#!/usr/bin/env python3
"""
extras/test_synthetic_pair_federated_synthesis.py

Feasibility Gate Benchmark: Single-Pair Multi-Site Synthetic Meta-Analysis
Fulfills REC-072-1 and DEC-GR-027/DEC-GR-032 governance requirements.

This script demonstrates a minimal, standalone, reproducible engineering
proof-of-concept for synthesizing one ordered concept pair (A, B) across
heterogeneous synthetic site records using DerSimonian-Laird random-effects
meta-analysis and aggregate directionality pooling.

Key Capabilities Tested:
  1. Input Schema Validation: Rejects malformed or incomplete site records.
  2. Site-Level Estimation: Expected count, lift, log-lift, and delta-method variance.
  3. DerSimonian-Laird Random-Effects Pooling: Q, tau^2, I^2, pooled lift, 95% CI.
  4. Directionality Pooling: Aggregates directional counts with continuity correction.
  5. Privacy-Preserving Small-Cell Handling: Safely quarantees masked records (<5 -> -1).
  6. Reference Result Verification: Compares directly against hand-computed values.

Scope Note:
  This benchmark establishes computational correctness and data transport
  feasibility for proposed federated synthesis. It does NOT assert clinical
  validity across live network databases.
"""

import math
import sys
from typing import Dict, List, Optional, Tuple, Any


class SitePairRecord:
    """Standardized schema for site-level aggregate pair records."""

    def __init__(
        self,
        site_id: str,
        concept_id_a: int,
        concept_id_b: int,
        pair_type: str,
        obs_after: int,
        obs_before: int,
        obs_same_day: int,
        obs_a: int,
        obs_b: int,
        observation_person_days: float,
    ):
        self.site_id = site_id
        self.concept_id_a = concept_id_a
        self.concept_id_b = concept_id_b
        self.pair_type = pair_type
        self.obs_after = obs_after
        self.obs_before = obs_before
        self.obs_same_day = obs_same_day
        self.obs_a = obs_a
        self.obs_b = obs_b
        self.observation_person_days = float(observation_person_days)

        self._validate()

    def _validate(self):
        """Validate input values against schema rules."""
        if not self.site_id or not isinstance(self.site_id, str):
            raise ValueError("site_id must be a non-empty string")
        if self.observation_person_days <= 0:
            raise ValueError("observation_person_days must be positive")
        if self.obs_a < -1 or self.obs_b < -1:
            raise ValueError("Marginal counts cannot be less than -1")
        if any(c < -1 for c in (self.obs_after, self.obs_before, self.obs_same_day)):
            raise ValueError("Observed counts cannot be less than -1")

    @property
    def is_suppressed(self) -> bool:
        """Return True if any count is masked under small-cell suppression (<5 -> -1)."""
        counts = [self.obs_after, self.obs_before, self.obs_same_day, self.obs_a, self.obs_b]
        return any(c == -1 for c in counts)

    def compute_site_estimates(self) -> Optional[Dict[str, float]]:
        """
        Compute site-level lift, log-lift, and delta-method variance.
        Returns None if record is suppressed or has zero observed co-occurrences.
        """
        if self.is_suppressed:
            return None

        if self.obs_after <= 0 or self.obs_a <= 0 or self.obs_b <= 0:
            return None

        expected_after = (self.obs_a * self.obs_b) / self.observation_person_days
        if expected_after <= 0:
            return None

        lift_after = self.obs_after / expected_after
        log_lift = math.log(lift_after)

        # Delta-method variance for log-lift: Var(ln(Lift)) = 1/O_AB + 1/O_A + 1/O_B
        variance = (1.0 / self.obs_after) + (1.0 / self.obs_a) + (1.0 / self.obs_b)

        return {
            "expected_after": expected_after,
            "lift_after": lift_after,
            "log_lift": log_lift,
            "variance": variance,
        }


def synthesize_random_effects_lift(
    site_estimates: List[Dict[str, float]],
) -> Dict[str, float]:
    """
    Synthesize site-level log-lift estimates via DerSimonian-Laird random effects.
    """
    k = len(site_estimates)
    if k == 0:
        raise ValueError("Cannot synthesize empty list of site estimates")

    if k == 1:
        # Single site fallback
        est = site_estimates[0]
        y = est["log_lift"]
        se = math.sqrt(est["variance"])
        return {
            "k_sites": 1,
            "pooled_log_lift": y,
            "se_pooled": se,
            "pooled_lift": math.exp(y),
            "ci_lower": math.exp(y - 1.96 * se),
            "ci_upper": math.exp(y + 1.96 * se),
            "cochrans_q": 0.0,
            "tau_squared": 0.0,
            "i_squared": 0.0,
        }

    # 1. Fixed-effects inverse-variance weighting
    weights = [1.0 / est["variance"] for est in site_estimates]
    sum_w = sum(weights)
    sum_w_y = sum(w * est["log_lift"] for w, est in zip(weights, site_estimates))
    y_fe = sum_w_y / sum_w

    # 2. Cochran's Q test for heterogeneity
    cochrans_q = sum(
        w * ((est["log_lift"] - y_fe) ** 2) for w, est in zip(weights, site_estimates)
    )
    df = k - 1

    # 3. DerSimonian-Laird between-site variance (tau^2)
    sum_w_squared = sum(w**2 for w in weights)
    denom_c = sum_w - (sum_w_squared / sum_w)
    tau_squared = max(0.0, (cochrans_q - df) / denom_c)

    # 4. Higgins & Thompson I^2 heterogeneity metric
    if cochrans_q > 0:
        i_squared = max(0.0, (cochrans_q - df) / cochrans_q) * 100.0
    else:
        i_squared = 0.0

    # 5. Random-effects weights and pooled estimate
    re_weights = [1.0 / (est["variance"] + tau_squared) for est in site_estimates]
    sum_re_w = sum(re_weights)
    pooled_log_lift = sum(
        w_star * est["log_lift"] for w_star, est in zip(re_weights, site_estimates)
    ) / sum_re_w
    se_pooled = math.sqrt(1.0 / sum_re_w)

    pooled_lift = math.exp(pooled_log_lift)
    ci_lower = math.exp(pooled_log_lift - 1.96 * se_pooled)
    ci_upper = math.exp(pooled_log_lift + 1.96 * se_pooled)

    return {
        "k_sites": k,
        "pooled_log_lift": pooled_log_lift,
        "se_pooled": se_pooled,
        "pooled_lift": pooled_lift,
        "ci_lower": ci_lower,
        "ci_upper": ci_upper,
        "cochrans_q": cochrans_q,
        "tau_squared": tau_squared,
        "i_squared": i_squared,
    }


def synthesize_directionality(records: List[SitePairRecord]) -> Dict[str, Any]:
    """
    Synthesize directional counts across participating sites with continuity correction.
    Masked records (<5) are omitted from count summation.
    """
    total_after = 0
    total_before = 0
    total_same_day = 0
    contributing_sites = 0

    for rec in records:
        if rec.is_suppressed:
            continue
        total_after += rec.obs_after
        total_before += rec.obs_before
        total_same_day += rec.obs_same_day
        contributing_sites += 1

    if contributing_sites == 0:
        return {
            "contributing_sites": 0,
            "total_after": 0,
            "total_before": 0,
            "total_same_day": 0,
            "dr_pooled": None,
            "category": "All Sites Suppressed (<5)",
        }

    dr_pooled = (total_after + 0.5) / (total_before + 0.5)

    if dr_pooled >= 1.50:
        category = "Empirically Preceding"
    elif dr_pooled <= 0.67:
        category = "Empirically Subsequent"
    else:
        category = "Empirically Concurrent / Balanced"

    return {
        "contributing_sites": contributing_sites,
        "total_after": total_after,
        "total_before": total_before,
        "total_same_day": total_same_day,
        "dr_pooled": dr_pooled,
        "category": category,
    }


def run_benchmark():
    print("================================================================================")
    print("FEASIBILITY GATE: Single-Pair Multi-Site Synthetic Meta-Analysis Benchmark")
    print("Governance: DEC-GR-027, DEC-GR-032 | Supervisory Review: REV-072 / REC-072-1")
    print("================================================================================\n")

    # 1. Define synthetic sites
    # Concept Pair: 255573 (COPD) -> 40241331 (Inhaled Long-Acting Beta-Agonist)
    concept_a = 255573
    concept_b = 40241331
    pair_type = "condition | drug"

    # Site 1: INPC-like EHR fixture
    site_1 = SitePairRecord(
        site_id="EHR_INPC_SYNTHETIC",
        concept_id_a=concept_a,
        concept_id_b=concept_b,
        pair_type=pair_type,
        obs_after=120,
        obs_before=40,
        obs_same_day=15,
        obs_a=1500,
        obs_b=2200,
        observation_person_days=58197414.0,
    )

    # Site 2: Commercial Claims-like fixture
    site_2 = SitePairRecord(
        site_id="CLAIMS_MARKETSCAN_SYNTHETIC",
        concept_id_a=concept_a,
        concept_id_b=concept_b,
        pair_type=pair_type,
        obs_after=350,
        obs_before=110,
        obs_same_day=50,
        obs_a=4000,
        obs_b=6500,
        observation_person_days=180000000.0,
    )

    # Site 3: Small-cell suppressed fixture (<5 count -> -1)
    site_3 = SitePairRecord(
        site_id="SMALL_PEDIATRIC_CLINIC_SYNTHETIC",
        concept_id_a=concept_a,
        concept_id_b=concept_b,
        pair_type=pair_type,
        obs_after=-1,
        obs_before=-1,
        obs_same_day=-1,
        obs_a=12,
        obs_b=8,
        observation_person_days=500000.0,
    )

    print("--- Test 1: Schema Validation & Masking Detection ---")
    assert not site_1.is_suppressed, "Site 1 should not be suppressed"
    assert not site_2.is_suppressed, "Site 2 should not be suppressed"
    assert site_3.is_suppressed, "Site 3 must be detected as suppressed"
    print("  [PASS] Masking detection verified: Site 3 correctly quarantined.\n")

    print("--- Test 2: Invalid Schema Rejection ---")
    try:
        SitePairRecord(
            site_id="",  # Invalid empty site ID
            concept_id_a=1,
            concept_id_b=2,
            pair_type="test",
            obs_after=10,
            obs_before=10,
            obs_same_day=0,
            obs_a=100,
            obs_b=100,
            observation_person_days=1000.0,
        )
        assert False, "Should have raised ValueError for empty site_id"
    except ValueError as e:
        print(f"  [PASS] Empty site_id rejected: {e}")

    try:
        SitePairRecord(
            site_id="TEST",
            concept_id_a=1,
            concept_id_b=2,
            pair_type="test",
            obs_after=-5,  # Invalid negative count below -1
            obs_before=10,
            obs_same_day=0,
            obs_a=100,
            obs_b=100,
            observation_person_days=1000.0,
        )
        assert False, "Should have raised ValueError for count < -1"
    except ValueError as e:
        print(f"  [PASS] Negative count < -1 rejected: {e}\n")

    print("--- Test 3: Site-Level Estimation & Variance Derivation ---")
    est_1 = site_1.compute_site_estimates()
    est_2 = site_2.compute_site_estimates()
    est_3 = site_3.compute_site_estimates()

    assert est_1 is not None
    assert est_2 is not None
    assert est_3 is None, "Suppressed site must return None for site estimates"

    print(
        f"  Site 1 ({site_1.site_id}): Expected={est_1['expected_after']:.4f}, "
        f"Lift={est_1['lift_after']:.2f}, ln(Lift)={est_1['log_lift']:.4f}, Var={est_1['variance']:.6f}"
    )
    print(
        f"  Site 2 ({site_2.site_id}): Expected={est_2['expected_after']:.4f}, "
        f"Lift={est_2['lift_after']:.2f}, ln(Lift)={est_2['log_lift']:.4f}, Var={est_2['variance']:.6f}"
    )
    print("  Site 3: Correctly returned None (quarantined from pooling)\n")

    # Assert exact agreement with hand calculations
    assert math.isclose(est_1["expected_after"], 0.056704, abs_tol=1e-5)
    assert math.isclose(est_1["lift_after"], 2116.269600, abs_tol=1e-3)
    assert math.isclose(est_1["log_lift"], 7.657410, abs_tol=1e-5)
    assert math.isclose(est_1["variance"], 0.009455, abs_tol=1e-5)

    assert math.isclose(est_2["expected_after"], 0.144444, abs_tol=1e-5)
    assert math.isclose(est_2["lift_after"], 2423.076923, abs_tol=1e-3)
    assert math.isclose(est_2["log_lift"], 7.792793, abs_tol=1e-5)
    assert math.isclose(est_2["variance"], 0.003261, abs_tol=1e-5)
    print("  [PASS] Site-level estimates match independent reference calculation.\n")

    print("--- Test 4: DerSimonian-Laird Random-Effects Pooling ---")
    valid_estimates = [est_1, est_2]
    meta_results = synthesize_random_effects_lift(valid_estimates)

    print(f"  Pooled log-lift: {meta_results['pooled_log_lift']:.6f}")
    print(f"  Standard Error:  {meta_results['se_pooled']:.6f}")
    print(
        f"  Pooled Lift:     {meta_results['pooled_lift']:.2f} "
        f"[95% CI: {meta_results['ci_lower']:.2f} - {meta_results['ci_upper']:.2f}]"
    )
    print(f"  Cochran's Q:     {meta_results['cochrans_q']:.6f} (df=1)")
    print(f"  Tau^2:           {meta_results['tau_squared']:.6f}")
    print(f"  I^2:             {meta_results['i_squared']:.2f}%")

    # Reference values:
    # Q = 1.441436, tau2 = 0.002807, I2 = 30.62%
    # Pooled log-lift = 7.747976, SE = 0.063710
    # Pooled Lift = 2316.88 [95% CI: 2044.90 - 2625.03]
    assert math.isclose(meta_results["cochrans_q"], 1.441436, abs_tol=1e-4)
    assert math.isclose(meta_results["tau_squared"], 0.002807, abs_tol=1e-5)
    assert math.isclose(meta_results["i_squared"], 30.62, abs_tol=0.1)
    assert math.isclose(meta_results["pooled_log_lift"], 7.747976, abs_tol=1e-4)
    assert math.isclose(meta_results["se_pooled"], 0.063710, abs_tol=1e-4)
    assert math.isclose(meta_results["pooled_lift"], 2316.878277, abs_tol=1e-1)
    assert math.isclose(meta_results["ci_lower"], 2044.901507, abs_tol=1e-1)
    assert math.isclose(meta_results["ci_upper"], 2625.028605, abs_tol=1e-1)
    print("  [PASS] Random-effects meta-analysis matches independent hand calculation.\n")

    print("--- Test 5: Directionality Ratio Pooling ---")
    all_records = [site_1, site_2, site_3]
    dir_results = synthesize_directionality(all_records)

    print(f"  Contributing Sites: {dir_results['contributing_sites']} of {len(all_records)}")
    print(f"  Total After:        {dir_results['total_after']}")
    print(f"  Total Before:       {dir_results['total_before']}")
    print(f"  Pooled DR:          {dir_results['dr_pooled']:.6f}")
    print(f"  Temporal Category:  {dir_results['category']}")

    # Expected: total_after = 120 + 350 = 470, total_before = 40 + 110 = 150
    # DR = (470 + 0.5) / (150 + 0.5) = 470.5 / 150.5 = 3.126246
    assert dir_results["contributing_sites"] == 2
    assert dir_results["total_after"] == 470
    assert dir_results["total_before"] == 150
    assert math.isclose(dir_results["dr_pooled"], 3.126246, abs_tol=1e-5)
    assert dir_results["category"] == "Empirically Preceding"
    print("  [PASS] Directionality ratio pooling verified.\n")

    print("================================================================================")
    print("FEASIBILITY GATE PASSED: 100% agreement on schema, masking, and reference math.")
    print("Scope boundary preserved: Demonstrates transport & math correctness, not clinical validity.")
    print("================================================================================")


if __name__ == "__main__":
    run_benchmark()
