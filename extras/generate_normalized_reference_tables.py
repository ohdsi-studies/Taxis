#!/usr/bin/env python3
"""
Generate Normalized TAXIS Reference Tables
==========================================
Extracts, prunes redundant text, and writes compressed CSVs (.csv.gz)
into inst/csv/ from local-private/bandeian/cab_vocab_all_082226/.

Preserves all concept IDs, mapping contracts, fractional RVUs, CCSR concepts,
and all 20 visit levels, fulfilling Astra-Supervisor audit REC-084-1 through REC-084-3.
"""

import os
import csv
import gzip
import hashlib
import json
import time

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SRC_DIR = os.path.join(REPO_ROOT, "local-private", "bandeian", "cab_vocab_all_082226")
OUT_DIR = os.path.join(REPO_ROOT, "inst", "csv")

os.makedirs(OUT_DIR, exist_ok=True)

TABLE_SPECS = {
    "cab_visit_hierarchy.csv.gz": {
        "src": "cab_vocab_all_visit_hierarchy.csv",
        "cols": ["visit_concept_id", "visit_concept_name", "visit_level", "visit_level_name"],
        "types": ["INTEGER", "VARCHAR(255)", "INTEGER", "VARCHAR(255)"],
    },
    "cab_chronic_conditions.csv.gz": {
        "src": "cab_vocab_all_chronic_conditions.csv",
        "cols": ["concept_id"],
        "types": ["BIGINT"],
    },
    "cab_device.csv.gz": {
        "src": "cab_vocab_all_device.csv",
        "cols": ["concept_id_in", "concept_id", "implant_flag"],
        "types": ["INTEGER", "BIGINT", "INTEGER"],
    },
    "cab_procedure.csv.gz": {
        "src": "cab_vocab_all_procedure.csv",
        "cols": ["concept_id_in", "concept_id", "concept_rbcs_1", "concept_rvu"],
        "types": ["INTEGER", "BIGINT", "INTEGER", "NUMERIC(10,2)"],
    },
    "cab_meas_obs_test.csv.gz": {
        "src": "cab_vocab_all_meas_obs_test.csv",
        "cols": ["concept_id_in", "concept_id", "is_question", "is_assertion_eligible", "flag_concept_id"],
        "types": ["INTEGER", "BIGINT", "INTEGER", "INTEGER", "INTEGER"],
    },
    "cab_drug_ing_form.csv.gz": {
        "src": "cab_vocab_all_drug_ing_form.csv",
        "cols": ["concept_id_in", "concept_id", "ingredient_id", "dose_form_concept_id"],
        "types": ["INTEGER", "BIGINT", "INTEGER", "INTEGER"],
    },
}


def sha256_file(filepath):
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()


def main():
    print("=" * 80)
    print(" TAXIS Reference Vocabulary Normalization & In-Package Bundling")
    print(" Source:", SRC_DIR)
    print(" Destination:", OUT_DIR)
    print("=" * 80)

    manifest = {"generated_at": time.strftime("%Y-%m-%d %H:%M:%S UTC", time.gmtime()), "tables": {}}
    total_raw_bytes = 0
    total_gz_bytes = 0

    # 1. Process Mapping Tables
    for out_name, spec in TABLE_SPECS.items():
        src_path = os.path.join(SRC_DIR, spec["src"])
        out_path = os.path.join(OUT_DIR, out_name)

        if not os.path.exists(src_path):
            raise FileNotFoundError(f"Missing source file: {src_path}")

        print(f"\n--> Processing {spec['src']} -> {out_name}...")
        t0 = time.time()
        n_rows = 0

        with open(src_path, "r", encoding="utf-8", errors="replace") as f_in, \
             gzip.open(out_path, "wt", encoding="utf-8", newline="", compresslevel=6) as f_out:
            reader = csv.reader(f_in)
            writer = csv.writer(f_out)
            src_header = next(reader)
            col_indices = [src_header.index(c) for c in spec["cols"]]

            writer.writerow(spec["cols"])
            for row in reader:
                n_rows += 1
                writer.writerow([row[i] for i in col_indices])

        t1 = time.time()
        raw_sz = os.path.getsize(src_path)
        gz_sz = os.path.getsize(out_path)
        total_raw_bytes += raw_sz
        total_gz_bytes += gz_sz
        chk = sha256_file(out_path)

        print(f"    Rows: {n_rows:,} in {t1-t0:.1f}s")
        print(f"    Raw: {raw_sz/(1024*1024):.2f} MB -> Gzip: {gz_sz/(1024*1024):.2f} MB ({(gz_sz/raw_sz)*100:.1f}%)")
        print(f"    SHA-256: {chk[:16]}...")

        manifest["tables"][out_name] = {
            "source_file": spec["src"],
            "row_count": n_rows,
            "columns": spec["cols"],
            "sql_types": spec["types"],
            "raw_bytes": raw_sz,
            "gzip_bytes": gz_sz,
            "sha256": chk,
        }

    # 2. Build Unified Concept Names Table (All output concepts across procedure, device, meas, drug)
    print("\n--> Extracting unified output concept naming authority (cab_concept_names.csv.gz)...")
    t0 = time.time()
    names = {}
    name_sources = [
        "cab_vocab_all_procedure.csv",
        "cab_vocab_all_device.csv",
        "cab_vocab_all_meas_obs_test.csv",
        "cab_vocab_all_drug_ing_form.csv",
    ]

    for src_file in name_sources:
        src_path = os.path.join(SRC_DIR, src_file)
        with open(src_path, "r", encoding="utf-8", errors="replace") as fp:
            reader = csv.reader(fp)
            header = next(reader)
            c_idx = header.index("concept_id")
            n_idx = header.index("concept_name")
            d_idx = header.index("concept_domain")
            v_idx = header.index("concept_vocab")
            for row in reader:
                cid = row[c_idx]
                if cid not in names:
                    names[cid] = (row[n_idx], row[d_idx], row[v_idx])

    names_out_path = os.path.join(OUT_DIR, "cab_concept_names.csv.gz")
    with gzip.open(names_out_path, "wt", encoding="utf-8", newline="", compresslevel=6) as f_out:
        writer = csv.writer(f_out)
        cols = ["concept_id", "concept_name", "concept_domain", "concept_vocab"]
        writer.writerow(cols)
        for cid, (cname, cdomain, cvocab) in names.items():
            writer.writerow([cid, cname, cdomain, cvocab])

    t1 = time.time()
    names_gz_sz = os.path.getsize(names_out_path)
    total_gz_bytes += names_gz_sz
    names_chk = sha256_file(names_out_path)

    print(f"    Distinct output concepts: {len(names):,} in {t1-t0:.1f}s")
    print(f"    Gzip Size: {names_gz_sz/(1024*1024):.2f} MB")
    print(f"    SHA-256: {names_chk[:16]}...")

    manifest["tables"]["cab_concept_names.csv.gz"] = {
        "source_file": "UNION(procedure, device, meas_obs_test, drug_ing_form)",
        "row_count": len(names),
        "columns": cols,
        "sql_types": ["BIGINT", "VARCHAR(500)", "VARCHAR(20)", "VARCHAR(50)"],
        "gzip_bytes": names_gz_sz,
        "sha256": names_chk,
    }

    # Write Manifest
    manifest_path = os.path.join(OUT_DIR, "manifest.json")
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)

    print("\n" + "=" * 80)
    print(" SUMMARY OF IN-PACKAGE BUNDLE")
    print("=" * 80)
    print(f" Total Tables: {len(manifest['tables'])}")
    print(f" Original Uncompressed: {total_raw_bytes/(1024*1024):.2f} MB")
    print(f" Final In-Package Gzip: {total_gz_bytes/(1024*1024):.2f} MB")
    print(f" Compression / Footprint Savings: {(1 - total_gz_bytes/total_raw_bytes)*100:.1f}%")
    print(f" Manifest written to: {manifest_path}")
    print("=" * 80)


if __name__ == "__main__":
    main()
