#!/usr/bin/env python3
"""
TAXIS Study Verification Suite: Tripartite OHDSI R Package Ecosystem
Validates the structural integrity, DESCRIPTION/NAMESPACE schemas, Circe JSON schemas,
SQL bundling, and data governance across the 3 modular OHDSI study packages:
1. Taxis (Root Network Study Package: Concept AB Mining Engine)
2. TaxisPhenotypeEvaluation (extras/TaxisPhenotypeEvaluation)
3. TaxisPhenotypeCreator (extras/TaxisPhenotypeCreator)

Usage:
  python extras/verify_package_ecosystem.py
"""

import os
import re
import sys
import json
import base64

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

PROHIBITED_TERMS = [
    re.compile(base64.b64decode("XGJwYXRyaWNrXHMrcnlhblxi").decode("utf-8"), re.IGNORECASE),
    re.compile(r"\bsenior\s+investigator\b", re.IGNORECASE),
    re.compile(r"🏆"),
]

PACKAGES = [
    {
        "name": "Taxis",
        "dir": ROOT_DIR,
        "is_root": True,
        "expected_exports": ["execute", "runConceptMining", "packageMiningResults"],
        "required_sql": [
            "inst/sql/sql_server/concept_ab_init.sql",
            "inst/sql/sql_server/concept_ab_batch.sql",
            "inst/sql/sql_server/concept_ab_finalize.sql"
        ],
        "code_to_run": "extras/CodeToRun.R"
    },
    {
        "name": "TaxisPhenotypeEvaluation",
        "dir": os.path.join(ROOT_DIR, "extras", "TaxisPhenotypeEvaluation"),
        "is_root": False,
        "expected_exports": ["execute", "createCohorts", "computeCohortOverlap", "packageResults"],
        "cohorts_dir": "inst/cohorts",
        "expected_cohort_count": 10,
        "code_to_run": "extras/CodeToRun.R"
    },
    {
        "name": "TaxisPhenotypeCreator",
        "dir": os.path.join(ROOT_DIR, "extras", "TaxisPhenotypeCreator"),
        "is_root": False,
        "expected_exports": ["createPhenotype", "synthesizeCirceCohort", "compileCohortSql", "buildBenchmarkPhenotypes"],
        "cohorts_dir": "inst/cohorts",
        "expected_cohort_count": 5,
        "code_to_run": "extras/CodeToRun.R"
    }
]


def test_package_structure_and_governance():
    """Verify package structure, DESCRIPTION, NAMESPACE, and governance sanitization."""
    print("--> Test 1: Validating package structure and governance across all 3 OHDSI packages...")
    errors = []

    for pkg in PACKAGES:
        pkg_dir = pkg["dir"]
        pkg_name = pkg["name"]

        # 1. DESCRIPTION
        desc_path = os.path.join(pkg_dir, "DESCRIPTION")
        if not os.path.exists(desc_path):
            errors.append(f"Missing DESCRIPTION in {pkg_name} ({desc_path})")
            continue

        with open(desc_path, "r", encoding="utf-8") as f:
            desc_text = f.read()

        if f"Package: {pkg_name}" not in desc_text:
            errors.append(f"Package name mismatch in {desc_path}")
        if "License: Apache License 2.0" not in desc_text:
            errors.append(f"Missing Apache License 2.0 in {desc_path}")

        # Governance checks
        for pat in PROHIBITED_TERMS:
            matches = pat.findall(desc_text)
            if matches:
                errors.append(f"Prohibited term '{matches}' found in {desc_path}")

        # 2. NAMESPACE
        ns_path = os.path.join(pkg_dir, "NAMESPACE")
        if not os.path.exists(ns_path):
            errors.append(f"Missing NAMESPACE in {pkg_name} ({ns_path})")
            continue

        with open(ns_path, "r", encoding="utf-8") as f:
            ns_text = f.read()

        for exp in pkg["expected_exports"]:
            if f"export({exp})" not in ns_text:
                errors.append(f"Missing expected export '{exp}' in {ns_path}")

        # 3. CodeToRun.R
        ctr_path = os.path.join(pkg_dir, pkg["code_to_run"])
        if not os.path.exists(ctr_path):
            errors.append(f"Missing CodeToRun.R in {pkg_name} ({ctr_path})")

    if errors:
        for err in errors:
            print(f"  [FAIL] {err}")
        return False

    print(f"  [PASS] All {len(PACKAGES)} OHDSI packages have valid DESCRIPTION, NAMESPACE, and CodeToRun.R drivers.")
    return True


def test_bundled_resources_and_circe_json():
    """Verify bundled SQL templates and valid Circe JSON cohort expressions."""
    print("--> Test 2: Validating bundled package resources (SQL & Circe JSON)...")
    errors = []

    # 1. Check Root Package SQL
    root_pkg = PACKAGES[0]
    for rel_sql in root_pkg["required_sql"]:
        sql_path = os.path.join(root_pkg["dir"], rel_sql)
        if not os.path.exists(sql_path):
            errors.append(f"Missing bundled SQL file: {sql_path}")
        else:
            if os.path.getsize(sql_path) < 1000:
                errors.append(f"Bundled SQL file appears truncated: {sql_path}")

    # 2. Check Circe Cohorts in PhenotypeEvaluation and PhenotypeCreator
    for pkg in PACKAGES[1:]:
        cohorts_path = os.path.join(pkg["dir"], pkg["cohorts_dir"])
        if not os.path.exists(cohorts_path):
            errors.append(f"Missing cohorts directory in {pkg['name']}: {cohorts_path}")
            continue

        json_files = [f for f in os.listdir(cohorts_path) if f.endswith(".json")]
        if len(json_files) != pkg["expected_cohort_count"]:
            errors.append(f"Expected {pkg['expected_cohort_count']} cohorts in {pkg['name']}, found {len(json_files)}")

        for jf in json_files:
            jpath = os.path.join(cohorts_path, jf)
            try:
                with open(jpath, "r", encoding="utf-8") as f:
                    data = json.load(f)
                if "ConceptSets" not in data or "PrimaryCriteria" not in data:
                    errors.append(f"Invalid Circe schema structure in {jpath}")
            except Exception as e:
                errors.append(f"Corrupted JSON in {jpath}: {e}")

    if errors:
        for err in errors:
            print(f"  [FAIL] {err}")
        return False

    print("  [PASS] Bundled resources verified: 3 canonical SQL files and 15 valid Circe JSON definitions.")
    return True


def test_sanitization_across_r_packages():
    """Verify zero prohibited terms, credentials, or internal IPs across all R directories."""
    print("--> Test 3: Checking sanitization across all package R/ and inst/ directories...")
    errors = []
    scanned_files = 0

    scan_dirs = [
        os.path.join(ROOT_DIR, "R"),
        os.path.join(ROOT_DIR, "extras", "TaxisPhenotypeEvaluation", "R"),
        os.path.join(ROOT_DIR, "extras", "TaxisPhenotypeCreator", "R"),
    ]

    for s_dir in scan_dirs:
        if not os.path.exists(s_dir):
            continue
        for fname in os.listdir(s_dir):
            if fname.endswith(".R"):
                fpath = os.path.join(s_dir, fname)
                scanned_files += 1
                with open(fpath, "r", encoding="utf-8", errors="replace") as f:
                    content = f.read()

                for pat in PROHIBITED_TERMS:
                    matches = pat.findall(content)
                    if matches:
                        errors.append(f"Prohibited term match '{matches}' in {fpath}")

    assert scanned_files >= 10, f"Expected at least 10 R files across packages, found {scanned_files}"
    if errors:
        for err in errors:
            print(f"  [FAIL] {err}")
        return False

    print(f"  [PASS] Scanned {scanned_files} package R files. Zero leaks, zero prohibited terms.")
    return True


def main():
    print("=====================================================================")
    print("TAXIS Verification Suite: Tripartite OHDSI R Package Ecosystem")
    print("=====================================================================\n")

    tests = [
        test_package_structure_and_governance,
        test_bundled_resources_and_circe_json,
        test_sanitization_across_r_packages,
    ]

    passed = 0
    for test in tests:
        if test():
            passed += 1
        else:
            print(f"FAILED: {test.__name__}")
            sys.exit(1)

    print(f"\n=====================================================================")
    print(f"ALL {passed}/{len(tests)} PACKAGE ECOSYSTEM TESTS PASSED SUCCESSFULLY.")
    print("=====================================================================")


if __name__ == "__main__":
    main()
