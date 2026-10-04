#!/usr/bin/env python3
"""
TAXIS HADES Conformance Verification Suite
Validates that all 3 packages in the TAXIS repository comply with the OHDSI HADES developer guidelines:
1. Taxis (Root Concept AB Mining Package)
2. TaxisPhenotypeCreator (extras/TaxisPhenotypeCreator)
3. TaxisPhenotypeEvaluation (extras/TaxisPhenotypeEvaluation)

Checks:
- Complete file structure (.lintr, NEWS.md, README.md, DESCRIPTION, NAMESPACE, .Rbuildignore)
- Standard extras/PackageMaintenance.R present
- Standard tests/testthat.R and tests/testthat/test-*.R test suites present
- DESCRIPTION contains required fields (Depends, Imports, Suggests: testthat, License, URL, BugReports)
- Zero governance violations (no Patrick Ryan mentions, no senior investigator, no trophies)

Usage:
  python extras/verify_hades_conformance.py
"""

import os
import re
import sys

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

PACKAGES = [
    {
        "name": "Taxis",
        "dir": ROOT_DIR,
        "is_root": True,
        "test_file": "tests/testthat/test-Taxis.R",
        "pkg_maint": "extras/PackageMaintenance.R"
    },
    {
        "name": "TaxisPhenotypeCreator",
        "dir": os.path.join(ROOT_DIR, "extras", "TaxisPhenotypeCreator"),
        "is_root": False,
        "test_file": "tests/testthat/test-TaxisPhenotypeCreator.R",
        "pkg_maint": "extras/PackageMaintenance.R"
    },
    {
        "name": "TaxisPhenotypeEvaluation",
        "dir": os.path.join(ROOT_DIR, "extras", "TaxisPhenotypeEvaluation"),
        "is_root": False,
        "test_file": "tests/testthat/test-TaxisPhenotypeEvaluation.R",
        "pkg_maint": "extras/PackageMaintenance.R"
    }
]

PROHIBITED_TERMS = [
    re.compile(r"\bpatrick\s+ryan\b", re.IGNORECASE),
    re.compile(r"\bsenior\s+investigator\b", re.IGNORECASE),
    re.compile(r"🏆"),
]

REQUIRED_DESC_FIELDS = [
    "Package:",
    "Title:",
    "Version:",
    "Authors@R:",
    "Description:",
    "Depends:",
    "Imports:",
    "Suggests:",
    "License: Apache License 2.0",
    "Encoding: UTF-8",
    "URL:",
    "BugReports:"
]


def test_hades_files_presence():
    """Verify presence of all standard HADES structural files."""
    print("--> Test 1: Checking presence of standard HADES structural files...")
    errors = []

    for pkg in PACKAGES:
        pdir = pkg["dir"]
        pname = pkg["name"]

        required_files = [
            "DESCRIPTION",
            "NAMESPACE",
            "README.md",
            "NEWS.md",
            ".lintr",
            ".Rbuildignore",
            pkg["pkg_maint"],
            "tests/testthat.R",
            pkg["test_file"]
        ]

        for rf in required_files:
            full_path = os.path.join(pdir, rf)
            if not os.path.exists(full_path):
                errors.append(f"[{pname}] Missing HADES required file: {rf}")

    if errors:
        for err in errors:
            print(f"  FAILED: {err}")
        return False

    print("  PASSED: All 3 packages contain complete HADES structural files.")
    return True


def test_hades_description_spec():
    """Verify DESCRIPTION conforms to HADES packaging requirements."""
    print("--> Test 2: Validating DESCRIPTION fields and dependencies...")
    errors = []

    for pkg in PACKAGES:
        pdir = pkg["dir"]
        pname = pkg["name"]
        desc_path = os.path.join(pdir, "DESCRIPTION")

        with open(desc_path, "r", encoding="utf-8") as f:
            content = f.read()

        for field in REQUIRED_DESC_FIELDS:
            if field not in content:
                errors.append(f"[{pname}] DESCRIPTION missing required HADES field: '{field}'")

        if "testthat" not in content:
            errors.append(f"[{pname}] DESCRIPTION Suggests must contain testthat")

    if errors:
        for err in errors:
            print(f"  FAILED: {err}")
        return False

    print("  PASSED: All DESCRIPTION files meet HADES metadata specifications.")
    return True


def test_hades_governance_and_lintr():
    """Verify .lintr configuration and governance constraints across all packages."""
    print("--> Test 3: Verifying .lintr linters and governance terms...")
    errors = []

    for pkg in PACKAGES:
        pdir = pkg["dir"]
        pname = pkg["name"]

        # Check .lintr
        lintr_path = os.path.join(pdir, ".lintr")
        with open(lintr_path, "r", encoding="utf-8") as f:
            lintr_content = f.read()

        if "linters_with_defaults" not in lintr_content:
            errors.append(f"[{pname}] .lintr missing linters_with_defaults configuration")

        # Check governance in NEWS.md, DESCRIPTION, README.md, PackageMaintenance.R
        for fname in ["DESCRIPTION", "NEWS.md", "README.md", pkg["pkg_maint"]]:
            fpath = os.path.join(pdir, fname)
            if os.path.exists(fpath):
                with open(fpath, "r", encoding="utf-8") as f:
                    txt = f.read()
                for pat in PROHIBITED_TERMS:
                    m = pat.findall(txt)
                    if m:
                        errors.append(f"[{pname}] Prohibited governance term '{m}' in {fname}")

    if errors:
        for err in errors:
            print(f"  FAILED: {err}")
        return False

    print("  PASSED: .lintr and governance verification succeeded across all packages.")
    return True


def run_all_tests():
    print("======================================================================")
    print("       TAXIS HADES CONFORMANCE VERIFICATION SUITE                     ")
    print("======================================================================")

    results = [
        test_hades_files_presence(),
        test_hades_description_spec(),
        test_hades_governance_and_lintr()
    ]

    print("======================================================================")
    if all(results):
        print("ALL HADES CONFORMANCE TESTS PASSED (3/3). Conformance: 100%.")
        print("======================================================================")
        return 0
    else:
        print("SOME HADES CONFORMANCE TESTS FAILED. Review errors above.")
        print("======================================================================")
        return 1


if __name__ == "__main__":
    sys.exit(run_all_tests())
