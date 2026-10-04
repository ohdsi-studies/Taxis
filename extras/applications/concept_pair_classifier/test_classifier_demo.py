#!/usr/bin/env python3
"""
Test Suite: Concept Pair Clinical Classifier Prototype Demo
===========================================================
Verifies that the downstream concept pair classifier demo executes cleanly
against the PostgreSQL database (work_cab_test.cab_s55_pair_all) and enforces
all required classification logic, privacy cell suppression, and metric mapping.
"""

import sys
import os

sys.path.insert(0, os.path.dirname(__file__))
from classify_pairs import classify_pairs, compute_directionality_ratio, categorize_pair, suppress_cell


def main():
    print("======================================================================")
    print("   TAXIS DOWNSTREAM CONCEPT PAIR CLASSIFIER DEMO VERIFICATION TEST    ")
    print("======================================================================")

    # Test 1: Unit tests for DR calculation and categorization
    print("--> Test 1: Verifying Directionality Ratio (DR) calculation...")
    dr_forward = compute_directionality_ratio(92, 34)
    expected_dr = (92 + 0.5) / (34 + 0.5)
    assert abs(dr_forward - expected_dr) < 1e-4, f"DR forward mismatch: {dr_forward} vs {expected_dr}"
    assert categorize_pair(dr_forward, 1.34).startswith("Forward Predominant")

    dr_reverse = compute_directionality_ratio(10, 50)
    assert categorize_pair(dr_reverse, 2.0).startswith("Reverse Predominant")

    dr_balanced = compute_directionality_ratio(25, 25)
    assert categorize_pair(dr_balanced, 1.0).startswith("Concurrent / Balanced")
    print("    [PASS] DR computation and category thresholds verified.")

    # Test 2: Unit test for privacy cell suppression (< 5 -> -1)
    print("--> Test 2: Verifying Small-Cell Privacy Suppression (< 5 -> -1)...")
    assert suppress_cell(0) == 0
    assert suppress_cell(1) == -1
    assert suppress_cell(4) == -1
    assert suppress_cell(5) == 5
    assert suppress_cell(100) == 100
    print("    [PASS] Small-cell suppression verified.")

    # Test 3: Live execution against PostgreSQL fixture
    print("--> Test 3: Querying live PostgreSQL fixture (work_cab_test.cab_s55_pair_all)...")
    results = classify_pairs(concept_id=260139, min_obs=5, limit=10)
    assert len(results) > 0, "No pairs retrieved for Acute bronchitis (concept_id = 260139)"
    print(f"    Retrieved {len(results)} pairs for Acute bronchitis.")

    # Locate acetaminophen pair
    apap_pair = None
    for r in results:
        if "acetaminophen" in r["concept_name_b"].lower():
            apap_pair = r
            break

    assert apap_pair is not None, "Acetaminophen pair not found for Acute bronchitis"
    print(f"    Found pair: {apap_pair['concept_name_a']} <-> {apap_pair['concept_name_b']}")
    print(f"    Obs: {apap_pair['obs_all']} | After: {apap_pair['obs_after']} | Before: {apap_pair['obs_before']}")
    print(f"    SQL dir_ab: {apap_pair['dir_ab_sql']} | Corrected DR: {apap_pair['dr_corrected']}")
    print(f"    Assigned Category: {apap_pair['candidate_category']}")

    assert apap_pair["dr_corrected"] >= 1.50, f"Expected DR >= 1.50, got {apap_pair['dr_corrected']}"
    assert apap_pair["candidate_category"].startswith("Forward Predominant")
    print("    [PASS] Live database classification verified.")

    print("\n======================================================================")
    print("   ALL CLASSIFIER PROTOTYPE DEMO TESTS PASSED SUCCESSFULLY            ")
    print("======================================================================")


if __name__ == "__main__":
    main()
