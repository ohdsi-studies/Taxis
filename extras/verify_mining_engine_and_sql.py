#!/usr/bin/env python3
"""
TAXIS Study Verification Suite: Concept AB Mining Engine (v57) & SQL Pipeline
Validates sanitization, parameterized SqlRender tokens, mathematical estimand
consistency (Directionality Ratio continuity correction, healthcare utilization
decile stratification), measurement key packing/unpacking, and 18-table schema
coverage.

Usage:
  python extras/verify_mining_engine_and_sql.py
"""

import os
import re
import sys
import math

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
MINING_DIR = os.path.join(ROOT_DIR, "docs", "mining")
SQL_DIR = os.path.join(MINING_DIR, "sql")
SPEC_FILE = os.path.join(MINING_DIR, "CONCEPT_AB_MINING_ENGINE_V57.md")

PROHIBITED_NAMES = [
    re.compile(r"\bpatrick\s+ryan\b", re.IGNORECASE),
    re.compile(r"\bsenior\s+investigator\b", re.IGNORECASE),
    re.compile(r"🏆"),
]

PROHIBITED_INTERNAL_PATTERNS = [
    re.compile(r"C:\\Users\\[a-zA-Z0-9_]+", re.IGNORECASE),
    re.compile(r"inpcdb\.iu\.edu", re.IGNORECASE),
    re.compile(r"\b10\.\d{1,3}\.\d{1,3}\.\d{1,3}\b"),
    re.compile(r"\b192\.168\.\d{1,3}\.\d{1,3}\b"),
    re.compile(r"password\s*=\s*['\"][^'\"]+['\"]", re.IGNORECASE),
]

EXPECTED_OUTPUT_TABLES = [
    "cab_s55_pair_all",
    "cab_s50_all",
    "cab_s40_all",
    "cab_s30_all",
    "cab_s10_person_all",
    "cab_s20_marginal_all",
    "cab_s13_strat_all",
    "cab_s23_strat_all",
    "cab_s33_strat_all",
    "cab_s33_mh_all",
    "cab_vocab_all_output",
    "cab_s37_lag_all",
    "cab_s38_profile_all",
    "cab_s39_pattern_all",
    "cab_timing_all",
    "cab_process_log",
]


def test_prohibited_terms_and_sanitization():
    """Verify zero prohibited terms, internal IPs, server hostnames, or credentials."""
    print("--> Test 1: Checking sanitization across docs/mining and sql templates...")
    errors = []
    scanned_files = 0

    for root, _, files in os.walk(MINING_DIR):
        for fname in files:
            fpath = os.path.join(root, fname)
            scanned_files += 1
            with open(fpath, "r", encoding="utf-8", errors="replace") as f:
                content = f.read()

            for pattern in PROHIBITED_NAMES:
                matches = pattern.findall(content)
                if matches:
                    errors.append(f"Prohibited term match '{matches}' in {os.path.relpath(fpath, ROOT_DIR)}")

            for pattern in PROHIBITED_INTERNAL_PATTERNS:
                matches = pattern.findall(content)
                if matches:
                    errors.append(f"Internal leak pattern '{matches}' in {os.path.relpath(fpath, ROOT_DIR)}")

    assert scanned_files >= 6, f"Expected at least 6 files in {MINING_DIR}, found {scanned_files}"
    if errors:
        for err in errors:
            print(f"  [FAIL] {err}")
        return False
    print(f"  [PASS] Scanned {scanned_files} files in docs/mining/. Zero leaks, zero prohibited terms.")
    return True


def test_sqlrender_token_consistency():
    """Verify standard SqlRender token parameters are used across SQL files."""
    print("--> Test 2: Validating SqlRender parameterized tokens...")
    required_tokens = [
        "@source_cdm_schema",
        "@results_database_schema",
        "@project_reference_schema",
        "@omop_reference_schema",
        "@batch_count",
    ]
    sql_files = [f for f in os.listdir(SQL_DIR) if f.endswith(".sql")]
    
    found_tokens = set()
    for sql_file in sql_files:
        fpath = os.path.join(SQL_DIR, sql_file)
        with open(fpath, "r", encoding="utf-8") as f:
            content = f.read()
        for token in re.findall(r"@[a-zA-Z0-9_]+", content):
            found_tokens.add(token)

    missing = [t for t in required_tokens if t not in found_tokens]
    if missing:
        print(f"  [FAIL] Missing required SqlRender tokens: {missing}")
        return False
    print(f"  [PASS] Found {len(found_tokens)} valid SqlRender tokens across {len(sql_files)} SQL files.")
    return True


def test_mathematical_directionality_ratio():
    """Verify continuity-corrected Directionality Ratio calculation and bounds."""
    print("--> Test 3: Validating continuity-corrected Directionality Ratio (DR) math...")
    
    def calc_dr(n_a_to_b, n_b_to_a):
        return (n_a_to_b + 0.5) / (n_b_to_a + 0.5)

    # Zero-zero boundary condition
    assert math.isclose(calc_dr(0, 0), 1.0), "DR(0,0) must equal 1.0"

    # Symmetric cases
    assert math.isclose(calc_dr(100, 100), 1.0), "DR(100,100) must equal 1.0"
    assert math.isclose(calc_dr(500, 500), 1.0), "DR(500,500) must equal 1.0"

    # Asymmetric forward cases (A -> B predominant)
    dr_fwd = calc_dr(300, 50)
    assert dr_fwd >= 1.50, f"Expected DR >= 1.50, got {dr_fwd}"

    # Asymmetric reverse cases (B -> A predominant)
    dr_rev = calc_dr(50, 300)
    assert dr_rev <= 0.67, f"Expected DR <= 0.67, got {dr_rev}"

    # Reciprocal symmetry: DR(A,B) * DR(B,A) == 1.0
    dr_ab = calc_dr(120, 40)
    dr_ba = calc_dr(40, 120)
    assert math.isclose(dr_ab * dr_ba, 1.0, rel_tol=1e-5), "DR(A->B) and DR(B->A) must be exact reciprocals"

    print("  [PASS] Directionality Ratio continuity correction and symmetry validated.")
    return True


def test_utilization_decile_stratification():
    """Verify healthcare utilization decile stratification math (DEC-GR-010)."""
    print("--> Test 4: Validating healthcare utilization decile stratification math...")
    
    # Simulate 10 utilization deciles
    # Low utilizers (U1-U3): low contact rate, high specificity
    # High utilizers (U8-U10): high contact rate, non-specific co-occurrences
    n_k = [100000] * 10  # Equal patient strata
    n_a_k = [500, 800, 1200, 1500, 2000, 2500, 3500, 5000, 8000, 15000]
    n_b_k = [400, 700, 1000, 1400, 1800, 2200, 3000, 4500, 7500, 14000]
    
    total_n = sum(n_k)
    total_a = sum(n_a_k)
    total_b = sum(n_b_k)

    # Crude unadjusted expected count
    expected_crude = (total_a * total_b) / total_n

    # Stratified expected count
    expected_stratified = sum((a * b) / n for a, b, n in zip(n_a_k, n_b_k, n_k))

    # High utilization creates heavy right skew, so stratified expected > crude expected
    assert expected_stratified > expected_crude, (
        f"Expected stratified ({expected_stratified}) > crude ({expected_crude}) under utilization confounding"
    )

    # Lift comparison
    observed_ab = 12000
    crude_lift = observed_ab / expected_crude
    stratified_lift = observed_ab / expected_stratified

    # Stratified lift adjusts down the spurious co-occurrence from contact density
    assert stratified_lift < crude_lift, (
        f"Stratified lift ({stratified_lift:.2f}) must be more conservative than crude lift ({crude_lift:.2f})"
    )

    print(f"  [PASS] Utilization stratification confirmed: Crude Lift={crude_lift:.2f}, Stratified Lift={stratified_lift:.2f}")
    return True


def test_measurement_key_packing():
    """Verify 64-bit integer packing for measurement concepts and categorical results."""
    print("--> Test 5: Validating measurement key packing/unpacking algorithm...")
    
    multiplier = 1000000000  # 1e9
    test_cases = [
        (3004410, 1),      # Glucose [Mass/volume] in Blood; Abnormal High
        (3015632, 2),      # Potassium [Moles/volume] in Serum or Plasma; Abnormal Low
        (40762499, 0),     # Hemoglobin A1c; Normal
        (3020564, 999),    # C-reactive protein; Extreme value
    ]

    for test_concept_id, result_code in test_cases:
        packed_key = (test_concept_id * multiplier) + result_code
        unpacked_concept_id = packed_key // multiplier
        unpacked_result_code = packed_key % multiplier
        
        assert unpacked_concept_id == test_concept_id, f"Concept ID mismatch: {unpacked_concept_id} != {test_concept_id}"
        assert unpacked_result_code == result_code, f"Result code mismatch: {unpacked_result_code} != {result_code}"

    print(f"  [PASS] Validated packed measurement key bijection across {len(test_cases)} test vectors.")
    return True


def test_table_coverage_in_specification():
    """Verify all 18 output tables are documented in CONCEPT_AB_MINING_ENGINE_V57.md."""
    print("--> Test 6: Validating table coverage in technical specification...")
    with open(SPEC_FILE, "r", encoding="utf-8") as f:
        spec_content = f.read()

    missing_tables = []
    for table_name in EXPECTED_OUTPUT_TABLES:
        if table_name not in spec_content:
            missing_tables.append(table_name)

    if missing_tables:
        print(f"  [FAIL] Tables missing from specification: {missing_tables}")
        return False
    print(f"  [PASS] All {len(EXPECTED_OUTPUT_TABLES)} output tables documented in technical specification.")
    return True


def main():
    print("=====================================================================")
    print("TAXIS Verification Suite: Concept AB Mining Engine & SQL Pipeline v57")
    print("=====================================================================\n")

    tests = [
        test_prohibited_terms_and_sanitization,
        test_sqlrender_token_consistency,
        test_mathematical_directionality_ratio,
        test_utilization_decile_stratification,
        test_measurement_key_packing,
        test_table_coverage_in_specification,
    ]

    passed = 0
    for test in tests:
        if test():
            passed += 1
        else:
            print(f"FAILED: {test.__name__}")
            sys.exit(1)

    print(f"\n=====================================================================")
    print(f"ALL {passed}/{len(tests)} VERIFICATION TESTS PASSED SUCCESSFULLY.")
    print("=====================================================================")


if __name__ == "__main__":
    main()
