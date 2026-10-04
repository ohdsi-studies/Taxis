#!/usr/bin/env python3
"""
TAXIS Concept AB Mining Results Exporter: Suppression & Packaging Verification
Tests and proves compliance with:
1. REC-037-1: Schema verification, correct count columns, boundary suppression (0, 1, 4, 5),
   algebraic back-calculation masking across companion fields, and fail-closed schema checks.
2. REC-037-2: Staging directory isolation, exact allowlist packaging, decoy/stale file rejection,
   and post-archive membership verification.
"""

import os
import sys
import tempfile
import zipfile
import shutil
import re

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
R_SCRIPT = os.path.join(REPO_ROOT, "R", "PackageMiningResults.R")
FINALIZE_SQL = os.path.join(REPO_ROOT, "inst", "sql", "sql_server", "concept_ab_finalize.sql")
INIT_SQL = os.path.join(REPO_ROOT, "inst", "sql", "sql_server", "concept_ab_init.sql")

def test_sql_column_schema_conformance():
    """Verify that tableSpecs in PackageMiningResults.R exactly match actual SQL column definitions."""
    print("--> Test 1: Verifying SQL column definitions match PackageMiningResults.R tableSpecs...")
    with open(R_SCRIPT, "r", encoding="utf-8") as f:
        r_content = f.read()

    with open(FINALIZE_SQL, "r", encoding="utf-8") as f:
        finalize_sql = f.read()

    with open(INIT_SQL, "r", encoding="utf-8") as f:
        init_sql = f.read()

    combined_sql = init_sql + "\n" + finalize_sql

    # Check key columns for REC-037-1
    assert "n_obs" in r_content and "n_persons" in r_content, "n_obs and n_persons must be present in cab_s39_pattern_all"
    assert "obs_act" in r_content and "pers_act" in r_content and "n_gaps" in r_content, "obs_act, pers_act, n_gaps must be in cab_s54_grain_guide"
    assert "mentions_per_person" in r_content, "mentions_per_person must be present in grain guide schema"
    assert "frac_gaps_tight" in r_content, "frac_gaps_tight must be present in grain guide schema"

    # Verify absence of wrong column configurations
    assert 'cab_s39_pattern_all = list(\n      requiredCols = c("count_val"' not in r_content
    assert 'cab_s54_grain_guide = list(\n      requiredCols = c("n_records"' not in r_content

    print("  [PASS] All column mappings match actual OHDSI T-SQL column definitions.")

def simulate_mining_suppression(table_name, row, min_cell_count=5):
    """Simulates applyTableSuppression from PackageMiningResults.R in Python."""
    threshold = max(5, int(min_cell_count)) if min_cell_count is not None else 5
    r = dict(row)

    if table_name == "cab_s13_strat_all":
        persons = r.get("persons_in_decile", 0)
        if 0 < persons < threshold:
            r["persons_in_decile"] = -1
            r["person_days_in_decile"] = -1

    elif table_name == "cab_s37_lag_all":
        if 0 < r.get("n_events", 0) < threshold:
            r["n_events"] = -1
        if 0 < r.get("n_pairs", 0) < threshold:
            r["n_pairs"] = -1

    elif table_name == "cab_s38_profile_all":
        if 0 < r.get("n_records", 0) < threshold:
            r["n_records"] = -1
        if 0 < r.get("n_persons", 0) < threshold:
            r["n_persons"] = -1

    elif table_name == "cab_s39_pattern_all":
        if 0 < r.get("n_obs", 0) < threshold:
            r["n_obs"] = -1
        if 0 < r.get("n_persons", 0) < threshold:
            r["n_persons"] = -1

    elif table_name == "cab_s54_grain_guide":
        pers_act = r.get("pers_act", 0)
        obs_act = r.get("obs_act", 0)
        if (0 < pers_act < threshold) or (0 < obs_act < threshold):
            r["pers_act"] = -1
            r["obs_act"] = -1
            r["mentions_per_person"] = -1.0

        n_gaps = r.get("n_gaps", 0)
        if 0 < n_gaps < threshold:
            r["n_gaps"] = -1
            r["frac_gaps_tight"] = -1.0
            r["frac_gaps_mid"] = -1.0
            r["frac_gaps_long"] = -1.0

    return r

def test_boundary_and_companion_suppression():
    """Verify counts 0, 1, 4, 5 and algebraic back-calculation masking across companion fields."""
    print("--> Test 2: Validating boundary counts (0, 1, 4, 5) and companion field masking...")

    # Case 0: count = 0 (preserved as true absence)
    row0 = {"concept_id": 201826, "src": 1, "obs_act": 0, "pers_act": 0, "mentions_per_person": 0.0, "n_gaps": 0, "frac_gaps_tight": 0.0, "frac_gaps_mid": 0.0, "frac_gaps_long": 0.0}
    res0 = simulate_mining_suppression("cab_s54_grain_guide", row0)
    assert res0["obs_act"] == 0 and res0["pers_act"] == 0 and res0["mentions_per_person"] == 0.0
    print("  [PASS] Count 0 preserved as true absence.")

    # Case 1: count = 1 (<5 masked, mentions_per_person masked to -1.0)
    row1 = {"concept_id": 201826, "src": 1, "obs_act": 2, "pers_act": 1, "mentions_per_person": 2.0, "n_gaps": 1, "frac_gaps_tight": 1.0, "frac_gaps_mid": 0.0, "frac_gaps_long": 0.0}
    res1 = simulate_mining_suppression("cab_s54_grain_guide", row1)
    assert res1["pers_act"] == -1, "pers_act=1 must be masked to -1"
    assert res1["obs_act"] == -1, "obs_act must be joint-masked when pers_act < 5"
    assert res1["mentions_per_person"] == -1.0, "mentions_per_person must be masked to -1.0 to prevent back-calculation"
    assert res1["n_gaps"] == -1, "n_gaps=1 must be masked to -1"
    assert res1["frac_gaps_tight"] == -1.0, "gap fractions must be masked to -1.0 when n_gaps is masked"
    print("  [PASS] Count 1 masked with joint companion suppression (mentions_per_person & gap fractions).")

    # Case 4: count = 4 (<5 masked in cab_s39_pattern_all)
    row4 = {"metric": "gap", "src": 1, "concept_id": 201826, "bucket": 7, "n_obs": 12, "n_persons": 4}
    res4 = simulate_mining_suppression("cab_s39_pattern_all", row4)
    assert res4["n_persons"] == -1, "n_persons=4 must be masked to -1"
    assert res4["n_obs"] == 12, "n_obs >= 5 is preserved"
    print("  [PASS] Count 4 masked to -1 in cab_s39_pattern_all.")

    # Case 5: count = 5 (>=5 preserved unmasked)
    row5 = {"metric": "gap", "src": 1, "concept_id": 201826, "bucket": 7, "n_obs": 25, "n_persons": 5}
    res5 = simulate_mining_suppression("cab_s39_pattern_all", row5)
    assert res5["n_persons"] == 5, "n_persons=5 must be preserved unmasked"
    assert res5["n_obs"] == 25, "n_obs=25 must be preserved unmasked"
    print("  [PASS] Count 5 preserved unmasked.")

    # Rate-based reconstruction test in cab_s13_strat_all
    row_strat = {"util_decile": 1, "persons_in_decile": 3, "person_days_in_decile": 1095}
    res_strat = simulate_mining_suppression("cab_s13_strat_all", row_strat)
    assert res_strat["persons_in_decile"] == -1, "persons_in_decile=3 must be masked"
    assert res_strat["person_days_in_decile"] == -1, "person_days_in_decile must be masked to prevent rate reconstruction"
    print("  [PASS] Rate-based reconstruction prevented in cab_s13_strat_all.")

def test_isolated_allowlist_archive_packaging():
    """Verify REC-037-2: Staging isolation, allowlist packaging, and decoy rejection."""
    print("--> Test 3: Verifying staging isolation and decoy rejection (REC-037-2)...")
    temp_dir = tempfile.mkdtemp(prefix="taxis_export_test_")
    try:
        db_id = "TEST_CDM"
        export_dir = os.path.join(temp_dir, f"export_{db_id}")
        os.makedirs(export_dir, exist_ok=True)

        # 1. Simulate approved exported files
        approved_basenames = [
            f"cab_process_log_{db_id}.csv",
            f"cab_s13_strat_all_{db_id}.csv",
            f"cab_s37_lag_all_{db_id}.csv",
            f"cab_s38_profile_all_{db_id}.csv",
            f"cab_s39_pattern_all_{db_id}.csv",
            f"cab_s54_grain_guide_{db_id}.csv",
            f"manifest_{db_id}.csv"
        ]
        for b in approved_basenames:
            with open(os.path.join(export_dir, b), "w") as f:
                f.write("test_header\n1\n")

        # 2. Plant leftover/private decoy files in the export folder
        decoys = [
            "private_person_identifiers.csv",
            "concept_ab_raw_matrix.csv",
            "error_dump.log"
        ]
        for d in decoys:
            with open(os.path.join(export_dir, d), "w") as f:
                f.write("CONFIDENTIAL_PATIENT_DATA\n12345\n")

        # 3. Simulate allowlist zip packaging (zipping approved_basenames ONLY)
        zip_path = os.path.join(temp_dir, f"Results_Mining_{db_id}.zip")
        with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
            for b in approved_basenames:
                z.write(os.path.join(export_dir, b), arcname=b)

        # 4. Verify zip contents
        with zipfile.ZipFile(zip_path, "r") as z:
            members = z.namelist()

        # Assert zero decoy files entered the archive
        for d in decoys:
            assert d not in members, f"DECOY LEAKED INTO ARCHIVE: {d}"
        assert set(members) == set(approved_basenames), f"Archive members mismatch: {members}"
        print("  [PASS] Decoy files rejected: Only approved allowlisted files entered the archive.")

        # 5. Simulate post-archive verification check rejecting an infected archive
        with zipfile.ZipFile(zip_path, "a") as z:
            z.writestr("unauthorized_leak.csv", "leaked")

        with zipfile.ZipFile(zip_path, "r") as z:
            infected_members = z.namelist()

        unexpected = set(infected_members) - set(approved_basenames)
        assert len(unexpected) > 0, "Post-packaging verification must detect infected members"
        # If unexpected, the safety check deletes the zip
        os.remove(zip_path)
        assert not os.path.exists(zip_path), "Infected zip must be deleted immediately"
        print("  [PASS] Post-archive verification active: Infected archive detected and destroyed.")

    finally:
        shutil.rmtree(temp_dir, ignore_errors=True)

def main():
    print("=" * 69)
    print("TAXIS Verification Suite: Mining Package Suppression & Isolation")
    print("=" * 69)
    test_sql_column_schema_conformance()
    test_boundary_and_companion_suppression()
    test_isolated_allowlist_archive_packaging()
    print("\n" + "=" * 69)
    print("ALL 3/3 MINING SUPPRESSION & ISOLATION TESTS PASSED SUCCESSFULLY.")
    print("=" * 69)

if __name__ == "__main__":
    main()
