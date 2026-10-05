#!/usr/bin/env python3
"""
Test Suite: Concept Pair Temporal Classifier Prototype Demo
===========================================================
Verifies that the downstream concept pair classifier demo executes cleanly
against the PostgreSQL database (work_cab_test.cab_s55_pair_all) and enforces:
1. Strict small-cell privacy protection and anti-reconstruction rules (REC-069-1).
2. Descriptive temporal sequence categorization without ungrounded clinical roles (REC-069-2).
3. Concordance across live database queries on the local fixture.
"""

import sys
import os

sys.path.insert(0, os.path.dirname(__file__))
from classify_pairs import (
    classify_pairs,
    sanitize_pair_record,
    compute_directionality_ratio,
    categorize_temporal_direction
)


def main():
    print("======================================================================")
    print("   TAXIS DOWNSTREAM CONCEPT PAIR CLASSIFIER DEMO VERIFICATION TEST    ")
    print("======================================================================")

    # Test 1: Unit tests for DR calculation and descriptive temporal categorization
    print("--> Test 1: Verifying Directionality Ratio (DR) calculation & descriptive categories...")
    dr_forward = compute_directionality_ratio(92, 34)
    expected_dr = (92 + 0.5) / (34 + 0.5)
    assert abs(dr_forward - expected_dr) < 1e-4, f"DR forward mismatch: {dr_forward} vs {expected_dr}"
    assert categorize_temporal_direction(92, 34, dr_forward).startswith("Empirically Preceding")

    dr_reverse = compute_directionality_ratio(10, 50)
    assert categorize_temporal_direction(10, 50, dr_reverse).startswith("Empirically Following")

    dr_balanced = compute_directionality_ratio(25, 25)
    assert categorize_temporal_direction(25, 25, dr_balanced).startswith("Empirically Balanced")

    # Edge case: zero directional counts
    assert categorize_temporal_direction(0, 0, 1.0) == "No Directional Precedence Observed"
    # Edge case: directional counts < 5
    assert categorize_temporal_direction(10, 3, 3.0) == "Directionality Suppressed (<5 count)"
    print("    [PASS] DR computation and descriptive categories verified.")

    # Test 2: Unit test for anti-reconstruction and small-cell privacy protection (REC-069-1)
    print("--> Test 2: Verifying Anti-Reconstruction Privacy Safeguards (Invented 10/3 Example)...")
    # Row: cid_a, cname_a, cid_b, cname_b, obs_all, obs_sd, obs_after, obs_before, lift_after, dir_ab
    test_row = (99901, "Test Cond", 99902, "Test Exp", 20, 7, 10, 3, 2.5, 0.769)
    sanitized = sanitize_pair_record(test_row)

    assert sanitized is not None, "Record unexpectedly withheld"
    # Small before count (3) must be masked to -1
    assert sanitized["obs_before"] == -1, f"Expected masked obs_before, got {sanitized['obs_before']}"
    # Total obs must be masked to -1 to prevent complementary subtraction (20 - 7 - 10 = 3)
    assert sanitized["obs_all"] == -1, f"Expected masked obs_all, got {sanitized['obs_all']}"
    # Derived DR must be None to prevent algebraic inversion ((10+0.5)/DR - 0.5 = 3)
    assert sanitized["dr_corrected"] is None, f"Expected None dr_corrected, got {sanitized['dr_corrected']}"
    assert sanitized["dir_ab_sql"] is None, f"Expected None dir_ab_sql, got {sanitized['dir_ab_sql']}"
    assert sanitized["temporal_category"] == "Directionality Suppressed (<5 count)"

    # Sub-test: total obs < 5 must be withheld completely
    small_total_row = (99901, "Test Cond", 99903, "Rare Exp", 4, 1, 2, 1, 1.5, 0.66)
    assert sanitize_pair_record(small_total_row) is None, "Row with total < 5 was not withheld"

    # Sub-test: after=0, before=0 (no directionality observed) must have None DR
    no_dir_row = (99901, "Test Cond", 99904, "SameDay Only", 10, 10, 0, 0, 1.25, 0.5)
    sanitized_nodir = sanitize_pair_record(no_dir_row)
    assert sanitized_nodir is not None, "No-direction record unexpectedly withheld"
    assert sanitized_nodir["obs_all"] == 10
    assert sanitized_nodir["obs_same_day"] == 10
    assert sanitized_nodir["obs_after"] == 0
    assert sanitized_nodir["obs_before"] == 0
    assert sanitized_nodir["temporal_category"] == "No Directional Precedence Observed"
    assert sanitized_nodir["dr_corrected"] is None, f"Expected None dr_corrected for no-direction, got {sanitized_nodir['dr_corrected']}"
    assert sanitized_nodir["dir_ab_sql"] == 0.5
    print("    [PASS] Small-cell suppression, subtraction protection, and anti-inversion verified.")

    # Test 3: Live execution against PostgreSQL fixture
    print("--> Test 3: Querying live PostgreSQL fixture (work_cab_test.cab_s55_pair_all)...")
    results = classify_pairs(concept_id=260139, min_obs=5, limit=10)
    assert len(results) > 0, "No pairs retrieved for Acute bronchitis (concept_id = 260139)"
    print(f"    Retrieved {len(results)} pairs for Acute bronchitis.")

    # Check allowed privacy-safe fields in return dict
    allowed_keys = {
        "concept_id_a", "concept_name_a", "concept_id_b", "concept_name_b",
        "obs_all", "obs_same_day", "obs_after", "obs_before",
        "lift_after", "dir_ab_sql", "dr_corrected", "temporal_category"
    }
    for r in results:
        assert set(r.keys()) == allowed_keys, f"Unexpected fields returned: {set(r.keys()) - allowed_keys}"

    # Locate acetaminophen pair
    apap_pair = None
    for r in results:
        if "acetaminophen" in r["concept_name_b"].lower():
            apap_pair = r
            break

    assert apap_pair is not None, "Acetaminophen pair not found for Acute bronchitis"
    print(f"    Found pair: {apap_pair['concept_name_a']} <-> {apap_pair['concept_name_b']}")
    print(f"    Obs: {apap_pair['obs_all']} | After: {apap_pair['obs_after']} | Before: {apap_pair['obs_before']}")
    print(f"    Corrected DR: {apap_pair['dr_corrected']}")
    print(f"    Assigned Category: {apap_pair['temporal_category']}")

    assert apap_pair["dr_corrected"] >= 1.50, f"Expected DR >= 1.50, got {apap_pair['dr_corrected']}"
    assert apap_pair["temporal_category"].startswith("Empirically Preceding")
    print("    [PASS] Live database classification verified.")

    print("\n======================================================================")
    print("   ALL CLASSIFIER PROTOTYPE DEMO TESTS PASSED SUCCESSFULLY            ")
    print("======================================================================")


if __name__ == "__main__":
    main()
