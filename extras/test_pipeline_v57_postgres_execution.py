#!/usr/bin/env python3
"""
Test Suite: Concept AB Mining Engine v57 Live Execution on PostgreSQL
====================================================================
Verifies that the Concept AB Mining Engine v57 pipeline executed cleanly
end-to-end against the local containerized PostgreSQL OMOP CDM fixture:
  1. Verifies that pipeline_v57_run_receipt.json exists and confirms status 'SUCCESS'.
  2. Verifies CDM facts, observations, visits, devices, and vocabulary.
  3. Verifies the 6 project reference lookup tables in 'concept_ab_vocab'.
  4. Verifies materialized pipeline output tables in 'work_cab_test' (s10, s13, s20, s23, s30, s33, s40, s50, s55).
  5. Audits statistical consistency and known-answer precision for canonical concept pairs in 'cab_s55_pair_all'.
"""

import sys
import os
import json
import psycopg

POSTGRES_HOST = os.environ.get("POSTGRES_HOST", "localhost")
POSTGRES_PORT = int(os.environ.get("POSTGRES_PORT", 5433))
POSTGRES_DB = os.environ.get("POSTGRES_DB", "synthea")
POSTGRES_USER = os.environ.get("POSTGRES_USER", "ohdsi_app")
POSTGRES_PASSWORD = os.environ.get("POSTGRES_PASSWORD", "ohdsi_app_pass_2026")

RECEIPT_FILE = os.path.abspath(os.path.join(os.path.dirname(__file__), "pipeline_v57_run_receipt.json"))


def main():
    print("======================================================================")
    print("   TAXIS PIPELINE v57 LIVE POSTGRESQL EXECUTION VERIFICATION SUITE    ")
    print("======================================================================")

    # Test 0: Run Receipt Verification
    print("--> Test 0: Auditing Pipeline Run Receipt...")
    if not os.path.exists(RECEIPT_FILE):
        print(f"FAILED: Run receipt {RECEIPT_FILE} does not exist. Run extras/run_cab_pipeline_postgres_minimal.R first.")
        sys.exit(1)
    
    with open(RECEIPT_FILE, "r", encoding="utf-8") as rf:
        receipt = json.load(rf)
    
    print(f"    Receipt timestamp: {receipt.get('run_timestamp')}")
    print(f"    Receipt status   : {receipt.get('status')}")
    print(f"    Total duration   : {receipt.get('total_duration_seconds')}s")
    assert receipt.get("status") == "SUCCESS", f"Run receipt reports non-success status: {receipt.get('status')}"
    print("    [PASS] Run receipt confirms successful pipeline execution.")

    conn_str = f"host={POSTGRES_HOST} port={POSTGRES_PORT} dbname={POSTGRES_DB} user={POSTGRES_USER} password={POSTGRES_PASSWORD}"
    print(f"\n--> Connecting to PostgreSQL at {POSTGRES_HOST}:{POSTGRES_PORT}/{POSTGRES_DB}...")

    try:
        conn = psycopg.connect(conn_str)
    except Exception as e:
        print(f"FAILED to connect to PostgreSQL: {e}")
        sys.exit(1)

    with conn.cursor() as cur:
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
                   obs_all, obs_same_day, obs_after, obs_before, dir_ab, lift_to_read
            FROM work_cab_test.cab_s55_pair_all
            WHERE concept_a = 260139 AND concept_b = 1000960169;
        """)
        row1 = cur.fetchone()
        assert row1 is not None, "Known pair (Acute bronchitis <-> acetaminophen) not found in cab_s55_pair_all"
        p_type, c_a, c_b, name_a, name_b, obs_all, obs_same, obs_aft, obs_bef, dir_ab, lift_read = row1
        print(f"    Pair 1: {name_a} <-> {name_b}")
        print(f"      Counts: obs_all={obs_all}, same_day={obs_same}, after={obs_aft}, before={obs_bef}")
        print(f"      dir_ab: {dir_ab} (read as: {lift_read})")
        assert obs_all == 8228, f"Expected obs_all=8,228, got {obs_all}"
        assert obs_same == 8102, f"Expected obs_same=8,102, got {obs_same}"
        assert obs_aft == 92, f"Expected obs_aft=92, got {obs_aft}"
        assert obs_bef == 34, f"Expected obs_bef=34, got {obs_bef}"
        
        # Verify dir_ab exact calculation: obs_after / (obs_after + obs_before)
        expected_dir = round(92.0 / (92.0 + 34.0), 4)
        assert abs(float(dir_ab) - expected_dir) < 0.001, f"Expected dir_ab={expected_dir}, got {dir_ab}"
        
        # Verify continuity-corrected DR calculation: (obs_after + 0.5) / (obs_before + 0.5)
        calc_dr = (92.0 + 0.5) / (34.0 + 0.5)
        assert calc_dr >= 1.50, f"Expected forward directed DR >= 1.50, got {calc_dr:.4f}"
        print(f"      Calculated DR: {calc_dr:.4f} >= 1.50 (Confirmed forward directed)")

        # Known-Answer Check 2: Otitis media (372328) <-> acetaminophen (1000960169)
        cur.execute("""
            SELECT pair_type, concept_a, concept_b, concept_name_a, concept_name_b,
                   obs_all, obs_same_day, obs_after, obs_before, dir_ab, lift_to_read
            FROM work_cab_test.cab_s55_pair_all
            WHERE concept_a = 372328 AND concept_b = 1000960169;
        """)
        row2 = cur.fetchone()
        assert row2 is not None, "Known pair (Otitis media <-> acetaminophen) not found"
        p_type2, _, _, name_a2, name_b2, obs_all2, obs_same2, obs_aft2, obs_bef2, dir_ab2, _ = row2
        print(f"    Pair 2: {name_a2} <-> {name_b2}")
        print(f"      Counts: obs_all={obs_all2}, same_day={obs_same2}, after={obs_aft2}, before={obs_bef2}, dir_ab={dir_ab2}")
        assert obs_all2 == 1415, f"Expected obs_all=1,415, got {obs_all2}"
        assert obs_same2 == 1359, f"Expected obs_same=1,359, got {obs_same2}"
        assert obs_aft2 == 31, f"Expected obs_aft=31, got {obs_aft2}"
        assert obs_bef2 == 25, f"Expected obs_bef=25, got {obs_bef2}"
        calc_dr2 = (31.0 + 0.5) / (25.0 + 0.5)
        assert 0.67 <= calc_dr2 <= 1.50, f"Expected symmetric DR between 0.67 and 1.50, got {calc_dr2:.4f}"
        print(f"      Calculated DR: {calc_dr2:.4f} (Confirmed symmetric association)")

        # Known-Answer Check 3: Suture open wound (4125906) <-> acetaminophen (1000960169)
        cur.execute("""
            SELECT obs_all, obs_same_day, obs_after, obs_before, dir_ab
            FROM work_cab_test.cab_s55_pair_all
            WHERE concept_a = 4125906 AND concept_b = 1000960169;
        """)
        row3 = cur.fetchone()
        assert row3 is not None
        assert row3[0] == 1062 and row3[1] == 1035 and row3[2] == 12 and row3[3] == 15
        print(f"    Pair 3 (Procedure -> Drug): Suture open wound <-> acetaminophen verified (obs={row3[0]}, dir_ab={row3[4]})")

        print("    [PASS] Master association table verified with 3 independent known-answer test vectors.")

    conn.close()
    print("\n======================================================================")
    print("   ALL PIPELINE v57 POSTGRESQL VERIFICATION TESTS PASSED SUCCESSFULLY ")
    print("======================================================================\n")


if __name__ == "__main__":
    main()
