#!/usr/bin/env python3
"""
extras/test_synthetic_pair_federated_synthesis.py

Synthetic Arithmetic & Schema Benchmark: Single-Pair Multi-Site Meta-Analysis
Fulfills REC-073-1, REC-073-2, REC-073-4 and DEC-GR-027, DEC-GR-028, DEC-GR-032 governance requirements.

This script demonstrates an in-memory, reproducible synthetic arithmetic and schema
benchmark for synthesizing one ordered concept pair (A, B) across heterogeneous synthetic
site records using DerSimonian-Laird random-effects meta-analysis and aggregate directionality pooling.

Key Capabilities Verified:
  1. Input Schema & Privacy Boundary Gate: Rejects unsuppressed small cells (1 <= c < 5),
     non-finite denominators (NaN, Inf, <= 0), invalid data types, and count values < -1.
  2. Compatibility Validation: Enforces matching concept IDs, pair types, anchor codes,
     window widths (win_w), and observation grains across site records prior to synthesis.
  3. Site-Level Estimation: Computes expected counts using the exact TAXIS SQL forward-window
     estimand ((obs_a * obs_b * win_w) / observation_person_days) matching concept_ab_finalize.sql:405.
  4. Illustrative Delta-Method Variance: Derives Var(ln(Lift)) ~ 1/O_after + 1/O_A + 1/O_B under
     an independent Poisson count approximation (treating covariance terms as an illustrative heuristic).
  5. DerSimonian-Laird Random-Effects Pooling: Q, tau^2, I^2, pooled lift, and 95% CI.
     Explicitly records prediction intervals as unavailable for K <= 2 (df = 0 under t-distribution).
  6. Directionality Ratio Pooling: Aggregates directional counts with continuity correction;
     gracefully returns indeterminate status when directional events are zero (after = before = 0).
  7. Edge-Case Resilience: Gracefully handles all-suppressed inputs and zero-event sites.

Scope Note (REC-073-4):
  This benchmark establishes computational arithmetic and schema correctness for proposed
  federated synthesis calculations. It constructs records strictly in memory and does NOT
  assert data transport feasibility, network serialization, or clinical generalizability.
"""

import math
import sys
from typing import Dict, List, Optional, Tuple, Any


class SitePairRecord:
    """Standardized schema for site-level aggregate pair records with input boundary privacy gate."""

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
        anchor_code: int = 1,
        win_w: float = 35.0,
        grain: str = "occurrence_events",
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
        if type(anchor_code) is not int or anchor_code != 1:
            raise ValueError(f"anchor_code must be integer 1 (ordinary forward event model), got {anchor_code}")
        self.anchor_code = anchor_code
        self.win_w = float(win_w)
        self.grain = grain

        self._validate()

    def _validate(self):
        """Validate input values against schema rules and privacy gate (REC-073-2, REC-074-1)."""
        if not self.site_id or not isinstance(self.site_id, str):
            raise ValueError("site_id must be a non-empty string")
        if not math.isfinite(self.observation_person_days) or self.observation_person_days <= 0:
            raise ValueError("observation_person_days must be a finite positive number")
        if not math.isfinite(self.win_w) or self.win_w <= 0:
            raise ValueError("win_w must be a finite positive number")
        if type(self.anchor_code) is not int or self.anchor_code != 1:
            raise ValueError(f"anchor_code must be integer 1 (ordinary forward event model), got {self.anchor_code}")
        if self.grain != "occurrence_events":
            raise ValueError(f"Unsupported grain '{self.grain}'; only 'occurrence_events' supported")

        # Strict privacy gate: reject unsuppressed small cells (1 <= c < 5) and non-integers
        for name, val in [
            ("obs_after", self.obs_after),
            ("obs_before", self.obs_before),
            ("obs_same_day", self.obs_same_day),
            ("obs_a", self.obs_a),
            ("obs_b", self.obs_b),
        ]:
            if type(val) is not int:
                raise TypeError(f"{name} must be an integer, got {type(val).__name__}")
            if val < -1:
                raise ValueError(f"{name} cannot be less than -1")
            if 1 <= val < 5:
                raise ValueError(
                    f"Privacy validation failure: count {name}={val} violates small-cell "
                    f"suppression protocol (<5 must be masked to -1)"
                )

    @property
    def is_suppressed(self) -> bool:
        """Return True if any count is masked under small-cell suppression (<5 -> -1)."""
        counts = [self.obs_after, self.obs_before, self.obs_same_day, self.obs_a, self.obs_b]
        return any(c == -1 for c in counts)

    def compute_site_estimates(self) -> Optional[Dict[str, Any]]:
        """
        Compute site-level lift, log-lift, and delta-method variance matching TAXIS SQL estimand.
        Returns None if record is suppressed or has zero observed co-occurrences.
        """
        if self.is_suppressed:
            return None

        if self.obs_after <= 0 or self.obs_a <= 0 or self.obs_b <= 0:
            return None

        # Exact estimand matching concept_ab_finalize.sql:405:
        # obs_exp = (obs_a * obs_b * win_w) / total_person_days
        expected_after = (self.obs_a * self.obs_b * self.win_w) / self.observation_person_days
        if expected_after <= 0:
            return None

        lift_after = self.obs_after / expected_after
        log_lift = math.log(lift_after)

        # NOTE on Variance Approximations (REC-073-1):
        # This variance formulation employs a first-order delta method under an independent Poisson
        # count approximation: Var(ln(Lift)) ~ 1/O_after + 1/O_A + 1/O_B.
        # This treats O_after, O_A, and O_B as independent realizations and omits the covariance
        # terms Cov(O_after, O_A) and Cov(O_after, O_B). In empirical longitudinal healthcare data,
        # pair co-occurrences and marginal counts share underlying patient trajectories, so omitting
        # covariance is strictly an illustrative heuristic approximation until full multinomial or
        # bootstrap covariance estimators are formally supported.
        variance = (1.0 / self.obs_after) + (1.0 / self.obs_a) + (1.0 / self.obs_b)

        return {
            "site_id": self.site_id,
            "concept_id_a": self.concept_id_a,
            "concept_id_b": self.concept_id_b,
            "pair_type": self.pair_type,
            "anchor_code": self.anchor_code,
            "win_w": self.win_w,
            "expected_after": expected_after,
            "lift_after": lift_after,
            "log_lift": log_lift,
            "variance": variance,
        }


def _validate_compatibility(records: List[SitePairRecord]):
    """
    Validate that all records share uniform pair, window, anchor, and grain definitions (REC-073-1, REC-074-1).
    """
    if not records:
        raise ValueError("Cannot synthesize empty list of records")

    ref_a = records[0].concept_id_a
    ref_b = records[0].concept_id_b
    ref_type = records[0].pair_type
    ref_anchor = records[0].anchor_code
    ref_win = records[0].win_w
    ref_grain = records[0].grain

    for r in records:
        if (
            r.concept_id_a != ref_a
            or r.concept_id_b != ref_b
            or r.pair_type != ref_type
            or r.anchor_code != ref_anchor
            or not math.isclose(r.win_w, ref_win, abs_tol=1e-5)
            or r.grain != ref_grain
        ):
            raise ValueError(
                f"Incompatible site pair definitions or window parameters: "
                f"expected (A={ref_a}, B={ref_b}, type={ref_type}, anchor={ref_anchor}, win_w={ref_win}, grain={ref_grain}), "
                f"got site '{r.site_id}' with (A={r.concept_id_a}, B={r.concept_id_b}, type={r.pair_type}, "
                f"anchor={r.anchor_code}, win_w={r.win_w}, grain={r.grain})"
            )


def synthesize_random_effects_lift(
    records: List[SitePairRecord],
) -> Dict[str, Any]:
    """
    Synthesize site-level log-lift estimates via DerSimonian-Laird random effects.
    Validates parameter compatibility across sites prior to pooling (REC-073-1, REC-074-1).
    """
    _validate_compatibility(records)

    site_estimates = []
    for r in records:
        est = r.compute_site_estimates()
        if est is not None:
            site_estimates.append(est)

    k = len(site_estimates)
    if k == 0:
        return {
            "k_sites": 0,
            "pooled_log_lift": None,
            "se_pooled": None,
            "pooled_lift": None,
            "ci_lower": None,
            "ci_upper": None,
            "cochrans_q": None,
            "tau_squared": None,
            "i_squared": None,
            "prediction_interval": None,
            "status": "No usable unmasked sites for pooling",
        }

    if k == 1:
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
            "prediction_interval": None,
            "status": "Single site only; between-study heterogeneity not evaluable",
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

    # Prediction interval (REC-073-3):
    # For K <= 2, degrees of freedom df = K - 2 <= 0 under the t-distribution;
    # between-study heterogeneity is poorly estimated, and prediction intervals are undefined.
    prediction_interval = None
    pi_note = "Unavailable / undefined for K <= 2 (df = 0 under t-distribution; see Cochrane Handbook 10.10.3)"

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
        "prediction_interval": prediction_interval,
        "prediction_interval_note": pi_note,
        "status": "Success",
    }


def synthesize_directionality(records: List[SitePairRecord]) -> Dict[str, Any]:
    """
    Synthesize directional counts across participating sites with continuity correction.
    Masked records (<5) are omitted from count summation.
    Validates parameter compatibility across sites prior to pooling (REC-073-1, REC-074-1).
    Returns Indeterminate status if directional counts are zero (REC-073-2).
    """
    _validate_compatibility(records)

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

    # Zero directional events edge case (REC-073-2)
    if total_after == 0 and total_before == 0:
        return {
            "contributing_sites": contributing_sites,
            "total_after": 0,
            "total_before": 0,
            "total_same_day": total_same_day,
            "dr_pooled": None,
            "category": "Indeterminate / Insufficient Directional Counts",
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
    print("FEASIBILITY GATE: Single-Pair Multi-Site Synthetic Arithmetic Benchmark")
    print("Governance: DEC-GR-027, DEC-GR-028, DEC-GR-032 | Supervisory Review: REV-073")
    print("================================================================================\n")

    # 1. Define synthetic sites
    # Concept Pair: 255573 (COPD) -> 40241331 (Inhaled Long-Acting Beta-Agonist)
    concept_a = 255573
    concept_b = 40241331
    pair_type = "condition | drug"
    anchor_code = 1
    win_w = 35.0  # 35-day forward co-occurrence window

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
        anchor_code=anchor_code,
        win_w=win_w,
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
        anchor_code=anchor_code,
        win_w=win_w,
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
        anchor_code=anchor_code,
        win_w=win_w,
    )

    print("--- Test 1: Schema Validation & Masking Detection ---")
    assert not site_1.is_suppressed, "Site 1 should not be suppressed"
    assert not site_2.is_suppressed, "Site 2 should not be suppressed"
    assert site_3.is_suppressed, "Site 3 must be detected as suppressed"
    print("  [PASS] Masking detection verified: Site 3 correctly quarantined.\n")

    print("--- Test 2: Input Boundary Privacy & Denominator Gate (REC-073-2) ---")
    # Test 2a: Unsuppressed count of 1-4 must be rejected
    try:
        SitePairRecord(
            site_id="VIOLATION_SITE",
            concept_id_a=concept_a,
            concept_id_b=concept_b,
            pair_type=pair_type,
            obs_after=3,  # Violates <5 suppression rule
            obs_before=10,
            obs_same_day=0,
            obs_a=100,
            obs_b=100,
            observation_person_days=100000.0,
        )
        assert False, "Should have raised ValueError for unsuppressed cell count in 1..4"
    except ValueError as e:
        print(f"  [PASS] Unsuppressed small-cell count (<5) rejected: {e}")

    # Test 2b: NaN / non-finite person-days must be rejected
    try:
        SitePairRecord(
            site_id="NAN_DENOM_SITE",
            concept_id_a=concept_a,
            concept_id_b=concept_b,
            pair_type=pair_type,
            obs_after=10,
            obs_before=10,
            obs_same_day=0,
            obs_a=100,
            obs_b=100,
            observation_person_days=float("nan"),
        )
        assert False, "Should have raised ValueError for NaN observation_person_days"
    except ValueError as e:
        print(f"  [PASS] NaN person-days denominator rejected: {e}")

    # Test 2c: Non-positive person-days must be rejected
    try:
        SitePairRecord(
            site_id="ZERO_DENOM_SITE",
            concept_id_a=concept_a,
            concept_id_b=concept_b,
            pair_type=pair_type,
            obs_after=10,
            obs_before=10,
            obs_same_day=0,
            obs_a=100,
            obs_b=100,
            observation_person_days=0.0,
        )
        assert False, "Should have raised ValueError for zero observation_person_days"
    except ValueError as e:
        print(f"  [PASS] Zero person-days denominator rejected: {e}")

    # Test 2d: Negative count below -1 must be rejected
    try:
        SitePairRecord(
            site_id="NEGATIVE_SITE",
            concept_id_a=concept_a,
            concept_id_b=concept_b,
            pair_type=pair_type,
            obs_after=-5,
            obs_before=10,
            obs_same_day=0,
            obs_a=100,
            obs_b=100,
            observation_person_days=100000.0,
        )
        assert False, "Should have raised ValueError for count < -1"
    except ValueError as e:
        print(f"  [PASS] Negative count < -1 rejected: {e}")

    # Test 2e: Non-integer / boolean count must be rejected
    try:
        SitePairRecord(
            site_id="BOOL_SITE",
            concept_id_a=concept_a,
            concept_id_b=concept_b,
            pair_type=pair_type,
            obs_after=True,  # type: ignore
            obs_before=10,
            obs_same_day=0,
            obs_a=100,
            obs_b=100,
            observation_person_days=100000.0,
        )
        assert False, "Should have raised TypeError for boolean count"
    except TypeError as e:
        print(f"  [PASS] Boolean count rejected: {e}\n")

    print("--- Test 3: Incompatible Pair & Window Definition Rejection (REC-073-1, REC-074-1) ---")
    # Test anchor_code = 4 rejection (REC-074-1)
    try:
        SitePairRecord(
            site_id="ANCHOR_4_SITE",
            concept_id_a=concept_a,
            concept_id_b=concept_b,
            pair_type=pair_type,
            obs_after=50,
            obs_before=20,
            obs_same_day=5,
            obs_a=500,
            obs_b=500,
            observation_person_days=1000000.0,
            anchor_code=4,
            win_w=win_w,
        )
        assert False, "Should have raised ValueError for anchor_code=4"
    except ValueError as e:
        print(f"  [PASS] Unimplemented anchor_code=4 rejected at input: {e}")

    incompatible_site_window = SitePairRecord(
        site_id="DIFF_WINDOW_SITE",
        concept_id_a=concept_a,
        concept_id_b=concept_b,
        pair_type=pair_type,
        obs_after=50,
        obs_before=20,
        obs_same_day=5,
        obs_a=500,
        obs_b=500,
        observation_person_days=1000000.0,
        win_w=14.0,  # 14 days vs 35 days
    )
    # Test rejection through synthesize_random_effects_lift
    try:
        synthesize_random_effects_lift([site_1, incompatible_site_window])
        assert False, "Should have raised ValueError for incompatible win_w in lift pooling"
    except ValueError as e:
        print(f"  [PASS] Incompatible window width rejected in lift pooling: {e}")

    # Test rejection through synthesize_directionality (REC-074-1)
    try:
        synthesize_directionality([site_1, incompatible_site_window])
        assert False, "Should have raised ValueError for incompatible win_w in directionality pooling"
    except ValueError as e:
        print(f"  [PASS] Incompatible window width rejected in directionality pooling: {e}")

    incompatible_site_concept = SitePairRecord(
        site_id="DIFF_CONCEPT_SITE",
        concept_id_a=concept_a,
        concept_id_b=99999999,  # Mismatched Concept B
        pair_type=pair_type,
        obs_after=50,
        obs_before=20,
        obs_same_day=5,
        obs_a=500,
        obs_b=500,
        observation_person_days=1000000.0,
        win_w=win_w,
    )
    try:
        synthesize_random_effects_lift([site_1, incompatible_site_concept])
        assert False, "Should have raised ValueError for mismatched concept ID in lift pooling"
    except ValueError as e:
        print(f"  [PASS] Incompatible concept ID rejected in lift pooling: {e}")

    try:
        synthesize_directionality([site_1, incompatible_site_concept])
        assert False, "Should have raised ValueError for mismatched concept ID in directionality pooling"
    except ValueError as e:
        print(f"  [PASS] Incompatible concept ID rejected in directionality pooling: {e}\n")

    print("--- Test 4: Edge Cases: Zero Directional Counts & All Masked Sites (REC-073-2) ---")
    zero_dir_site = SitePairRecord(
        site_id="ZERO_DIR_SITE",
        concept_id_a=concept_a,
        concept_id_b=concept_b,
        pair_type=pair_type,
        obs_after=0,
        obs_before=0,
        obs_same_day=5,
        obs_a=100,
        obs_b=100,
        observation_person_days=100000.0,
        win_w=win_w,
    )
    zero_dir_result = synthesize_directionality([zero_dir_site])
    assert zero_dir_result["dr_pooled"] is None, "Zero directional counts must yield None DR"
    assert zero_dir_result["category"] == "Indeterminate / Insufficient Directional Counts"
    print("  [PASS] Zero directional counts correctly returned Indeterminate.")

    all_masked_result = synthesize_random_effects_lift([site_3])
    assert all_masked_result["k_sites"] == 0
    assert all_masked_result["pooled_lift"] is None
    print("  [PASS] All-masked site list gracefully returns 0 usable sites.\n")

    print("--- Test 5: Site-Level Estimation & Estimand Alignment (REC-073-1) ---")
    est_1 = site_1.compute_site_estimates()
    est_2 = site_2.compute_site_estimates()
    est_3 = site_3.compute_site_estimates()

    assert est_1 is not None
    assert est_2 is not None
    assert est_3 is None, "Suppressed site must return None for site estimates"

    print(
        f"  Site 1 ({site_1.site_id}): Expected={est_1['expected_after']:.6f}, "
        f"Lift={est_1['lift_after']:.6f}, ln(Lift)={est_1['log_lift']:.6f}, Var={est_1['variance']:.8f}"
    )
    print(
        f"  Site 2 ({site_2.site_id}): Expected={est_2['expected_after']:.6f}, "
        f"Lift={est_2['lift_after']:.6f}, ln(Lift)={est_2['log_lift']:.6f}, Var={est_2['variance']:.8f}"
    )
    print("  Site 3: Correctly returned None (quarantined from pooling)\n")

    # Assert exact agreement with TAXIS SQL estimand (win_w = 35.0):
    # Site 1: Expected = (1500 * 2200 * 35) / 58197414 = 1.984624137
    # Lift = 120 / 1.984624137 = 60.4648464
    # ln(Lift) = 4.1020633
    # Var = 1/120 + 1/1500 + 1/2200 = 0.009454545
    assert math.isclose(est_1["expected_after"], 1.984624, abs_tol=1e-5)
    assert math.isclose(est_1["lift_after"], 60.464846, abs_tol=1e-3)
    assert math.isclose(est_1["log_lift"], 4.102063, abs_tol=1e-5)
    assert math.isclose(est_1["variance"], 0.009455, abs_tol=1e-5)

    # Site 2: Expected = (4000 * 6500 * 35) / 180000000 = 5.055555556
    # Lift = 350 / 5.055555556 = 69.2307692
    # ln(Lift) = 4.2374389
    # Var = 1/350 + 1/4000 + 1/6500 = 0.003260989
    assert math.isclose(est_2["expected_after"], 5.055556, abs_tol=1e-5)
    assert math.isclose(est_2["lift_after"], 69.230769, abs_tol=1e-3)
    assert math.isclose(est_2["log_lift"], 4.237439, abs_tol=1e-5)
    assert math.isclose(est_2["variance"], 0.003261, abs_tol=1e-5)
    print("  [PASS] Site-level estimates match exact TAXIS 35-day forward-window estimand.\n")

    print("--- Test 6: DerSimonian-Laird Random-Effects Pooling & Bounded Statistics (REC-073-1, REC-073-3) ---")
    meta_results = synthesize_random_effects_lift([site_1, site_2, site_3])

    print(f"  Contributing Sites: {meta_results['k_sites']}")
    print(f"  Pooled log-lift:    {meta_results['pooled_log_lift']:.6f}")
    print(f"  Standard Error:     {meta_results['se_pooled']:.6f}")
    print(
        f"  Pooled Lift:        {meta_results['pooled_lift']:.4f} "
        f"[95% CI: {meta_results['ci_lower']:.4f} - {meta_results['ci_upper']:.4f}]"
    )
    print(f"  Cochran's Q:        {meta_results['cochrans_q']:.6f} (df=1)")
    print(f"  Tau^2:              {meta_results['tau_squared']:.8f}")
    print(f"  I^2:                {meta_results['i_squared']:.2f}%")
    print(f"  Prediction Interval:{meta_results['prediction_interval']} ({meta_results['prediction_interval_note']})")

    # Reference values:
    # Q = 1.441436, tau2 = 0.002807, I2 = 30.62%
    # Pooled log-lift = 4.192628, SE = 0.063710
    # Pooled Lift = 66.1965 [95% CI: 58.4258 - 75.0008]
    assert meta_results["k_sites"] == 2
    assert math.isclose(meta_results["cochrans_q"], 1.441436, abs_tol=1e-4)
    assert math.isclose(meta_results["tau_squared"], 0.002807, abs_tol=1e-5)
    assert math.isclose(meta_results["i_squared"], 30.62, abs_tol=0.1)
    assert math.isclose(meta_results["pooled_log_lift"], 4.192628, abs_tol=1e-4)
    assert math.isclose(meta_results["se_pooled"], 0.063710, abs_tol=1e-4)
    assert math.isclose(meta_results["pooled_lift"], 66.1965, abs_tol=1e-2)
    assert math.isclose(meta_results["ci_lower"], 58.4258, abs_tol=1e-2)
    assert math.isclose(meta_results["ci_upper"], 75.0008, abs_tol=1e-2)
    assert meta_results["prediction_interval"] is None, "Prediction interval must be unavailable for K <= 2"
    print("  [PASS] Random-effects meta-analysis matches independent hand calculation.\n")

    print("--- Test 7: Directionality Ratio Pooling ---")
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
    print("Scope boundary preserved (REC-073-4): Demonstrates synthetic arithmetic correctness;")
    print("does NOT assert data transport feasibility or clinical generalizability.")
    print("================================================================================")


if __name__ == "__main__":
    run_benchmark()
