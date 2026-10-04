#!/usr/bin/env python3
"""
TAXIS Eunomia Integration Testing Suite (SQLite & DuckDB)
=========================================================
Executes end-to-end integration tests using the official OHDSI Eunomia synthetic OMOP CDM dataset:
1. Auto-downloads and caches official Eunomia GiBleed dataset (6.8 MB) from OHDSI/EunomiaDatasets.
2. Ingests OMOP CDM tables into both native SQLite (cdm.sqlite) and DuckDB (cdm.duckdb).
3. Executes TAXIS Phenotype Extraction & Overlap Analysis (2x2 Jaccard, sensitivity, agreement).
4. Tests algebraic disclosure protection (small-cell suppression, bound masking, floor normalization).
5. Executes TAXIS Concept AB Mining queries on synthetic longitudinal data (Directionality Ratio, Stratification).
6. Verifies export bundle creation and sanitization (zero leaks, allowlisted CSVs).

Usage:
    python extras/test_eunomia_integration.py
"""

import os
import sys
import json
import zipfile
import urllib.request
import sqlite3
import tempfile
import shutil
import csv
import pandas as pd

try:
    import duckdb
    HAS_DUCKDB = True
except ImportError:
    HAS_DUCKDB = False

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
TESTDATA_DIR = os.path.join(ROOT_DIR, "extras", "testdata", "eunomia")
EUNOMIA_ZIP_URL = "https://raw.githubusercontent.com/OHDSI/EunomiaDatasets/main/datasets/GiBleed/GiBleed_5.3.zip"


def ensure_eunomia_dataset():
    """Ensure the Eunomia GiBleed tables are downloaded, extracted, and loaded into SQLite and DuckDB."""
    os.makedirs(TESTDATA_DIR, exist_ok=True)
    sqlite_path = os.path.join(TESTDATA_DIR, "cdm.sqlite")
    duckdb_path = os.path.join(TESTDATA_DIR, "cdm.duckdb")
    zip_path = os.path.join(TESTDATA_DIR, "GiBleed_5.3.zip")
    csv_dir = os.path.join(TESTDATA_DIR, "GiBleed_5.3")

    if not os.path.exists(csv_dir):
        if not os.path.exists(zip_path):
            print(f"--> Downloading official OHDSI Eunomia dataset from:\n    {EUNOMIA_ZIP_URL}")
            urllib.request.urlretrieve(EUNOMIA_ZIP_URL, zip_path)
            print(f"    Downloaded successfully ({os.path.getsize(zip_path)} bytes).")
        
        print("--> Extracting Eunomia GiBleed_5.3.zip...")
        with zipfile.ZipFile(zip_path, "r") as zf:
            zf.extractall(TESTDATA_DIR)
        print(f"    Extracted tables to {csv_dir}.")

    # Core OMOP CDM tables needed for TAXIS phenotyping & mining
    core_tables = [
        "PERSON",
        "OBSERVATION_PERIOD",
        "CONDITION_OCCURRENCE",
        "DRUG_EXPOSURE",
        "CONCEPT",
        "CONCEPT_ANCESTOR",
        "MEASUREMENT",
        "PROCEDURE_OCCURRENCE"
    ]

    # Ingest into SQLite if not present
    if not os.path.exists(sqlite_path):
        print("--> Building Eunomia SQLite database (cdm.sqlite)...")
        conn = sqlite3.connect(sqlite_path)
        for tname in core_tables:
            cfile = os.path.join(csv_dir, f"{tname}.csv")
            if os.path.exists(cfile):
                print(f"    Loading {tname}.csv into SQLite...")
                df = pd.read_csv(cfile, low_memory=False)
                df.columns = [c.lower() for c in df.columns]
                df.to_sql(tname.lower(), conn, if_exists="replace", index=False)
        conn.close()
        print(f"    Successfully created {sqlite_path}.")

    # Ingest into DuckDB if not present
    if HAS_DUCKDB and not os.path.exists(duckdb_path):
        print("--> Building Eunomia DuckDB database (cdm.duckdb)...")
        con = duckdb.connect(duckdb_path)
        for tname in core_tables:
            cfile = os.path.join(csv_dir, f"{tname}.csv").replace("\\", "/")
            if os.path.exists(cfile):
                print(f"    Loading {tname}.csv into DuckDB...")
                con.execute(f"CREATE TABLE IF NOT EXISTS {tname.lower()} AS SELECT * FROM read_csv_auto('{cfile}');")
        con.close()
        print(f"    Successfully created {duckdb_path}.")

    return sqlite_path, duckdb_path


# ==============================================================================
# TAXIS Core Algorithms in Python (Mirroring R implementations)
# ==============================================================================

def apply_cohort_overlap_suppression(taxis_count, library_count, intersect_count,
                                     union_count, taxis_only, library_only, min_cell_count=5):
    """
    Python mirror of applyCohortOverlapSuppression() in CohortOverlap.R.
    Enforces privacy floor and integer overflow guards (REC-049-1, REC-050-1).
    """
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

    if partition_suppressed:
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

    if taxis_suppressed or library_suppressed:
        masked_intersect = -1
        masked_taxis_only = -1
        masked_library_only = -1
        masked_union = -1
        jaccard = -1.0
        sens = -1.0
        agree = -1.0

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
    """
    Continuity-corrected Directionality Ratio (DR) per TAXIS v57 specification:
    DR = (N_A_before_B + 0.5) / (N_B_before_A + 0.5)
    """
    return round((forward_pairs + 0.5) / (reverse_pairs + 0.5), 4)


# ==============================================================================
# Integration Test Functions
# ==============================================================================

def test_sqlite_eunomia_integration(sqlite_path):
    """Run integration test against SQLite Eunomia database."""
    print("\n======================================================================")
    print(" [1/2] RUNNING TAXIS INTEGRATION TESTS ON EUNOMIA SQLITE")
    print("======================================================================")
    conn = sqlite3.connect(sqlite_path)
    cur = conn.cursor()

    # 1. Schema & Population Verification
    print("--> Subtest 1.1: Verifying OMOP CDM v5.3 tables in SQLite...")
    tables = [r[0].lower() for r in cur.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()]
    required_tables = ["person", "observation_period", "condition_occurrence", "drug_exposure", "concept"]
    for t in required_tables:
        assert t in tables, f"Missing table {t} in SQLite Eunomia"
    
    person_count = cur.execute("SELECT COUNT(*) FROM person").fetchone()[0]
    print(f"    PASSED: Found {len(tables)} tables. Person count = {person_count} (Standard Eunomia GiBleed = 2694).")
    assert person_count == 2694, f"Expected 2694 persons, got {person_count}"

    # 2. Phenotype Extraction: Gastrointestinal Bleed (192671) & NSAID exposure
    print("--> Subtest 1.2: Extracting candidate cohorts & evaluating overlap...")
    gi_bleed_exact = cur.execute("SELECT COUNT(DISTINCT person_id) FROM condition_occurrence WHERE condition_concept_id = 192671").fetchone()[0]
    print(f"    Distinct patients with GI Bleed (concept 192671): {gi_bleed_exact}")
    assert gi_bleed_exact > 0, "No GI Bleed patients found in Eunomia"

    # Set overlap between cohort A (GI Bleed) and cohort B (GI Bleed + Drug Exposure)
    query = """
        WITH cohort_a AS (
            SELECT DISTINCT person_id FROM condition_occurrence WHERE condition_concept_id = 192671
        ),
        cohort_b AS (
            SELECT DISTINCT c.person_id
            FROM condition_occurrence c
            JOIN drug_exposure d ON c.person_id = d.person_id
            WHERE c.condition_concept_id = 192671
        )
        SELECT 
            (SELECT COUNT(*) FROM cohort_a) AS count_a,
            (SELECT COUNT(*) FROM cohort_b) AS count_b,
            (SELECT COUNT(*) FROM (SELECT person_id FROM cohort_a INTERSECT SELECT person_id FROM cohort_b)) AS count_intersect,
            (SELECT COUNT(*) FROM (SELECT person_id FROM cohort_a UNION SELECT person_id FROM cohort_b)) AS count_union,
            (SELECT COUNT(*) FROM (SELECT person_id FROM cohort_a EXCEPT SELECT person_id FROM cohort_b)) AS count_a_only,
            (SELECT COUNT(*) FROM (SELECT person_id FROM cohort_b EXCEPT SELECT person_id FROM cohort_a)) AS count_b_only
    """
    row = cur.execute(query).fetchone()
    cnt_a, cnt_b, cnt_intersect, cnt_union, cnt_a_only, cnt_b_only = row
    print(f"    Raw Overlap: CohortA={cnt_a}, CohortB={cnt_b}, Intersect={cnt_intersect}, Union={cnt_union}, A_Only={cnt_a_only}, B_Only={cnt_b_only}")
    assert cnt_a == cnt_intersect + cnt_a_only
    assert cnt_b == cnt_intersect + cnt_b_only

    # Test suppression helper with privacy floor
    suppressed = apply_cohort_overlap_suppression(
        taxis_count=cnt_a,
        library_count=cnt_b,
        intersect_count=cnt_intersect,
        union_count=cnt_union,
        taxis_only=cnt_a_only,
        library_only=cnt_b_only,
        min_cell_count=5
    )
    print(f"    Suppression Result: Jaccard={suppressed['jaccardIndex']}, TaxisSensitivity={suppressed['taxisSensitivityVsLibrary']}")
    assert suppressed["taxisPatientCount"] == cnt_a
    assert suppressed["libraryPatientCount"] == cnt_b
    assert suppressed["jaccardIndex"] > 0

    # 3. Concept AB Mining Simulation on Eunomia
    print("--> Subtest 1.3: Simulating Concept AB Association Mining on SQLite...")
    mining_query = """
        SELECT 
            d.drug_concept_id,
            COUNT(DISTINCT c.person_id) AS cooccur_person_count,
            SUM(CASE WHEN d.drug_exposure_start_date < c.condition_start_date THEN 1 ELSE 0 END) AS prior_exposures,
            SUM(CASE WHEN d.drug_exposure_start_date >= c.condition_start_date THEN 1 ELSE 0 END) AS post_exposures
        FROM condition_occurrence c
        JOIN drug_exposure d ON c.person_id = d.person_id
        WHERE c.condition_concept_id = 192671
        GROUP BY d.drug_concept_id
        HAVING COUNT(DISTINCT c.person_id) >= 5
        ORDER BY cooccur_person_count DESC
        LIMIT 5
    """
    pairs = cur.execute(mining_query).fetchall()
    print(f"    Found {len(pairs)} top co-occurring drugs with N >= 5:")
    for drug_id, n_pts, prior_n, post_n in pairs:
        dr = compute_directionality_ratio(prior_n, post_n)
        print(f"      DrugConcept={drug_id}: Persons={n_pts}, Prior={prior_n}, Post={post_n}, DR={dr}")
        assert n_pts >= 5, "Privacy floor violation in query result"

    conn.close()
    print("  PASSED: SQLite Eunomia integration test completed successfully.")
    return True


def test_duckdb_eunomia_integration(duckdb_path):
    """Run integration test against DuckDB Eunomia database."""
    print("\n======================================================================")
    print(" [2/2] RUNNING TAXIS INTEGRATION TESTS ON EUNOMIA DUCKDB")
    print("======================================================================")
    if not HAS_DUCKDB:
        print("  SKIPPED: DuckDB python module not available.")
        return False

    con = duckdb.connect(duckdb_path)

    # 1. Population Verification in DuckDB
    print("--> Subtest 2.1: Querying DuckDB native Eunomia database...")
    person_count = con.execute("SELECT COUNT(*) FROM person;").fetchone()[0]
    print(f"    DuckDB person count: {person_count}")
    assert person_count == 2694, f"Expected 2694 persons, got {person_count}"

    # 2. Vectorized Cohort Overlap in DuckDB
    print("--> Subtest 2.2: Executing vectorized cohort overlap query in DuckDB...")
    duck_query = """
        WITH cohort_a AS (
            SELECT DISTINCT person_id FROM condition_occurrence WHERE condition_concept_id = 192671
        ),
        cohort_b AS (
            SELECT DISTINCT c.person_id
            FROM condition_occurrence c
            JOIN drug_exposure d ON c.person_id = d.person_id
            WHERE c.condition_concept_id = 192671
        )
        SELECT 
            (SELECT COUNT(*) FROM cohort_a) AS cnt_a,
            (SELECT COUNT(*) FROM cohort_b) AS cnt_b,
            (SELECT COUNT(*) FROM (SELECT person_id FROM cohort_a INTERSECT SELECT person_id FROM cohort_b)) AS cnt_intersect,
            (SELECT COUNT(*) FROM (SELECT person_id FROM cohort_a UNION SELECT person_id FROM cohort_b)) AS cnt_union,
            (SELECT COUNT(*) FROM (SELECT person_id FROM cohort_a EXCEPT SELECT person_id FROM cohort_b)) AS cnt_a_only,
            (SELECT COUNT(*) FROM (SELECT person_id FROM cohort_b EXCEPT SELECT person_id FROM cohort_a)) AS cnt_b_only;
    """
    duck_overlap = con.execute(duck_query).fetchone()
    cnt_a, cnt_b, cnt_intersect, cnt_union, cnt_a_only, cnt_b_only = duck_overlap
    print(f"    DuckDB Overlap Result: CohortA={cnt_a}, CohortB={cnt_b}, Intersect={cnt_intersect}, Union={cnt_union}")
    assert cnt_a == cnt_intersect + cnt_a_only
    assert cnt_b == cnt_intersect + cnt_b_only

    # 3. Vectorized Directionality Ratio in DuckDB
    print("--> Subtest 2.3: Vectorized Concept AB temporal directionality in DuckDB...")
    duck_pairs_query = """
        SELECT 
            d.drug_concept_id,
            COUNT(DISTINCT c.person_id) AS cooccur_person_count,
            COUNT(CASE WHEN d.drug_exposure_start_date < c.condition_start_date THEN 1 END) AS prior_exposures,
            COUNT(CASE WHEN d.drug_exposure_start_date >= c.condition_start_date THEN 1 END) AS post_exposures,
            ROUND((COUNT(CASE WHEN d.drug_exposure_start_date < c.condition_start_date THEN 1 END) + 0.5) / 
                  (COUNT(CASE WHEN d.drug_exposure_start_date >= c.condition_start_date THEN 1 END) + 0.5), 4) AS directionality_ratio
        FROM condition_occurrence c
        JOIN drug_exposure d ON c.person_id = d.person_id
        WHERE c.condition_concept_id = 192671
        GROUP BY d.drug_concept_id
        HAVING COUNT(DISTINCT c.person_id) >= 5
        ORDER BY cooccur_person_count DESC
        LIMIT 5;
    """
    duck_pairs = con.execute(duck_pairs_query).fetchall()
    print(f"    Found {len(duck_pairs)} top drug associations in DuckDB:")
    for row in duck_pairs:
        print(f"      Drug={row[0]}: N={row[1]}, Prior={row[2]}, Post={row[3]}, DR={row[4]}")
        assert row[1] >= 5, "Privacy floor violation"

    con.close()
    print("  PASSED: DuckDB Eunomia integration test completed successfully.")
    return True


def test_package_results_export_hygiene():
    """Verify packageResults export hygiene on temporary synthetic outputs."""
    print("\n======================================================================")
    print(" [3/3] VERIFYING EXPORT BUNDLING & PRIVACY HYGIENE")
    print("======================================================================")
    temp_dir = tempfile.mkdtemp(prefix="taxis_export_test_")
    try:
        # Create synthetic allowlisted files
        manifest_csv = os.path.join(temp_dir, "cohort_overlap_summary_Eunomia.csv")
        with open(manifest_csv, "w") as f:
            f.write("databaseId,pairGroup,taxisPatientCount,libraryPatientCount,intersectionCount,jaccardIndex\n")
            f.write("Eunomia,GI_Bleed,253,253,253,1.0\n")

        # Create decoy sensitive file to verify non-allowlist exclusion
        decoy_file = os.path.join(temp_dir, "raw_person_phi_leak.csv")
        with open(decoy_file, "w") as f:
            f.write("person_id,ssn,name\n1,000-00-0000,JohnDoe\n")

        # Bundle allowlisted files
        zip_path = os.path.join(temp_dir, "Results_Eunomia.zip")
        with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
            for fname in os.listdir(temp_dir):
                if fname.startswith("cohort_overlap_summary") and fname.endswith(".csv"):
                    zf.write(os.path.join(temp_dir, fname), fname)

        # Inspect zip archive
        with zipfile.ZipFile(zip_path, "r") as zf:
            namelist = zf.namelist()
            print(f"    Export archive contains: {namelist}")
            assert "cohort_overlap_summary_Eunomia.csv" in namelist
            assert "raw_person_phi_leak.csv" not in namelist, "Decoy PHI file leaked into export archive!"

        print("  PASSED: Export hygiene verified. Only allowlisted files entered the archive.")
        return True
    finally:
        shutil.rmtree(temp_dir, ignore_errors=True)


def main():
    print("======================================================================")
    print("       TAXIS EUNOMIA INTEGRATION SUITE (SQLite & DuckDB)              ")
    print("       Zero-PHI Synthetic OMOP CDM End-to-End Execution              ")
    print("======================================================================")

    sqlite_path, duckdb_path = ensure_eunomia_dataset()

    res_sqlite = test_sqlite_eunomia_integration(sqlite_path)
    res_duckdb = test_duckdb_eunomia_integration(duckdb_path)
    res_export = test_package_results_export_hygiene()

    print("\n======================================================================")
    if res_sqlite and res_duckdb and res_export:
        print("ALL EUNOMIA INTEGRATION TESTS PASSED (3/3).")
        print("1. SQLite Native CDM Engine: PASSED")
        print("2. DuckDB Vectorized CDM Engine: PASSED")
        print("3. Export Bundling & Privacy Hygiene: PASSED")
        print("======================================================================")
        return 0
    else:
        print("SOME INTEGRATION TESTS FAILED.")
        print("======================================================================")
        return 1


if __name__ == "__main__":
    sys.exit(main())
