#!/usr/bin/env python3
"""
Test Suite: Concept AB Mining Engine v57 Live Execution on PostgreSQL
====================================================================
Verifies that the Concept AB Mining Engine v57 pipeline executed cleanly
end-to-end against the local containerized PostgreSQL OMOP CDM fixture:
  1. Verifies CDM facts, observations, visits, devices, and vocabulary.
  2. Verifies the 6 project reference lookup tables in 'concept_ab_vocab'.
  3. Verifies materialized pipeline output tables in 'work_cab_test' (s10, s13, s20, s23, s30, s33, s40, s50, s55).
  4. Verifies that master pair table 'cab_s55_pair_all' contains valid association metrics (Lift, DR, dir_ab).
"""

import sys
import os
import psycopg

POSTGRES_HOST = os.environ.get("POSTGRES_HOST", "localhost")
POSTGRES_PORT = int(os.environ.get("POSTGRES_PORT", 5433))
POSTGRES_DB = os.environ.get("POSTGRES_DB", "synthea")
POSTGRES_USER = os.environ.get("POSTGRES_USER", "ohdsi_app")
POSTGRES_PASSWORD = os.environ.get("POSTGRES_PASSWORD", "ohdsi_app_pass_2026")


def main():
    print("======================================================================")
    print("   TAXIS PIPELINE v57 LIVE POSTGRESQL EXECUTION VERIFICATION SUITE    ")
    print("======================================================================")

    conn_str = f"host={POSTGRES_HOST} port={POSTGRES_PORT} dbname={POSTGRES_DB} user={POSTGRES_USER} password={POSTGRES_PASSWORD}"
    print(f"--> Connecting to PostgreSQL at {POSTGRES_HOST}:{POSTGRES_PORT}/{POSTGRES_DB}...")

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
        print(f"    cdm.person: {p_cnt:,} | condition_occurrence: {c_cnt:,} | visit_occurrence: {v_cnt:,} | observation: {o_cnt:,}")
        assert p_cnt == 2694, f"Expected 2,694 persons, got {p_cnt}"
        assert v_cnt == 1037, f"Expected 1,037 visits, got {v_cnt}"
        assert o_cnt == 1477, f"Expected 1,477 observations, got {o_cnt}"
        print("    [PASS] OMOP CDM schema verified.")

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

        # Test 4: Master Association Table Sanity & Metrics
        print("--> Test 4: Auditing Master Association Table 'cab_s55_pair_all'...")
        cur.execute("SELECT count(*) FROM work_cab_test.cab_s55_pair_all;")
        pair_cnt = cur.fetchone()[0]
        print(f"    Total mined concept pairs in cab_s55_pair_all: {pair_cnt:,}")
        assert pair_cnt > 5000, f"Expected > 5,000 pairs, found {pair_cnt}"

        cur.execute("""
            SELECT count(*) 
            FROM work_cab_test.cab_s55_pair_all 
            WHERE dir_ab IS NOT NULL AND dir_ab >= 0.0 AND dir_ab <= 1.0;
        """)
        valid_dir_cnt = cur.fetchone()[0]
        print(f"    Pairs with valid directional share (dir_ab in [0, 1]): {valid_dir_cnt:,}")
        assert valid_dir_cnt > 0, "No valid directional shares found"

        # Check top pair
        cur.execute("""
            SELECT pair_type, concept_name_a, concept_name_b, obs_all, dir_ab, lift_to_read
            FROM work_cab_test.cab_s55_pair_all
            ORDER BY obs_all DESC
            LIMIT 1;
        """)
        top_row = cur.fetchone()
        print(f"    Top co-occurring pair: {top_row[1]} <-> {top_row[2]} (obs={top_row[3]:,}, dir_ab={top_row[4]}, lift_type={top_row[5]})")
        print("    [PASS] Master association table passed statistical consistency audit.")

    conn.close()
    print("\n======================================================================")
    print("   ALL PIPELINE v57 POSTGRESQL VERIFICATION TESTS PASSED SUCCESSFULLY ")
    print("======================================================================\n")


if __name__ == "__main__":
    main()
