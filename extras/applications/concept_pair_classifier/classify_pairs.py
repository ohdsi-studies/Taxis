#!/usr/bin/env python3
"""
TAXIS Downstream Application Prototype: Concept Pair Clinical Classifier
========================================================================
Illustrative downstream tool demonstrating how pre-computed association
summaries from TAXIS (cab_s55_pair_all) can be classified into candidate
clinical relationship categories based on continuity-corrected Directionality
Ratio (DR) and stratified lift.

Operational Boundary Notice (DEC-GR-027, DEC-GR-029):
This is an illustrative proof-of-concept application, not part of the core
network study package execution (extras/CodeToRun.R).
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


def categorize_pair(dr, lift_after):
    """
    Assign illustrative relationship category based on empirical metrics:
    - DR >= 1.50: Forward Predominant (candidate antecedent / prodromal)
    - 0.67 < DR < 1.50: Concurrent / Balanced (candidate diagnostic / presentation)
    - DR <= 0.67: Reverse Predominant (candidate intervention / sequela)
    """
    if dr >= 1.50:
        return "Forward Predominant (Candidate Precursor / Antecedent)"
    elif dr <= 0.67:
        return "Reverse Predominant (Candidate Intervention / Sequela)"
    else:
        return "Concurrent / Balanced (Candidate Diagnostic / Biomarker)"


def suppress_cell(val):
    """Enforce aggregate small-cell privacy suppression (< 5 -> -1)."""
    if val is None:
        return 0
    num = int(val)
    return -1 if 0 < num < 5 else num


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
        cid_a, cname_a, cid_b, cname_b, obs_all, obs_sd, obs_after, obs_before, lift_after, dir_ab = r
        dr = compute_directionality_ratio(obs_after, obs_before)
        category = categorize_pair(dr, lift_after)
        classified.append({
            "concept_id_a": cid_a,
            "concept_name_a": cname_a,
            "concept_id_b": cid_b,
            "concept_name_b": cname_b,
            "obs_all": suppress_cell(obs_all),
            "obs_same_day": suppress_cell(obs_sd),
            "obs_after": suppress_cell(obs_after),
            "obs_before": suppress_cell(obs_before),
            "lift_after": round(lift_after, 3) if lift_after is not None else None,
            "dir_ab_sql": round(dir_ab, 4) if dir_ab is not None else None,
            "dr_corrected": round(dr, 4),
            "candidate_category": category
        })
    return classified


def print_table(results):
    if not results:
        print("No concept pairs found matching criteria.")
        return

    print(f"\nTarget Concept: {results[0]['concept_name_a']} (Concept ID: {results[0]['concept_id_a']})")
    print(f"{'Co-occurring Concept':<35} | {'Obs':>6} | {'After':>6} | {'Bef':>6} | {'Lift_Aft':>8} | {'DR':>6} | {'Candidate Relationship'}")
    print("-" * 115)
    for row in results:
        b_name = (row['concept_name_b'][:32] + '...') if len(row['concept_name_b']) > 35 else row['concept_name_b']
        obs = str(row['obs_all']) if row['obs_all'] != -1 else "<5"
        aft = str(row['obs_after']) if row['obs_after'] != -1 else "<5"
        bef = str(row['obs_before']) if row['obs_before'] != -1 else "<5"
        lift = f"{row['lift_after']:.2f}" if row['lift_after'] is not None else "N/A"
        dr = f"{row['dr_corrected']:.2f}"
        cat = row['candidate_category']
        print(f"{b_name:<35} | {obs:>6} | {aft:>6} | {bef:>6} | {lift:>8} | {dr:>6} | {cat}")
    print("-" * 115)
    print("Note: Counts < 5 are masked to '<5' for privacy suppression.")
    print("Directionality Ratio DR = (obs_after + 0.5) / (obs_before + 0.5).\n")


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
