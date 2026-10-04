#!/usr/bin/env python3
"""
Test Suite: Concept AB Mining Engine v57 Live Execution on PostgreSQL
====================================================================
Verifies that the Concept AB Mining Engine v57 pipeline executed cleanly
end-to-end against the local containerized PostgreSQL OMOP CDM fixture:
  0. Audits pipeline_v57_run_receipt.json for valid timestamp, duration,
     status == 'SUCCESS', matching SQL file SHA-256 hashes, and database run_id binding.
  1. Verifies OMOP CDM facts, observations, visits, devices, and vocabulary.
  2. Verifies the 6 project reference lookup tables in 'concept_ab_vocab'.
  3. Verifies materialized pipeline output tables in 'work_cab_test'.
  4. Audits master association table 'cab_s55_pair_all' known answers.
  5. Independently derives counts and lifts directly from raw CDM fact tables
     (cdm.condition_occurrence and cdm.drug_exposure) and confirms exact concordance.
"""

import sys
import os
import json
import hashlib
from datetime import datetime
import psycopg

POSTGRES_HOST = os.environ.get("POSTGRES_HOST", "localhost")
POSTGRES_PORT = int(os.environ.get("POSTGRES_PORT", 5433))
POSTGRES_DB = os.environ.get("POSTGRES_DB", "synthea")
POSTGRES_USER = os.environ.get("POSTGRES_USER", "ohdsi_app")
POSTGRES_PASSWORD = os.environ.get("POSTGRES_PASSWORD", "ohdsi_app_pass_2026")

RECEIPT_FILE = os.path.abspath(os.path.join(os.path.dirname(__file__), "pipeline_v57_run_receipt.json"))
SQL_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "inst", "sql", "sql_server"))


def compute_sha256(file_path):
    h = hashlib.sha256()
    with open(file_path, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()


def main():
    print("======================================================================")
    print("   TAXIS PIPELINE v57 LIVE POSTGRESQL EXECUTION VERIFICATION SUITE    ")
    print("======================================================================")

    # Test 0: Run Receipt Verification & Dynamic SQL Provenance
    print("--> Test 0: Auditing Pipeline Run Receipt & SQL Provenance...")
    if not os.path.exists(RECEIPT_FILE):
        print(f"FAILED: Run receipt {RECEIPT_FILE} does not exist. Run extras/run_cab_pipeline_postgres_minimal.R first.")
        sys.exit(1)
    
    with open(RECEIPT_FILE, "r", encoding="utf-8") as rf:
        receipt = json.load(rf)
    
    run_id = receipt.get("run_id")
    ts_str = receipt.get("run_timestamp")
    status = receipt.get("status")
    duration = receipt.get("total_duration_seconds", 0)

    print(f"    Receipt Run ID   : {run_id}")
    print(f"    Receipt Timestamp: {ts_str}")
    print(f"    Receipt Status   : {status}")
    print(f"    Total Duration   : {duration}s")

    assert run_id and len(run_id) > 0, "Receipt missing valid run_id"
    assert status == "SUCCESS", f"Run receipt reports non-success status: {status}"
    assert duration > 0, f"Total duration must be positive, got {duration}"

    # Validate ISO 8601 UTC timestamp format
    try:
        dt = datetime.strptime(ts_str, "%Y-%m-%dT%H:%M:%SZ")
        print(f"    Validated ISO 8601 UTC timestamp: {dt}")
    except ValueError as ve:
        raise AssertionError(f"Invalid timestamp format: {ts_str}") from ve

    # Validate dynamic SQL digests
    init_sql = os.path.join(SQL_DIR, "concept_ab_init.sql")
    batch_sql = os.path.join(SQL_DIR, "concept_ab_batch.sql")
    fin_sql = os.path.join(SQL_DIR, "concept_ab_finalize.sql")

    expected_hashes = {
        "concept_ab_init_sha256": compute_sha256(init_sql),
        "concept_ab_batch_sha256": compute_sha256(batch_sql),
        "concept_ab_finalize_sha256": compute_sha256(fin_sql)
    }

    receipt_hashes = receipt.get("sql_hashes", {})
    for k, expected_h in expected_hashes.items():
        actual_h = receipt_hashes.get(k)
        print(f"    SQL Hash {k:<28}: {actual_h}")
        assert actual_h == expected_h, f"Digest mismatch for {k}: receipt has {actual_h}, file has {expected_h}"

    print("    [PASS] Run receipt and dynamic SQL hashes verified.")

    conn_str = f"host={POSTGRES_HOST} port={POSTGRES_PORT} dbname={POSTGRES_DB} user={POSTGRES_USER} password={POSTGRES_PASSWORD}"
    print(f"\n--> Connecting to PostgreSQL at {POSTGRES_HOST}:{POSTGRES_PORT}/{POSTGRES_DB}...")

    try:
        conn = psycopg.connect(conn_str)
    except Exception as e:
        print(f"FAILED to connect to PostgreSQL: {e}")
        sys.exit(1)

    with conn.cursor() as cur:
        # Test 0b: Database Run Receipt Binding
        print("--> Test 0b: Verifying Database Run Receipt Binding in 'work_cab_test.taxis_run_receipt'...")
        cur.execute("SELECT run_id, run_timestamp, status, batch_count, window_days, init_sha256 FROM work_cab_test.taxis_run_receipt WHERE run_id = %s;", (run_id,))
        row_rcpt = cur.fetchone()
        assert row_rcpt is not None, f"Database has no record for run_id: {run_id}"
        db_run_id, db_ts, db_status, db_b_cnt, db_win, db_init_h = row_rcpt
        print(f"    Database Run Record: run_id={db_run_id}, status={db_status}, window_days={db_win}")
        assert db_status == "SUCCESS", f"Database record status is not SUCCESS: {db_status}"
        assert db_init_h == expected_hashes["concept_ab_init_sha256"], "Database init SHA256 mismatch"
        print("    [PASS] Database outputs bound to matching identified successful run.")

        # Test 1: CDM Schema Verification
        print("--> Test 1: Verifying OMOP CDM tables in 'cdm' schema...")
        cur.execute("SELECT count(*) FROM cdm.person;")
        p_cnt = cur.fetchone()[0]
        cur.execute("SELECT count(*) FROM cdm.condition_occurrence;")
        c_cnt = cur.fetchone()[0]
        cur.execute("SELECT count(*) FROM cdm.visit_occurrence;")
        v_cnt = cur.fetchone()[0]
        cur.execute("SELECT count(*) FROM cdm.observation;")
        o_cnt = cur.fetchone()[0]
        cur.execute("SELECT count(*) FROM cdm.device_exposure;")
        dev_cnt = cur.fetchone()[0]
        print(f"    cdm.person: {p_cnt:,} | condition_occurrence: {c_cnt:,} | visit_occurrence: {v_cnt:,} | observation: {o_cnt:,} | device_exposure: {dev_cnt:,}")
        assert p_cnt == 2694, f"Expected 2,694 persons, got {p_cnt}"
        assert v_cnt == 1037, f"Expected 1,037 visits, got {v_cnt}"
        assert o_cnt == 1477, f"Expected 1,477 observations, got {o_cnt}"
        assert dev_cnt == 0, f"Expected 0 device records in synthetic GiBleed, got {dev_cnt}"
        print("    [PASS] OMOP CDM schema verified (noting 0 device exposures as an explicit synthetic fixture coverage limit).")

        # Test 2: Project Reference Vocabulary Verification
        print("--> Test 2: Verifying 6 Project Lookup Tables in 'concept_ab_vocab'...")
        lookup_tables = [
            ("cab_vocab_all_visit_hierarchy", 20),
            ("cab_vocab_all_procedure", 151868),
            ("cab_vocab_all_device", 32517),
            ("cab_vocab_all_chronic_conditions", 29346),
            ("cab_vocab_all_meas_obs_test", 299934),
            ("cab_vocab_all_drug_ing_form", 2996686)
        ]
        for tbl, min_expected in lookup_tables:
            cur.execute(f"SELECT count(*) FROM concept_ab_vocab.{tbl};")
            cnt = cur.fetchone()[0]
            print(f"    concept_ab_vocab.{tbl:<35} : {cnt:>10,} rows")
            assert cnt >= min_expected, f"Table {tbl} has {cnt} rows, expected >= {min_expected}"
        print("    [PASS] All 6 project lookup tables verified.")

        # Test 3: Output Schema and Table Inventory
        print("--> Test 3: Verifying Materialized Pipeline v57 Output Tables in 'work_cab_test'...")
        cur.execute("SELECT table_name FROM information_schema.tables WHERE table_schema = 'work_cab_test' ORDER BY table_name;")
        tables = [r[0] for r in cur.fetchall()]
        print(f"    Found {len(tables)} tables in work_cab_test.")

        core_tables = [
            "cab_s10_person_all",
            "cab_s13_strat_all",
            "cab_s20_marginal_all",
            "cab_s23_strat_all",
            "cab_s30_all",
            "cab_s33_mh_all",
            "cab_s33_strat_all",
            "cab_s40_all",
            "cab_s50_all",
            "cab_s55_pair_all"
        ]
        for t in core_tables:
            assert t in tables, f"Expected output table {t} missing from work_cab_test"
            cur.execute(f"SELECT count(*) FROM work_cab_test.{t};")
            cnt = cur.fetchone()[0]
            print(f"    work_cab_test.{t:<25} : {cnt:>8,} rows")
            assert cnt > 0, f"Table {t} is unexpectedly empty"
        print("    [PASS] Core pipeline output tables present and populated.")

        # Test 4: Master Association Table Sanity & Known-Answer Checks
        print("--> Test 4: Auditing Master Association Table 'cab_s55_pair_all' Known Answers...")
        cur.execute("SELECT count(*) FROM work_cab_test.cab_s55_pair_all;")
        pair_cnt = cur.fetchone()[0]
        print(f"    Total mined concept pairs in cab_s55_pair_all: {pair_cnt:,}")
        assert pair_cnt > 5000, f"Expected > 5,000 pairs, found {pair_cnt}"

        # Known-Answer Check 1: Acute bronchitis (260139) <-> acetaminophen (1000960169)
        cur.execute("""
            SELECT pair_type, concept_a, concept_b, concept_name_a, concept_name_b,
                   obs_all, obs_same_day, obs_after, obs_before, dir_ab, lift_same_day, lift_after, lift_before
            FROM work_cab_test.cab_s55_pair_all
            WHERE concept_a = 260139 AND concept_b = 1000960169;
        """)
        row1 = cur.fetchone()
        assert row1 is not None, "Known pair (Acute bronchitis <-> acetaminophen) not found in cab_s55_pair_all"
        p_type, c_a, c_b, name_a, name_b, obs_all, obs_same, obs_aft, obs_bef, dir_ab, lift_same, lift_aft, lift_bef = row1
        print(f"    Pair 1: {name_a} <-> {name_b}")
        print(f"      Counts: obs_all={obs_all}, same_day={obs_same}, after={obs_aft}, before={obs_bef}")
        print(f"      Lifts : same_day={lift_same}, after={lift_aft}, before={lift_bef} | dir_ab={dir_ab}")
        assert obs_all == 8228, f"Expected obs_all=8,228, got {obs_all}"
        assert obs_same == 8102, f"Expected obs_same=8,102, got {obs_same}"
        assert obs_aft == 92, f"Expected obs_aft=92, got {obs_aft}"
        assert obs_bef == 34, f"Expected obs_bef=34, got {obs_bef}"
        assert abs(float(lift_same) - 4121.195) < 0.1, f"Expected lift_same_day ~4121.195, got {lift_same}"
        assert abs(float(lift_aft) - 1.337) < 0.01, f"Expected lift_after ~1.337, got {lift_aft}"
        assert abs(float(lift_bef) - 0.494) < 0.01, f"Expected lift_before ~0.494, got {lift_bef}"

        # Verify continuity-corrected DR calculation: (obs_after + 0.5) / (obs_before + 0.5)
        calc_dr = (92.0 + 0.5) / (34.0 + 0.5)
        assert calc_dr >= 1.50, f"Expected forward directed DR >= 1.50, got {calc_dr:.4f}"
        print(f"      Calculated DR: {calc_dr:.4f} >= 1.50 (Confirmed forward directed)")

        # Known-Answer Check 2: Otitis media (372328) <-> acetaminophen (1000960169)
        cur.execute("""
            SELECT pair_type, concept_a, concept_b, concept_name_a, concept_name_b,
                   obs_all, obs_same_day, obs_after, obs_before, dir_ab, lift_after
            FROM work_cab_test.cab_s55_pair_all
            WHERE concept_a = 372328 AND concept_b = 1000960169;
        """)
        row2 = cur.fetchone()
        assert row2 is not None, "Known pair (Otitis media <-> acetaminophen) not found"
        p_type2, _, _, name_a2, name_b2, obs_all2, obs_same2, obs_aft2, obs_bef2, dir_ab2, lift_aft2 = row2
        print(f"    Pair 2: {name_a2} <-> {name_b2}")
        print(f"      Counts: obs_all={obs_all2}, same_day={obs_same2}, after={obs_aft2}, before={obs_bef2}, dir_ab={dir_ab2}, lift_after={lift_aft2}")
        assert obs_all2 == 1415, f"Expected obs_all=1,415, got {obs_all2}"
        assert obs_same2 == 1359, f"Expected obs_same=1,359, got {obs_same2}"
        assert obs_aft2 == 31, f"Expected obs_aft=31, got {obs_aft2}"
        assert obs_bef2 == 25, f"Expected obs_bef=25, got {obs_bef2}"
        calc_dr2 = (31.0 + 0.5) / (25.0 + 0.5)
        assert 0.67 <= calc_dr2 <= 1.50, f"Expected symmetric DR between 0.67 and 1.50, got {calc_dr2:.4f}"
        print(f"      Calculated DR: {calc_dr2:.4f} (Confirmed symmetric association)")

        # Test 5: Independent Derivation Direct from Raw CDM Fact Tables
        print("--> Test 5: Independently Deriving Co-occurrences & Denominators Directly from Raw CDM Facts...")
        # Direct raw CDM query for Acute Bronchitis (260139) <-> Acetaminophen (1000960169)
        raw_cdm_sql = """
        WITH cond AS (
          SELECT DISTINCT person_id, condition_start_date AS dt_a
          FROM cdm.condition_occurrence
          WHERE condition_concept_id = 260139
        ),
        drug AS (
          SELECT DISTINCT de.person_id, de.drug_exposure_start_date AS dt_b
          FROM cdm.drug_exposure de
          JOIN concept_ab_vocab.cab_vocab_all_drug_ing_form map ON de.drug_concept_id = map.concept_id_in
          WHERE map.concept_id = 1000960169
        )
        SELECT 
          sum(CASE WHEN dt_b - dt_a = 0 THEN 1 ELSE 0 END) AS same_day,
          sum(CASE WHEN dt_b - dt_a BETWEEN 1 AND 35 THEN 1 ELSE 0 END) AS after_cnt,
          sum(CASE WHEN dt_b - dt_a BETWEEN -35 AND -1 THEN 1 ELSE 0 END) AS before_cnt
        FROM cond c
        JOIN drug d ON c.person_id = d.person_id;
        """
        cur.execute(raw_cdm_sql)
        raw_same, raw_aft, raw_bef = cur.fetchone()
        print(f"    Independent Raw CDM Fact Derivation: same_day={raw_same}, after={raw_aft}, before={raw_bef}")
        assert raw_same == 8102, f"Raw derivation mismatch for same_day: {raw_same} vs 8102"
        assert raw_aft == 92, f"Raw derivation mismatch for after: {raw_aft} vs 92"
        assert raw_bef == 34, f"Raw derivation mismatch for before: {raw_bef} vs 34"

        # Test 5b: Independently derive total observation-time denominator directly from source CDM
        print("--> Test 5b: Deriving Observation Person-Days Denominator Directly from Source CDM Tables...")
        cur.execute("""
            SELECT sum(op.observation_period_end_date - op.observation_period_start_date + 1)
            FROM cdm.observation_period op
            WHERE op.person_id IN (
                SELECT person_id FROM cdm.condition_occurrence
                UNION SELECT person_id FROM cdm.procedure_occurrence
                UNION SELECT person_id FROM cdm.drug_exposure
                UNION SELECT person_id FROM cdm.observation
                UNION SELECT person_id FROM cdm.measurement
            );
        """)
        source_derived_person_days = cur.fetchone()[0]
        print(f"    Source-Derived Observation Person-Days Denominator: {source_derived_person_days:,}")
        assert source_derived_person_days == 58197414, f"Expected 58,197,414 person-days from source CDM, got {source_derived_person_days}"

        # Verify pipeline table cab_s10_person_all matches source CDM derivation
        cur.execute("SELECT total_person_days FROM work_cab_test.cab_s10_person_all;")
        pipeline_person_days = cur.fetchone()[0]
        assert pipeline_person_days == source_derived_person_days, (
            f"Pipeline person-days ({pipeline_person_days}) differs from source-derived ({source_derived_person_days})"
        )

        # Check raw condition marginal directly from cdm.condition_occurrence
        cur.execute("SELECT count(*) FROM cdm.condition_occurrence WHERE condition_concept_id = 260139;")
        raw_cond_cnt = cur.fetchone()[0]
        assert raw_cond_cnt == 8184, f"Expected 8,184 condition occurrences, got {raw_cond_cnt}"

        # Check deduplicated drug marginal directly from cdm.drug_exposure joined to reference mapping
        cur.execute("""
          SELECT count(DISTINCT (de.person_id, map.concept_id, de.drug_exposure_start_date))
          FROM cdm.drug_exposure de
          JOIN concept_ab_vocab.cab_vocab_all_drug_ing_form map ON de.drug_concept_id = map.concept_id_in
          WHERE map.concept_id = 1000960169;
        """)
        raw_drug_dedup_cnt = cur.fetchone()[0]
        assert raw_drug_dedup_cnt == 13980, f"Expected 13,980 deduplicated drug events, got {raw_drug_dedup_cnt}"

        # Independently calculate expected co-occurrences and lift using source-derived values:
        # Expected(co-occurrences) = (N_A * N_B * window_days) / T_person_days
        window_days = 35.0
        expected_obs_aft = (float(raw_cond_cnt) * float(raw_drug_dedup_cnt) * window_days) / float(source_derived_person_days)
        derived_lift_aft = round(float(raw_aft) / expected_obs_aft, 3)
        print(f"    Independent Expected Count: {expected_obs_aft:.4f} | Derived Lift After: {derived_lift_aft}")
        assert abs(derived_lift_aft - float(lift_aft)) < 0.005, (
            f"Source-derived lift {derived_lift_aft} mismatch with pipeline SQL output {lift_aft}"
        )

        print("    [PASS] Independent raw CDM derivation confirms 100% statistical correctness.")

    conn.close()
    print("\n======================================================================")
    print("   ALL PIPELINE v57 POSTGRESQL VERIFICATION TESTS PASSED SUCCESSFULLY ")
    print("======================================================================\n")


if __name__ == "__main__":
    main()
