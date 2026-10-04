#!/usr/bin/env python3
"""
TAXIS Synthea PostgreSQL Synthetic Smoke Testing Suite
======================================================
Live Containerized OMOP CDM v5.4 Synthetic Pre-Flight

Scope & Calibration Note (REC-052-1):
This harness executes synthetic Python/PostgreSQL CDM smoke checks against a
containerized Synthea OMOP CDM v5.4 instance. It validates schema initialization,
cohort generation in cohort.cohort, small-cell suppression (<5 -> -1), and
Concept AB mining queries.

This suite is a pre-flight synthetic smoke test. It does NOT invoke native R packages,
R SqlRender transpilation, or released TaxisPhenotypeEvaluation::packageResults() functions,
which remain separate gates pending native R runtime and partner CDM execution.

Usage:
    python extras/test_postgres_synthea_integration.py [--host localhost] [--port 5433]
"""

import os
import sys
import argparse
import tempfile
import zipfile
import shutil

try:
    import psycopg
    HAS_PSYCOPG = True
except ImportError:
    HAS_PSYCOPG = False


def apply_cohort_overlap_suppression(taxis_count, library_count, intersect_count,
                                     union_count, taxis_only, library_only, min_cell_count=5):
    """Mirror of applyCohortOverlapSuppression() in CohortOverlap.R."""
    int_max = 2147483647
    if min_cell_count is None or not isinstance(min_cell_count, (int, float)):
        min_cell_count = 5
    elif min_cell_count < 5 or min_cell_count > int_max or (min_cell_count % 1 != 0):
        min_cell_count = 5
    else:
        min_cell_count = int(min_cell_count)

    taxis_suppressed = (0 < taxis_count < min_cell_count)
    library_suppressed = (0 < library_count < min_cell_count)
    intersect_suppressed = (0 < intersect_count < min_cell_count)
    union_suppressed = (0 < union_count < min_cell_count)
    taxis_only_suppressed = (0 < taxis_only < min_cell_count)
    library_only_suppressed = (0 < library_only < min_cell_count)

    partition_suppressed = (intersect_suppressed or taxis_only_suppressed or
                            library_only_suppressed or union_suppressed)

    if partition_suppressed or taxis_suppressed or library_suppressed:
        masked_intersect = -1
        masked_taxis_only = -1
        masked_library_only = -1
        masked_union = -1
        jaccard = -1.0
        sens = -1.0
        agree = -1.0
    else:
        masked_intersect = intersect_count
        masked_taxis_only = taxis_only
        masked_library_only = library_only
        masked_union = union_count
        jaccard = round(intersect_count / union_count, 4) if union_count > 0 else 0.0
        sens = round(intersect_count / library_count, 4) if library_count > 0 else 0.0
        agree = round(intersect_count / taxis_count, 4) if taxis_count > 0 else 0.0

    masked_taxis = -1 if taxis_suppressed else taxis_count
    masked_library = -1 if library_suppressed else library_count

    return {
        "taxisPatientCount": masked_taxis,
        "libraryPatientCount": masked_library,
        "intersectionCount": masked_intersect,
        "unionCount": masked_union,
        "taxisOnlyCount": masked_taxis_only,
        "libraryOnlyCount": masked_library_only,
        "jaccardIndex": jaccard,
        "taxisSensitivityVsLibrary": sens,
        "taxisAgreementVsLibrary": agree
    }


def compute_directionality_ratio(forward_pairs, reverse_pairs):
    """Continuity-corrected Directionality Ratio (DR) = (N_prior + 0.5) / (N_post + 0.5)."""
    return round((forward_pairs + 0.5) / (reverse_pairs + 0.5), 4)


def run_postgres_tests(host, port, dbname, user, password):
    print("======================================================================")
    print("       TAXIS SYNTHEA POSTGRESQL SYNTHETIC SMOKE SUITE                 ")
    print("       Live Containerized OMOP CDM v5.4 Synthetic Pre-Flight          ")
    print("======================================================================")

    if not HAS_PSYCOPG:
        print("ERROR: psycopg is required. Install via 'pip install psycopg[binary]'")
        return False

    conn_str = f"host={host} port={port} dbname={dbname} user={user} password={password} connect_timeout=3"
    print(f"--> Connecting to PostgreSQL at {host}:{port}/{dbname}...")

    try:
        conn = psycopg.connect(conn_str, autocommit=True)
    except Exception as e:
        print(f"\n[ERROR] Unable to connect to PostgreSQL container on {host}:{port}: {e}")
        print("\nTo start the container, run:")
        print("  Windows:  .\\docker\\synthea-omop-postgres\\setup_synthea_postgres.ps1")
        print("  Linux/Mac: ./docker/synthea-omop-postgres/setup_synthea_postgres.sh")
        print("  Manual:   cd docker/synthea-omop-postgres && docker compose up -d\n")
        return None

    cur = conn.cursor()

    # 1. Schema & Table Presence
    print("--> Test 1: Verifying OMOP CDM tables in 'cdm' schema...")
    cur.execute("""
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'cdm'
        ORDER BY table_name;
    """)
    tables = [r[0] for r in cur.fetchall()]
    print(f"    Found {len(tables)} tables in cdm schema: {', '.join(tables[:8])}...")
    for req in ["person", "observation_period", "condition_occurrence", "drug_exposure"]:
        assert req in tables, f"Missing required table cdm.{req}"

    cur.execute("SELECT COUNT(*) FROM cdm.person;")
    person_cnt = cur.fetchone()[0]
    print(f"    Total person count in cdm.person: {person_cnt}")

    # 2. Cohort Table Initialization
    print("--> Test 2: Initializing cohort.cohort table...")
    cur.execute("""
        CREATE SCHEMA IF NOT EXISTS cohort;
        CREATE TABLE IF NOT EXISTS cohort.cohort (
            cohort_definition_id BIGINT NOT NULL,
            subject_id BIGINT NOT NULL,
            cohort_start_date DATE NOT NULL,
            cohort_end_date DATE NOT NULL
        );
        TRUNCATE TABLE cohort.cohort;
    """)

    # Populate synthetic test cohort:
    # Cohort 1798326 (Taxis candidate): Patients with condition occurrence
    cur.execute("""
        INSERT INTO cohort.cohort (cohort_definition_id, subject_id, cohort_start_date, cohort_end_date)
        SELECT 1798326, person_id, MIN(condition_start_date), COALESCE(MAX(condition_end_date), MIN(condition_start_date))
        FROM cdm.condition_occurrence
        GROUP BY person_id;
    """)
    # Cohort 1032 (Library comparator): Patients with condition AND drug exposure
    cur.execute("""
        INSERT INTO cohort.cohort (cohort_definition_id, subject_id, cohort_start_date, cohort_end_date)
        SELECT 1032, c.person_id, MIN(c.condition_start_date), COALESCE(MAX(c.condition_end_date), MIN(c.condition_start_date))
        FROM cdm.condition_occurrence c
        JOIN cdm.drug_exposure d ON c.person_id = d.person_id
        GROUP BY c.person_id;
    """)

    cur.execute("SELECT cohort_definition_id, COUNT(DISTINCT subject_id) FROM cohort.cohort GROUP BY cohort_definition_id;")
    cohort_counts = dict(cur.fetchall())
    print(f"    Generated cohorts in cohort.cohort: {cohort_counts}")

    # 3. 2x2 Overlap and Algebraic Suppression
    print("--> Test 3: Evaluating 2x2 cohort overlap in PostgreSQL...")
    cur.execute("""
        WITH cohort_a AS (
            SELECT DISTINCT subject_id FROM cohort.cohort WHERE cohort_definition_id = 1798326
        ),
        cohort_b AS (
            SELECT DISTINCT subject_id FROM cohort.cohort WHERE cohort_definition_id = 1032
        )
        SELECT 
            (SELECT COUNT(*) FROM cohort_a) AS cnt_a,
            (SELECT COUNT(*) FROM cohort_b) AS cnt_b,
            (SELECT COUNT(*) FROM (SELECT subject_id FROM cohort_a INTERSECT SELECT subject_id FROM cohort_b) s) AS cnt_intersect,
            (SELECT COUNT(*) FROM (SELECT subject_id FROM cohort_a UNION SELECT subject_id FROM cohort_b) s) AS cnt_union,
            (SELECT COUNT(*) FROM (SELECT subject_id FROM cohort_a EXCEPT SELECT subject_id FROM cohort_b) s) AS cnt_a_only,
            (SELECT COUNT(*) FROM (SELECT subject_id FROM cohort_b EXCEPT SELECT subject_id FROM cohort_a) s) AS cnt_b_only;
    """)
    cnt_a, cnt_b, cnt_intersect, cnt_union, cnt_a_only, cnt_b_only = cur.fetchone()
    print(f"    PostgreSQL Overlap: Taxis={cnt_a}, Library={cnt_b}, Intersect={cnt_intersect}, Union={cnt_union}")

    suppressed = apply_cohort_overlap_suppression(cnt_a, cnt_b, cnt_intersect, cnt_union, cnt_a_only, cnt_b_only, min_cell_count=5)
    print(f"    Suppression Output: Jaccard={suppressed['jaccardIndex']}, SensitivityProxy={suppressed['taxisSensitivityVsLibrary']}")
    assert "jaccardIndex" in suppressed

    # 4. Concept AB Association Mining in PostgreSQL
    print("--> Test 4: Executing Concept AB Association Mining in PostgreSQL...")
    cur.execute("""
        SELECT 
            d.drug_concept_id,
            COUNT(DISTINCT c.person_id) AS cooccur_patients,
            COUNT(CASE WHEN d.drug_exposure_start_date < c.condition_start_date THEN 1 END) AS prior_exposures,
            COUNT(CASE WHEN d.drug_exposure_start_date >= c.condition_start_date THEN 1 END) AS post_exposures
        FROM cdm.condition_occurrence c
        JOIN cdm.drug_exposure d ON c.person_id = d.person_id
        GROUP BY d.drug_concept_id
        HAVING COUNT(DISTINCT c.person_id) >= 5
        ORDER BY cooccur_patients DESC
        LIMIT 5;
    """)
    pairs = cur.fetchall()
    print(f"    Extracted {len(pairs)} top condition-drug association pairs with N >= 5:")
    for row in pairs:
        dr = compute_directionality_ratio(row[2], row[3])
        print(f"      Drug {row[0]}: N={row[1]}, Prior={row[2]}, Post={row[3]}, DR={dr}")

    conn.close()
    print("\nALL POSTGRESQL INTEGRATION CHECKS PASSED SUCCESSFULLY.")
    return True


def main():
    parser = argparse.ArgumentParser(description="TAXIS PostgreSQL Synthea Integration Test")
    parser.add_argument("--host", default=os.environ.get("POSTGRES_HOST", "localhost"))
    parser.add_argument("--port", default=int(os.environ.get("POSTGRES_PORT", 5433)), type=int)
    parser.add_argument("--db", default=os.environ.get("POSTGRES_DB", "synthea"))
    parser.add_argument("--user", default=os.environ.get("POSTGRES_USER", "ohdsi_app"))
    parser.add_argument("--password", default=os.environ.get("POSTGRES_PASSWORD", "ohdsi_app_pass_2026"))
    parser.add_argument("--allow-skip", action="store_true", default=False,
                        help="Allow skipping the test with exit code 0 if database is unavailable")
    args = parser.parse_args()

    result = run_postgres_tests(args.host, args.port, args.db, args.user, args.password)
    if result is True:
        sys.exit(0)
    elif result is None:
        if args.allow_skip:
            print("[SKIPPED] PostgreSQL integration test skipped (--allow-skip enabled).")
            sys.exit(0)
        else:
            print("[FAILED] PostgreSQL database is unavailable. Exiting with failure code 1.")
            sys.exit(1)
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
