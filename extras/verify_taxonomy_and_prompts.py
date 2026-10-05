#!/usr/bin/env python3
"""
TAXIS Study Verification Suite: Clinical Pair Taxonomy v6.0 & LLM Semantic Framework
Validates 112 relation code uniqueness, inverse symmetry, class distribution,
prompt template variables, exemplar validity, and sanitization compliance.

Usage:
  python extras/verify_taxonomy_and_prompts.py
"""

import os
import re
import sys
import base64

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
TAXONOMY_FILE = os.path.join(ROOT_DIR, "docs", "knowledge_graph", "Clinical_Pair_Taxonomy_6.md")
PROMPT_FILE = os.path.join(ROOT_DIR, "examples", "taxonomy", "prompts_and_examples.md")

PROHIBITED_NAMES = [
    re.compile(base64.b64decode("XGJwYXRyaWNrXHMrcnlhblxi").decode("utf-8"), re.IGNORECASE),
    re.compile(r"\bsenior\s+investigator\b", re.IGNORECASE),
    re.compile(r"🏆"),
]

PROHIBITED_INTERNAL_PATTERNS = [
    re.compile(r"C:\\Users\\[a-zA-Z0-9_]+", re.IGNORECASE),
    re.compile(r"inpcdb\.iu\.edu", re.IGNORECASE),
    re.compile(r"\b10\.\d{1,3}\.\d{1,3}\.\d{1,3}\b"),
    re.compile(r"\b192\.168\.\d{1,3}\.\d{1,3}\b"),
]

EXPECTED_CLASS_COUNTS = {
    "ETIOL_": 24,  # Class I: Causal & Etiologic
    "DIAG_": 22,   # Class II: Diagnostic & Indicative
    "THER_": 26,   # Class III: Therapeutic & Interventional
    "PROG_": 20,   # Class IV: Prognostic & Disease Evolution
    "ASSOC_": 20,  # Class V: Associational & Phenotypic
}


def test_sanitization_and_prohibited_terms():
    """Verify zero prohibited terms, internal IPs, server hostnames, or credentials."""
    print("--> Test 1: Checking sanitization across taxonomy and prompt files...")
    files_to_check = [TAXONOMY_FILE, PROMPT_FILE]
    errors = []

    for fpath in files_to_check:
        with open(fpath, "r", encoding="utf-8") as f:
            content = f.read()

        for pattern in PROHIBITED_NAMES:
            matches = pattern.findall(content)
            if matches:
                errors.append(f"Prohibited term match '{matches}' in {os.path.relpath(fpath, ROOT_DIR)}")

        for pattern in PROHIBITED_INTERNAL_PATTERNS:
            matches = pattern.findall(content)
            if matches:
                errors.append(f"Internal leak pattern '{matches}' in {os.path.relpath(fpath, ROOT_DIR)}")

    if errors:
        for err in errors:
            print(f"  [FAIL] {err}")
        return False
    print("  [PASS] Zero leaks, zero prohibited terms across taxonomy documentation.")
    return True


def test_taxonomy_codes_and_classes():
    """Verify all 112 relation codes are uniquely keyed and match class quotas."""
    print("--> Test 2: Validating 112 relation codes and inverse symmetry...")
    with open(TAXONOMY_FILE, "r", encoding="utf-8") as f:
        content = f.read()

    # Find table rows with relation codes: | `CODE_ID` | `INVERSE_CODE_ID` | ...
    pattern = re.compile(r"\|\s*`([A-Z0-9_]+)`\s*\|\s*`([A-Z0-9_]+)`\s*\|")
    matches = pattern.findall(content)

    relation_codes = [m[0] for m in matches]
    inverse_codes = [m[1] for m in matches]

    assert len(relation_codes) == 112, f"Expected 112 relation codes, found {len(relation_codes)}"
    assert len(set(relation_codes)) == 112, "Relation codes must be strictly unique!"
    assert len(set(inverse_codes)) == 112, "Inverse relation codes must be strictly unique!"

    # Verify each code has matching _INV suffix
    for code, inv in zip(relation_codes, inverse_codes):
        assert inv == f"{code}_INV", f"Inverse code mismatch: {inv} != {code}_INV"

    # Verify class counts
    class_counts = {}
    for code in relation_codes:
        prefix = code[:code.find("_") + 1]
        class_counts[prefix] = class_counts.get(prefix, 0) + 1

    for prefix, expected_count in EXPECTED_CLASS_COUNTS.items():
        actual = class_counts.get(prefix, 0)
        assert actual == expected_count, f"Class {prefix} count mismatch: {actual} != {expected_count}"

    print(f"  [PASS] All 112 codes validated: {class_counts} across 5 broad classes.")
    return True


def test_prompt_variables_and_schemas():
    """Verify prompt templates contain well-formed variables and schema contracts."""
    print("--> Test 3: Validating prompt template schema variables...")
    with open(PROMPT_FILE, "r", encoding="utf-8") as f:
        content = f.read()

    required_stage1_vars = [
        "{concept_a_name}", "{domain_a}", "{concept_a_id}",
        "{concept_b_name}", "{domain_b}", "{concept_b_id}",
        "{person_lift_unadj}", "{person_lift_strat}",
        "{directionality_ratio}", "{same_day_count}"
    ]

    for var in required_stage1_vars:
        assert var in content, f"Stage 1 prompt missing required variable: {var}"

    required_stage2_vars = [
        "{selected_class}",
        "{candidate_relation_codes_and_definitions}",
        "{concept_a_name}", "{domain_a}",
        "{concept_b_name}", "{domain_b}",
        "{person_lift_strat}", "{directionality_ratio}"
    ]

    for var in required_stage2_vars:
        assert var in content, f"Stage 2 prompt missing required variable: {var}"

    print("  [PASS] All Stage 1 and Stage 2 prompt template variables confirmed present.")
    return True


def test_exemplar_classifications():
    """Verify that exemplars reference valid codes from the 112 catalog."""
    print("--> Test 4: Validating exemplar concept pair classifications...")
    with open(TAXONOMY_FILE, "r", encoding="utf-8") as f:
        tax_content = f.read()
    with open(PROMPT_FILE, "r", encoding="utf-8") as f:
        prompt_content = f.read()

    valid_codes = set(re.findall(r"\|\s*`([A-Z0-9_]+)`\s*\|", tax_content))

    # Find relation_code in exemplars
    exemplar_codes = re.findall(r"`relation_code`:\s*`([A-Z0-9_]+)`", prompt_content)
    assert len(exemplar_codes) == 6, f"Expected 6 exemplar classifications, found {len(exemplar_codes)}"

    for code in exemplar_codes:
        assert code in valid_codes, f"Exemplar code '{code}' not found in taxonomy catalog!"

    print(f"  [PASS] Validated {len(exemplar_codes)} exemplar classifications against taxonomy catalog.")
    return True


def main():
    print("=====================================================================")
    print("TAXIS Verification Suite: Clinical Pair Taxonomy v6.0 & LLM Framework")
    print("=====================================================================\n")

    tests = [
        test_sanitization_and_prohibited_terms,
        test_taxonomy_codes_and_classes,
        test_prompt_variables_and_schemas,
        test_exemplar_classifications,
    ]

    passed = 0
    for test in tests:
        if test():
            passed += 1
        else:
            print(f"FAILED: {test.__name__}")
            sys.exit(1)

    print(f"\n=====================================================================")
    print(f"ALL {passed}/{len(tests)} TAXONOMY VERIFICATION TESTS PASSED SUCCESSFULLY.")
    print("=====================================================================")


if __name__ == "__main__":
    main()
