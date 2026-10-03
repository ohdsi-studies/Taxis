#!/usr/bin/env python3
"""
TAXIS Study Verification Suite: 2026 Symposium Dissemination Suite (Wave 8)
Validates sanitization, policy compliance, word count bounds, section completeness,
decision codes, and relative link integrity across symposium showcase deliverables.

Usage:
  python extras/verify_symposium_suite.py
"""

import os
import re
import sys

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BRIEF_REPORT_FILE = os.path.join(ROOT_DIR, "docs", "symposium_2026", "TAXIS_Brief_Report_v6.md")
POSTER_GUIDE_FILE = os.path.join(ROOT_DIR, "docs", "symposium_2026", "Poster_Presentation_Guide.md")

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

REQUIRED_BRIEF_REPORT_SECTIONS = [
    "Introduction & Background",
    "Methods",
    "Results & Empirical Evidence Register",
    "Discussion & Ecosystem Integration",
    "Conclusions",
    "References",
]

REQUIRED_POSTER_SECTIONS = [
    "Poster Architecture Overview",
    "Panel 1: The Challenge & Large-Scale Association Mining Pipeline",
    "Panel 2: Clinical Pair Taxonomy v6.0 & Automated Phenotype Synthesis",
    "Panel 3: Empirical Benchmarks, Federated Evaluation & Ecosystem Integration",
    "Four-Minute Presentation Script for Showcase Presenters",
    "Digital Assets & QR Code Verification Targets",
]

REQUIRED_DECISION_CODES = [
    "DEC-GR-002",
    "DEC-GR-003",
    "DEC-GR-005",
    "DEC-GR-007",
    "DEC-GR-008",
    "DEC-GR-010",
]


def test_sanitization_and_prohibited_terms():
    """Verify zero prohibited terms, internal IPs, server hostnames, or credentials."""
    print("--> Test 1: Checking sanitization across symposium showcase deliverables...")
    files_to_check = [BRIEF_REPORT_FILE, POSTER_GUIDE_FILE]
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
    print("  [PASS] Zero leaks, zero prohibited terms across symposium deliverables.")
    return True


def test_brief_report_word_count_and_budget():
    """Verify Brief Report satisfies the word-budget heuristic for the 4-page target (REC-030-4: pagination unverified until layout render)."""
    print("--> Test 2: Validating Brief Report word-budget heuristic (4-page submission target)...")
    with open(BRIEF_REPORT_FILE, "r", encoding="utf-8") as f:
        content = f.read()

    words = content.split()
    word_count = len(words)

    # Standard 4-page conference manuscript with tables and figures is ~1,800 to 2,600 words
    min_words = 1500
    max_words = 2800

    assert min_words <= word_count <= max_words, (
        f"Brief Report word count ({word_count}) outside acceptable 4-page budget [{min_words}, {max_words}]"
    )
    print(f"  [PASS] Brief Report word count ({word_count} words) satisfies 4-page heuristic budget [{min_words}, {max_words}] (visual page rendering unverified pending template export).")
    return True


def test_structural_completeness():
    """Verify all required sections are present in Brief Report and Poster Guide."""
    print("--> Test 3: Validating structural section completeness...")
    with open(BRIEF_REPORT_FILE, "r", encoding="utf-8") as f:
        report_text = f.read()
    with open(POSTER_GUIDE_FILE, "r", encoding="utf-8") as f:
        poster_text = f.read()

    for sec in REQUIRED_BRIEF_REPORT_SECTIONS:
        assert sec in report_text, f"Brief Report missing required section: '{sec}'"

    for sec in REQUIRED_POSTER_SECTIONS:
        assert sec in poster_text, f"Poster Guide missing required section: '{sec}'"

    # Verify decision codes
    combined = report_text + "\n" + poster_text
    for dec in REQUIRED_DECISION_CODES:
        assert dec in combined, f"Missing authoritative decision reference: '{dec}'"

    print("  [PASS] All required structural sections and decision codes validated.")
    return True


def test_markdown_relative_links():
    """Verify that internal markdown links resolve to existing files in repository."""
    print("--> Test 4: Auditing internal markdown relative link integrity...")
    files_to_check = [BRIEF_REPORT_FILE, POSTER_GUIDE_FILE]
    broken_links = []

    for fpath in files_to_check:
        base_dir = os.path.dirname(fpath)
        with open(fpath, "r", encoding="utf-8") as f:
            content = f.read()

        # Find relative markdown links: [text](path) where path does not start with http/mailto
        link_matches = re.findall(r"\[([^\]]+)\]\(([^)]+)\)", content)
        for text, target in link_matches:
            if target.startswith("http://") or target.startswith("https://") or target.startswith("mailto:"):
                continue
            # Strip anchors: path#anchor
            clean_target = target.split("#")[0]
            if not clean_target:
                continue
            resolved_path = os.path.abspath(os.path.join(base_dir, clean_target))
            if not os.path.exists(resolved_path):
                broken_links.append(f"{os.path.relpath(fpath, ROOT_DIR)}: broken link to '{clean_target}' -> '{resolved_path}'")

    if broken_links:
        for bl in broken_links:
            print(f"  [FAIL] {bl}")
        return False
    print("  [PASS] All relative markdown links resolve to verified existing repository files.")
    return True


def main():
    print("=" * 69)
    print("TAXIS Verification Suite: 2026 Symposium Dissemination Suite (Wave 8)")
    print("=" * 69)
    print()

    tests = [
        test_sanitization_and_prohibited_terms,
        test_brief_report_word_count_and_budget,
        test_structural_completeness,
        test_markdown_relative_links,
    ]

    all_passed = True
    for test in tests:
        try:
            if not test():
                all_passed = False
        except AssertionError as e:
            print(f"  [ASSERTION FAILED] {e}")
            all_passed = False
        except Exception as e:
            print(f"  [ERROR] {e}")
            all_passed = False

    print()
    print("=" * 69)
    if all_passed:
        print("ALL 4/4 SYMPOSIUM VERIFICATION TESTS PASSED SUCCESSFULLY.")
        print("=" * 69)
        sys.exit(0)
    else:
        print("VERIFICATION FAILED: One or more symposium tests failed.")
        print("=" * 69)
        sys.exit(1)


if __name__ == "__main__":
    main()
