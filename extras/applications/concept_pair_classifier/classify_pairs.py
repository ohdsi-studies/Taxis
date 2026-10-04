#!/usr/bin/env python3
"""
TAXIS Downstream Application Prototype: Concept Pair Temporal Classifier
========================================================================
Illustrative downstream tool demonstrating how pre-computed aggregate
association summaries from TAXIS (cab_s55_pair_all) can be classified into
descriptive temporal categories based on continuity-corrected Directionality
Ratio (DR) while enforcing strict small-cell privacy protection.

Operational Boundary Notice (DEC-GR-027, DEC-GR-029):
This is an illustrative proof-of-concept downstream application, not part of the
core network study package execution on partner CDMs (extras/CodeToRun.R).
Observational temporal sequence is supporting descriptive evidence and does NOT
establish clinical roles, biological mechanisms, or causal relationships.
"""

import os
import sys
import argparse
import psycopg


def get_connection(host=None, port=None, dbname=None, user=None, password=None):
    return psycopg.connect(
        host=host or os.environ.get("POSTGRES_HOST", "localhost"),
        port=int(port or os.environ.get("POSTGRES_PORT", 5433)),
        dbname=dbname or os.environ.get("POSTGRES_DB", "synthea"),
        user=user or os.environ.get("POSTGRES_USER", "ohdsi_app"),
        password=password or os.environ.get("POSTGRES_PASSWORD", "ohdsi_app_pass_2026")
    )


def compute_directionality_ratio(obs_after, obs_before):
    """
    Calculate continuity-corrected Directionality Ratio (DR):
    DR = (obs_after + 0.5) / (obs_before + 0.5)
    """
    after_val = float(obs_after) if obs_after is not None else 0.0
    before_val = float(obs_before) if obs_before is not None else 0.0
    return (after_val + 0.5) / (before_val + 0.5)


def categorize_temporal_direction(obs_after, obs_before, dr):
    """
    Assign descriptive temporal category with explicit handling of edge cases:
    - If either directional cell is suppressed (< 5): Directionality Suppressed (<5)
    - If both after and before counts are zero: No Directional Precedence Observed
    - If valid counts (>= 5):
        * DR >= 1.50: Empirically Preceding (Concept A precedes B)
        * DR <= 0.67: Empirically Following (Concept B precedes A)
        * 0.67 < DR < 1.50: Empirically Balanced / Non-Directional
    """
    after_val = int(obs_after) if obs_after is not None else 0
    before_val = int(obs_before) if obs_before is not None else 0

    if (0 < after_val < 5) or (0 < before_val < 5):
        return "Directionality Suppressed (<5 count)"

    if after_val == 0 and before_val == 0:
        return "No Directional Precedence Observed"

    if after_val < 5 or before_val < 5:
        return "Directionality Suppressed (<5 count)"

    if dr >= 1.50:
        return "Empirically Preceding (Concept A precedes B)"
    elif dr <= 0.67:
        return "Empirically Following (Concept B precedes A)"
    else:
        return "Empirically Balanced / Non-Directional"


def sanitize_pair_record(row):
    """
    Enforce comprehensive small-cell privacy protection across all fields:
    - Entirely withholds records where total observations < 5.
    - If any directional count (obs_after, obs_before, obs_same_day) is 0 < count < 5:
        * Count is masked to -1 (displayed as '<5').
        * Derived directional statistics (dr_corrected, dir_ab_sql) are suppressed
          (set to None) to prevent algebraic reconstruction of the hidden cell.
        * If subtraction could reveal a hidden cell (e.g. obs_all - obs_after - obs_same_day),
          obs_all is also masked to -1 to prevent complementary disclosure.
    - Returns sanitized dict or None if row is unsafe/withheld.
    """
    cid_a, cname_a, cid_b, cname_b, obs_all, obs_sd, obs_after, obs_before, lift_after, dir_ab = row

    all_val = int(obs_all) if obs_all is not None else 0
    sd_val = int(obs_sd) if obs_sd is not None else 0
    aft_val = int(obs_after) if obs_after is not None else 0
    bef_val = int(obs_before) if obs_before is not None else 0

    # Withhold entire row if total co-occurrences < 5
    if all_val < 5:
        return None

    has_small_directional_cell = (0 < aft_val < 5) or (0 < bef_val < 5) or (0 < sd_val < 5)

    if has_small_directional_cell:
        # Mask counts
        safe_all = -1
        safe_sd = -1 if 0 < sd_val < 5 else sd_val
        safe_aft = -1 if 0 < aft_val < 5 else aft_val
        safe_bef = -1 if 0 < bef_val < 5 else bef_val
        # Suppress derived metrics to prevent algebraic inversion
        safe_dr = None
        safe_dir_ab = None
        safe_lift_aft = None if (0 < aft_val < 5) else (round(lift_after, 3) if lift_after is not None else None)
        category = "Directionality Suppressed (<5 count)"
    else:
        safe_all = all_val
        safe_sd = sd_val
        safe_aft = aft_val
        safe_bef = bef_val
        safe_lift_aft = round(lift_after, 3) if lift_after is not None else None
        safe_dir_ab = round(dir_ab, 4) if dir_ab is not None else None
        raw_dr = compute_directionality_ratio(aft_val, bef_val)
        category = categorize_temporal_direction(aft_val, bef_val, raw_dr)
        safe_dr = round(raw_dr, 4) if category != "Directionality Suppressed (<5 count)" else None

    return {
        "concept_id_a": cid_a,
        "concept_name_a": cname_a,
        "concept_id_b": cid_b,
        "concept_name_b": cname_b,
        "obs_all": safe_all,
        "obs_same_day": safe_sd,
        "obs_after": safe_aft,
        "obs_before": safe_bef,
        "lift_after": safe_lift_aft,
        "dir_ab_sql": safe_dir_ab,
        "dr_corrected": safe_dr,
        "temporal_category": category
    }


def classify_pairs(concept_id=None, concept_name=None, schema="work_cab_test", min_obs=5, limit=25):
    with get_connection() as conn:
        with conn.cursor() as cur:
            if concept_id is not None:
                sql = f"""
                    SELECT 
                        concept_a, concept_name_a,
                        concept_b, concept_name_b,
                        obs_all, obs_same_day, obs_after, obs_before,
                        lift_after, dir_ab
                    FROM {schema}.cab_s55_pair_all
                    WHERE concept_a = %s AND obs_all >= %s
                    ORDER BY obs_all DESC
                    LIMIT %s;
                """
                cur.execute(sql, (concept_id, min_obs, limit))
            elif concept_name is not None:
                sql = f"""
                    SELECT 
                        concept_a, concept_name_a,
                        concept_b, concept_name_b,
                        obs_all, obs_same_day, obs_after, obs_before,
                        lift_after, dir_ab
                    FROM {schema}.cab_s55_pair_all
                    WHERE concept_name_a ILIKE %s AND obs_all >= %s
                    ORDER BY obs_all DESC
                    LIMIT %s;
                """
                cur.execute(sql, (f"%{concept_name}%", min_obs, limit))
            else:
                raise ValueError("Must provide either concept_id or concept_name")

            rows = cur.fetchall()

    classified = []
    for r in rows:
        record = sanitize_pair_record(r)
        if record is not None:
            classified.append(record)
    return classified


def print_table(results):
    if not results:
        print("No concept pairs found matching criteria.")
        return

    print(f"\nTarget Concept: {results[0]['concept_name_a']} (Concept ID: {results[0]['concept_id_a']})")
    print(f"{'Co-occurring Concept':<35} | {'Obs':>6} | {'After':>6} | {'Bef':>6} | {'Lift_Aft':>8} | {'DR':>8} | {'Temporal Sequence Category'}")
    print("-" * 125)
    for row in results:
        b_name = (row['concept_name_b'][:32] + '...') if len(row['concept_name_b']) > 35 else row['concept_name_b']
        obs = str(row['obs_all']) if row['obs_all'] != -1 else "<5"
        aft = str(row['obs_after']) if row['obs_after'] != -1 else "<5"
        bef = str(row['obs_before']) if row['obs_before'] != -1 else "<5"
        lift = f"{row['lift_after']:.2f}" if row['lift_after'] is not None else "Suppr"
        dr = f"{row['dr_corrected']:.2f}" if row['dr_corrected'] is not None else "Suppr"
        cat = row['temporal_category']
        print(f"{b_name:<35} | {obs:>6} | {aft:>6} | {bef:>6} | {lift:>8} | {dr:>8} | {cat}")
    print("-" * 125)
    print("Privacy Protection: Cells with counts < 5 and derived ratios subject to algebraic reconstruction are masked.")
    print("Directionality Ratio DR = (obs_after + 0.5) / (obs_before + 0.5) for cells >= 5.\n")


def main():
    parser = argparse.ArgumentParser(description="TAXIS Downstream Concept Pair Classifier Demo")
    parser.add_argument("--concept-id", type=int, help="Target Concept ID (e.g. 260139 for Acute bronchitis)")
    parser.add_argument("--concept-name", type=str, help="Target Concept Name search query (e.g. 'bronchitis')")
    parser.add_argument("--schema", type=str, default="work_cab_test", help="Database results schema")
    parser.add_argument("--min-obs", type=int, default=5, help="Minimum observed co-occurrence count")
    parser.add_argument("--limit", type=int, default=20, help="Maximum number of pairs to retrieve")

    args = parser.parse_args()
    cid = args.concept_id
    cname = args.concept_name
    if cid is None and cname is None:
        cname = "bronchitis"

    results = classify_pairs(concept_id=cid, concept_name=cname, schema=args.schema, min_obs=args.min_obs, limit=args.limit)
    print_table(results)


if __name__ == "__main__":
    main()
