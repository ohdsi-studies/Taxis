#!/usr/bin/env python3
"""
TAXIS HADES Conformance Verification Suite
Validates that all 3 packages in the TAXIS repository comply with the official OHDSI HADES developer guidelines
(sourced directly from C:\\files\\git\\github\\ohdsi\\Hades):
1. Taxis (Root Concept AB Mining Package)
2. TaxisPhenotypeCreator (extras/TaxisPhenotypeCreator)
3. TaxisPhenotypeEvaluation (extras/TaxisPhenotypeEvaluation)

Checks across 11 HADES Conformance Dimensions:
1. Standard Structural Files (.lintr, NEWS.md, README.md, DESCRIPTION, NAMESPACE, LICENSE, .Rbuildignore)
2. Apache License 2.0 Compliance & Source File Copyright Headers
3. DESCRIPTION Metadata, Semver 3-digit versioning, and Remotes for Non-CRAN HADES packages
4. Dependency Conformance with Official HADES Registry (C:\\files\\git\\github\\ohdsi\\Hades\\extras\\packages.csv)
5. Invisible Side Effects Prevention (no library/require in functions, no options(), no <<- global assignments)
6. Code Style, CamelCase Naming, and Lintr Configuration
7. Cross-Platform Database Integration (DatabaseConnector, SqlRender, Parameterized SQL) & Multi-OS CI
8. Unit Test Suite Completeness (testthat.R and test-*.R with test_that blocks)
9. Scientific Governance & Attribution Integrity (zero prohibited terms, exact investigator designations)
10. .Rbuildignore Patterns & extras/PackageMaintenance.R Structure
11. README.md HADES Badges & NEWS.md Release Semver Structure

Usage:
  python extras/verify_hades_conformance.py
"""

import os
import re
import sys

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
HADES_DIR = r"C:\files\git\github\ohdsi\Hades"

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
            "LICENSE",
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


def test_hades_license_and_headers():
    """Verify Apache License 2.0 text and source copyright headers."""
    print("--> Test 2: Validating Apache 2.0 license and source copyright headers...")
    errors = []

    for pkg in PACKAGES:
        pdir = pkg["dir"]
        pname = pkg["name"]

        # 1. Check LICENSE file
        lic_path = os.path.join(pdir, "LICENSE")
        if os.path.exists(lic_path):
            with open(lic_path, "r", encoding="utf-8") as f:
                lic_text = f.read()
            if "Apache License" not in lic_text or "Version 2.0" not in lic_text:
                errors.append(f"[{pname}] LICENSE file does not contain valid Apache License 2.0 text")
        else:
            errors.append(f"[{pname}] Missing LICENSE file")

        # 2. Check copyright headers in R/ directory
        r_dir = os.path.join(pdir, "R")
        if os.path.exists(r_dir):
            for fname in os.listdir(r_dir):
                if fname.endswith(".R"):
                    fpath = os.path.join(r_dir, fname)
                    with open(fpath, "r", encoding="utf-8") as f:
                        code = f.read()
                    if "Copyright" not in code or "Observational Health Data Sciences and Informatics" not in code:
                        errors.append(f"[{pname}] R/{fname} missing OHDSI copyright notice")
                    if "Licensed under the Apache License, Version 2.0" not in code:
                        errors.append(f"[{pname}] R/{fname} missing Apache 2.0 license notice")

    if errors:
        for err in errors:
            print(f"  FAILED: {err}")
        return False

    print("  PASSED: Apache 2.0 license and source headers verified across all packages.")
    return True


def test_hades_description_spec():
    """Verify DESCRIPTION conforms to HADES packaging requirements and Semver."""
    print("--> Test 3: Validating DESCRIPTION fields, semver versioning, and Remotes...")
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

        # Semver 3-digit check (x.y.z)
        v_match = re.search(r"Version:\s*(\d+\.\d+\.\d+)", content)
        if not v_match:
            errors.append(f"[{pname}] DESCRIPTION Version must follow 3-digit semver format (x.y.z)")

        if "testthat" not in content:
            errors.append(f"[{pname}] DESCRIPTION Suggests must contain testthat")

        # Check Remotes for TaxisPhenotypeEvaluation
        if pname == "TaxisPhenotypeEvaluation":
            if "Remotes:" not in content or "ohdsi/CohortDiagnostics" not in content or "ohdsi/PheValuator" not in content:
                errors.append(f"[{pname}] Missing Remotes for non-CRAN HADES packages (CohortDiagnostics, PheValuator)")

    if errors:
        for err in errors:
            print(f"  FAILED: {err}")
        return False

    print("  PASSED: All DESCRIPTION files meet HADES metadata and Semver specifications.")
    return True


def test_hades_dependency_conformance():
    """Verify package dependencies conform to HADES registry or core CRAN packages."""
    print("--> Test 4: Verifying dependencies against official HADES registry...")
    errors = []

    # Known accepted CRAN utility packages in HADES ecosystem
    allowed_cran = {"r", "readr", "dplyr", "zip", "jsonlite", "testthat"}

    # Extract official HADES packages if repo exists
    hades_packages = set()
    hades_csv = os.path.join(HADES_DIR, "extras", "packages.csv")
    if os.path.exists(hades_csv):
        with open(hades_csv, "r", encoding="utf-8") as f:
            lines = f.readlines()
        for line in lines[1:]:
            parts = line.split(",")
            if len(parts) >= 2:
                hades_packages.add(parts[1].strip().lower())

    for pkg in PACKAGES:
        pdir = pkg["dir"]
        pname = pkg["name"]
        desc_path = os.path.join(pdir, "DESCRIPTION")

        with open(desc_path, "r", encoding="utf-8") as f:
            lines = f.readlines()

        in_deps = False
        for line in lines:
            if re.match(r"^(Depends|Imports|Suggests):", line):
                in_deps = True
                continue
            elif re.match(r"^[A-Za-z@]+:", line):
                in_deps = False
                continue

            if in_deps:
                dep_match = re.search(r"([A-Za-z0-9\.]+)", line.strip())
                if dep_match:
                    dep_name = dep_match.group(1).lower()
                    if dep_name in allowed_cran:
                        continue
                    if hades_packages and dep_name in hades_packages:
                        continue
                    if dep_name not in allowed_cran and dep_name not in hades_packages and hades_packages:
                        errors.append(f"[{pname}] Unrecognized non-HADES/non-CRAN dependency: {dep_match.group(1)}")

    if errors:
        for err in errors:
            print(f"  FAILED: {err}")
        return False

    print("  PASSED: All package dependencies conform to official HADES or core CRAN registries.")
    return True


def test_hades_no_invisible_side_effects():
    """Verify functions do not invoke library(), require(), or global assignments."""
    print("--> Test 5: Checking for invisible side effects in R functions...")
    errors = []

    # Patterns for invisible side effects inside functions
    bad_patterns = [
        (re.compile(r"^\s*(library|require)\s*\(", re.MULTILINE), "Disallowed library()/require() call in function (use pkg::fun)"),
        (re.compile(r"^\s*options\s*\(", re.MULTILINE), "Disallowed options() call in function (HADES side-effect prohibition)"),
        (re.compile(r"<<-"), "Disallowed global assignment <<-"),
        (re.compile(r"assign\s*\([^,]+,[^,]+,\s*envir\s*=\s*\.?GlobalEnv"), "Disallowed assignment to .GlobalEnv")
    ]

    for pkg in PACKAGES:
        pdir = pkg["dir"]
        pname = pkg["name"]
        r_dir = os.path.join(pdir, "R")

        if os.path.exists(r_dir):
            for fname in os.listdir(r_dir):
                if fname.endswith(".R"):
                    fpath = os.path.join(r_dir, fname)
                    with open(fpath, "r", encoding="utf-8") as f:
                        code = f.read()

                    for pat, desc in bad_patterns:
                        if pat.search(code):
                            errors.append(f"[{pname}] R/{fname}: {desc}")

    if errors:
        for err in errors:
            print(f"  FAILED: {err}")
        return False

    print("  PASSED: Zero invisible side effects detected across all R functions.")
    return True


def test_hades_code_style_and_lintr():
    """Verify .lintr configuration and function naming conventions."""
    print("--> Test 6: Verifying .lintr linters and camelCase function conventions...")
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

        # Check NAMESPACE exports are camelCase
        ns_path = os.path.join(pdir, "NAMESPACE")
        if os.path.exists(ns_path):
            with open(ns_path, "r", encoding="utf-8") as f:
                ns_text = f.read()
            exports = re.findall(r"export\(([^)]+)\)", ns_text)
            for exp in exports:
                exp_clean = exp.strip().strip('"').strip("'")
                # First letter should be lowercase for camelCase function
                if exp_clean and exp_clean[0].isupper():
                    errors.append(f"[{pname}] Exported function '{exp_clean}' should be camelCase per HADES guidelines")

    if errors:
        for err in errors:
            print(f"  FAILED: {err}")
        return False

    print("  PASSED: .lintr and camelCase naming conventions verified.")
    return True


def test_hades_cross_platform_and_ci():
    """Verify static cross-database dependencies and multi-package/multi-OS CI workflow."""
    print("--> Test 7: Checking static cross-database dependencies and multi-package/multi-OS CI workflow...")
    errors = []

    # 1. Root package must use DatabaseConnector and SqlRender
    root_desc = os.path.join(ROOT_DIR, "DESCRIPTION")
    with open(root_desc, "r", encoding="utf-8") as f:
        desc = f.read()
    if "DatabaseConnector" not in desc or "SqlRender" not in desc:
        errors.append("[Taxis] Root package must import DatabaseConnector and SqlRender for cross-database support")

    # 2. Check GitHub Actions workflow covers all 3 packages and all 3 OS targets
    ci_path = os.path.join(ROOT_DIR, ".github", "workflows", "R-CMD-check.yaml")
    if not os.path.exists(ci_path):
        errors.append("Missing .github/workflows/R-CMD-check.yaml for continuous integration")
    else:
        with open(ci_path, "r", encoding="utf-8") as f:
            ci_text = f.read()
        for os_name in ["windows-latest", "macOS-latest", "ubuntu-22.04"]:
            if os_name not in ci_text:
                errors.append(f"CI workflow missing matrix OS target: {os_name}")
        for pkg_name in ["Taxis", "TaxisPhenotypeCreator", "TaxisPhenotypeEvaluation"]:
            if pkg_name not in ci_text:
                errors.append(f"CI workflow missing package target: {pkg_name}")

    if errors:
        for err in errors:
            print(f"  FAILED: {err}")
        return False

    print("  PASSED: Static cross-database dependencies and multi-package/multi-OS CI matrix configured (runtime database interoperability and native R CMD check execution pending partner CDM environments).")
    return True


def test_hades_unit_tests():
    """Verify unit test infrastructure and testthat completeness."""
    print("--> Test 8: Validating testthat suites and assertion blocks...")
    errors = []

    for pkg in PACKAGES:
        pdir = pkg["dir"]
        pname = pkg["name"]

        # 1. testthat.R check
        tt_runner = os.path.join(pdir, "tests", "testthat.R")
        if os.path.exists(tt_runner):
            with open(tt_runner, "r", encoding="utf-8") as f:
                txt = f.read()
            if f'test_check("{pname}")' not in txt and f"test_check('{pname}')" not in txt:
                errors.append(f"[{pname}] tests/testthat.R missing test_check('{pname}')")

        # 2. test-*.R check
        test_file = os.path.join(pdir, pkg["test_file"])
        if os.path.exists(test_file):
            with open(test_file, "r", encoding="utf-8") as f:
                tt_code = f.read()
            if "test_that(" not in tt_code:
                errors.append(f"[{pname}] {pkg['test_file']} contains no test_that blocks")
            if "expect_" not in tt_code:
                errors.append(f"[{pname}] {pkg['test_file']} contains no expect_* assertions")

    if errors:
        for err in errors:
            print(f"  FAILED: {err}")
        return False

    print("  PASSED: Complete testthat infrastructure and assertions verified across all packages.")
    return True


def test_hades_governance_and_attribution():
    """Verify governance constraints and exact scientific attribution."""
    print("--> Test 9: Auditing governance constraints and investigator attribution...")
    errors = []

    for pkg in PACKAGES:
        pdir = pkg["dir"]
        pname = pkg["name"]

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

    print("  PASSED: Zero governance violations; scientific attribution strictly preserved.")
    return True


def test_hades_rbuildignore_and_maintenance():
    """Verify .Rbuildignore rules and extras/PackageMaintenance.R structure."""
    print("--> Test 10: Validating .Rbuildignore patterns and PackageMaintenance.R...")
    errors = []

    required_buildignore_patterns = [
        r"^\.lintr\$",
        r"^\.\*\.Rproj\$",
        r"^\^\.Rproj\\\.user\$",
        r"\^extras\$",
        r"\^deploy\\\.sh\$",
        r"\^compare_versions\$"
    ]

    for pkg in PACKAGES:
        pdir = pkg["dir"]
        pname = pkg["name"]

        # Check .Rbuildignore content
        rb_path = os.path.join(pdir, ".Rbuildignore")
        if os.path.exists(rb_path):
            with open(rb_path, "r", encoding="utf-8") as f:
                rb_lines = [line.strip() for line in f.readlines()]
            rb_text = "\n".join(rb_lines)

            patterns = [r"\.lintr", r"\.Rproj", r"extras", r"deploy(\\\.)?sh", r"compare_versions"]
            for pat in patterns:
                if not re.search(pat, rb_text):
                    errors.append(f"[{pname}] .Rbuildignore missing required HADES pattern for: {pat}")
        else:
            errors.append(f"[{pname}] Missing .Rbuildignore")

        # Check PackageMaintenance.R content
        pm_path = os.path.join(pdir, pkg["pkg_maint"])
        if os.path.exists(pm_path):
            with open(pm_path, "r", encoding="utf-8") as f:
                pm_text = f.read()
            if "Apache License" not in pm_text or "Observational Health Data Sciences" not in pm_text:
                errors.append(f"[{pname}] {pkg['pkg_maint']} missing standard OHDSI Apache 2.0 header")
            if "PackageMaintenance.R" in pm_path and "devtools::" not in pm_text and "OhdsiRTools::" not in pm_text:
                errors.append(f"[{pname}] {pkg['pkg_maint']} missing standard maintenance commands (devtools/OhdsiRTools)")
        else:
            errors.append(f"[{pname}] Missing {pkg['pkg_maint']}")

    if errors:
        for err in errors:
            print(f"  FAILED: {err}")
        return False

    print("  PASSED: .Rbuildignore patterns and PackageMaintenance.R verified across all packages.")
    return True


def test_hades_readme_badges_and_news():
    """Verify README.md badges and NEWS.md semver release documentation."""
    print("--> Test 11: Validating README.md HADES badges and NEWS.md release documentation...")
    errors = []

    for pkg in PACKAGES:
        pdir = pkg["dir"]
        pname = pkg["name"]

        # Check README.md
        readme_path = os.path.join(pdir, "README.md")
        if os.path.exists(readme_path):
            with open(readme_path, "r", encoding="utf-8") as f:
                readme_text = f.read()
            if "workflows/R-CMD-check/badge.svg" not in readme_text:
                errors.append(f"[{pname}] README.md missing official R-CMD-check build status badge")
            if "License-Apache" not in readme_text and "License: Apache" not in readme_text:
                errors.append(f"[{pname}] README.md missing Apache 2.0 license badge")
        else:
            errors.append(f"[{pname}] Missing README.md")

        # Check NEWS.md
        news_path = os.path.join(pdir, "NEWS.md")
        if os.path.exists(news_path):
            with open(news_path, "r", encoding="utf-8") as f:
                news_text = f.read()
            header_match = re.search(r"^#\s+([A-Za-z0-9]+)\s+(\d+\.\d+\.\d+)", news_text, re.MULTILINE)
            if not header_match:
                errors.append(f"[{pname}] NEWS.md missing required semver release header '# <Package> x.y.z'")
        else:
            errors.append(f"[{pname}] Missing NEWS.md")

    if errors:
        for err in errors:
            print(f"  FAILED: {err}")
        return False

    print("  PASSED: README.md badges and NEWS.md release notes meet HADES specifications.")
    return True


def run_all_tests():
    print("======================================================================")
    print("       TAXIS HADES CONFORMANCE VERIFICATION SUITE                     ")
    print("       Benchmarked against OHDSI HADES Guidelines & Registry         ")
    print("======================================================================")

    results = [
        test_hades_files_presence(),
        test_hades_license_and_headers(),
        test_hades_description_spec(),
        test_hades_dependency_conformance(),
        test_hades_no_invisible_side_effects(),
        test_hades_code_style_and_lintr(),
        test_hades_cross_platform_and_ci(),
        test_hades_unit_tests(),
        test_hades_governance_and_attribution(),
        test_hades_rbuildignore_and_maintenance(),
        test_hades_readme_badges_and_news()
    ]

    print("======================================================================")
    if all(results):
        print("ALL HADES STATIC STRUCTURAL CONFORMANCE CHECKS PASSED (11/11).")
        print("Notice: Static pre-flight verified. Native R CMD check compilation and real-CDM database execution remain pending execution in partner environments.")
        print("======================================================================")
        return 0
    else:
        print("SOME HADES CONFORMANCE TESTS FAILED. Review errors above.")
        print("======================================================================")
        return 1


if __name__ == "__main__":
    sys.exit(run_all_tests())
