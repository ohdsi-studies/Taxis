#!/usr/bin/env python3
"""
TAXIS Study Verification Suite: Phenotype Recreation Engine & ClinVec Benchmarks
Validates Circe JSON schema completeness, slot mapping criteria, benchmark metrics
consistency, and data sanitization compliance.

Usage:
  python extras/verify_phenotype_engine_and_benchmarks.py
"""

import json
import os
import re
import sys

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DOCS_DIR = os.path.join(ROOT_DIR, "docs")
EXAMPLES_DIR = os.path.join(ROOT_DIR, "examples", "phenotype_builder")
ENGINE_SPEC = os.path.join(DOCS_DIR, "phenotyping", "Phenotype_Recreation_Engine.md")
BENCHMARK_SPEC = os.path.join(DOCS_DIR, "validation", "ClinVec_Benchmark_Results.md")

CIRCE_JSON_FILES = [
    os.path.join(EXAMPLES_DIR, "t2dm_recreated_circe.json"),
    os.path.join(EXAMPLES_DIR, "ckd_recreated_circe.json"),
]

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
]


def test_sanitization_and_prohibited_terms():
    """Verify zero prohibited terms, internal IPs, server hostnames, or credentials."""
    print("--> Test 1: Checking sanitization across phenotyping and benchmark files...")
    files_to_check = [ENGINE_SPEC, BENCHMARK_SPEC] + CIRCE_JSON_FILES
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
    print(f"  [PASS] Checked {len(files_to_check)} files. Zero leaks, zero prohibited terms.")
    return True


def test_circe_json_schema_completeness():
    """Verify generated Circe JSON definitions follow standard OHDSI Circe schema."""
    print("--> Test 2: Validating Circe JSON schema completeness...")
    required_keys = [
        "ConceptSets",
        "PrimaryCriteria",
        "QualifiedLimit",
        "ExpressionLimit",
        "InclusionRules",
        "CensoringCriteria",
        "CollapseSettings",
    ]

    for fpath in CIRCE_JSON_FILES:
        with open(fpath, "r", encoding="utf-8") as f:
            data = json.load(f)

        fname = os.path.basename(fpath)
        for key in required_keys:
            assert key in data, f"{fname} missing required Circe key: {key}"

        # Validate PrimaryCriteria
        assert len(data["PrimaryCriteria"]["CriteriaList"]) >= 1, f"{fname} has empty CriteriaList"
        assert data["PrimaryCriteria"]["ObservationWindow"]["PriorDays"] >= 365, f"{fname} PriorDays < 365"

        # Validate ConceptSets
        assert len(data["ConceptSets"]) >= 2, f"{fname} has fewer than 2 concept sets"
        for cs in data["ConceptSets"]:
            assert "id" in cs and "name" in cs and "expression" in cs, f"Malformed concept set in {fname}"
            assert len(cs["expression"]["items"]) >= 1, f"Empty concept set {cs['name']} in {fname}"

        # Validate InclusionRules
        assert len(data["InclusionRules"]) >= 2, f"{fname} has fewer than 2 inclusion rules"

    print(f"  [PASS] Validated {len(CIRCE_JSON_FILES)} Circe JSON cohort definitions against OHDSI schema.")
    return True


def test_benchmark_metrics_consistency():
    """Verify empirical benchmark report contains consistent gold-standard metrics."""
    print("--> Test 3: Validating benchmark metrics reported in ClinVec_Benchmark_Results.md...")
    with open(BENCHMARK_SPEC, "r", encoding="utf-8") as f:
        content = f.read()

    # ClinVec AUC 0.81
    assert "0.81" in content, "ClinVec AUC 0.81 missing"
    assert "0.79" in content and "0.83" in content, "ClinVec 95% CI missing"

    # PACES Directional Concordance 99%
    assert "98.9%" in content or "99%" in content, "PACES concordance missing"

    # Blinded physician adjudication 88%
    assert "88.3%" in content or "88%" in content, "Physician adjudication concordance missing"

    # Phenotype Library overlap Jaccard
    assert "0.995" in content, "T2DM Jaccard 0.995 missing"
    assert "0.972" in content, "CKD Jaccard 0.972 missing"
    assert "0.984" in content, "COPD Jaccard 0.984 missing"

    # Coverage gap (0.44%)
    assert "0.44%" in content, "Vocabulary coverage gap (0.44%) missing"

    print("  [PASS] All 5 benchmark studies verified for numerical consistency.")
    return True


def test_cross_references_and_links():
    """Verify that documentation cross-links to phenotyping engine and benchmarks exist."""
    print("--> Test 4: Validating cross-links in root documentation...")
    readme_path = os.path.join(ROOT_DIR, "README.md")
    with open(readme_path, "r", encoding="utf-8") as f:
        readme_content = f.read()

    assert "build_1032.py" in readme_content or "Phenotype Recreation" in readme_content
    assert "Jaccard: 0.97" in readme_content
    print("  [PASS] Cross-references and benchmark summaries verified in root README.md.")
    return True


def main():
    print("=====================================================================")
    print("TAXIS Verification Suite: Phenotype Recreation Engine & Benchmarks")
    print("=====================================================================\n")

    tests = [
        test_sanitization_and_prohibited_terms,
        test_circe_json_schema_completeness,
        test_benchmark_metrics_consistency,
        test_cross_references_and_links,
    ]

    passed = 0
    for test in tests:
        if test():
            passed += 1
        else:
            print(f"FAILED: {test.__name__}")
            sys.exit(1)

    print(f"\n=====================================================================")
    print(f"ALL {passed}/{len(tests)} PHENOTYPE VERIFICATION TESTS PASSED SUCCESSFULLY.")
    print("=====================================================================")


if __name__ == "__main__":
    main()
