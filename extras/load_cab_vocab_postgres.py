#!/usr/bin/env python3
"""
Load CAB Vocabulary Lookup Tables into PostgreSQL
=================================================
Loads the 6 reference lookup tables required by the Concept AB Mining Engine (v57)
into PostgreSQL (database 'synthea', schema 'concept_ab_vocab').

Reference source:
  - DDL: local-private/bandeian/CONCEPT_AB_V57_Jeff/CONCEPT_AB_V57_Jeff/Load/cab_vocab_lookups_postgres.sql
  - CSVs: local-private/bandeian/cab_vocab_all_082226/*.csv
"""

import os
import sys
import time
import psycopg

POSTGRES_HOST = os.environ.get("POSTGRES_HOST", "localhost")
POSTGRES_PORT = int(os.environ.get("POSTGRES_PORT", 5433))
POSTGRES_DB = os.environ.get("POSTGRES_DB", "synthea")
POSTGRES_USER = os.environ.get("POSTGRES_USER", "ohdsi_app")
POSTGRES_PASSWORD = os.environ.get("POSTGRES_PASSWORD", "ohdsi_app_pass_2026")
TARGET_SCHEMA = "concept_ab_vocab"

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
CSV_DIR = os.path.join(REPO_ROOT, "local-private", "bandeian", "cab_vocab_all_082226")
DDL_FILE = os.path.join(
    REPO_ROOT,
    "local-private",
    "bandeian",
    "CONCEPT_AB_V57_Jeff",
    "CONCEPT_AB_V57_Jeff",
    "Load",
    "cab_vocab_lookups_postgres.sql"
)

TABLES = [
    "cab_vocab_all_visit_hierarchy",
    "cab_vocab_all_procedure",
    "cab_vocab_all_device",
    "cab_vocab_all_chronic_conditions",
    "cab_vocab_all_meas_obs_test",
    "cab_vocab_all_drug_ing_form"
]


def main():
    conn_str = f"host={POSTGRES_HOST} port={POSTGRES_PORT} dbname={POSTGRES_DB} user={POSTGRES_USER} password={POSTGRES_PASSWORD}"
    print(f"Connecting to PostgreSQL at {POSTGRES_HOST}:{POSTGRES_PORT}/{POSTGRES_DB}...")

    with psycopg.connect(conn_str) as conn:
        with conn.cursor() as cur:
            # 1. Create target schema
            print(f"--> Ensuring schema '{TARGET_SCHEMA}' exists...")
            cur.execute(f"CREATE SCHEMA IF NOT EXISTS {TARGET_SCHEMA};")
            conn.commit()

            # 2. Read and apply DDL (Section 0 and Section 1)
            print(f"--> Reading DDL from {DDL_FILE}...")
            with open(DDL_FILE, "r", encoding="utf-8") as f:
                ddl_content = f.read()

            ddl_sql = ddl_content.replace("{schema}", TARGET_SCHEMA)

            # Split DDL into sections
            # Section 0: Drop tables
            # Section 1: Create tables
            # Section 2: Create indexes (run after load)
            # Section 3: Analyze
            sec2_idx = ddl_sql.find("-- SECTION 2")
            sec3_idx = ddl_sql.find("-- SECTION 3")

            ddl_tables = ddl_sql[:sec2_idx]
            ddl_indexes = ddl_sql[sec2_idx:sec3_idx]
            ddl_analyze = ddl_sql[sec3_idx:]

            print("--> Executing Section 0 & 1 (Drop & Create tables)...")
            cur.execute(ddl_tables)
            conn.commit()

            # 3. Stream COPY CSV files
            print("--> Streaming CSV data into tables...")
            for table in TABLES:
                csv_path = os.path.join(CSV_DIR, f"{table}.csv")
                if not os.path.exists(csv_path):
                    print(f"    ERROR: Missing CSV {csv_path}")
                    sys.exit(1)

                size_mb = os.path.getsize(csv_path) / (1024 * 1024)
                print(f"    Loading {table} ({size_mb:.1f} MB)...", end="", flush=True)
                t0 = time.time()

                with open(csv_path, "r", encoding="utf-8", errors="replace") as f:
                    copy_sql = f"COPY {TARGET_SCHEMA}.{table} FROM STDIN WITH (FORMAT csv, HEADER true);"
                    with cur.copy(copy_sql) as copy:
                        while data := f.read(1024 * 1024):  # 1MB buffer
                            copy.write(data)

                conn.commit()
                t1 = time.time()
                cur.execute(f"SELECT COUNT(*) FROM {TARGET_SCHEMA}.{table};")
                row_count = cur.fetchone()[0]
                print(f" done: {row_count:,} rows in {t1 - t0:.1f}s")

            # 4. Create Indexes
            print("--> Executing Section 2 (Creating Indexes)...")
            t0 = time.time()
            cur.execute(ddl_indexes)
            conn.commit()
            print(f"    Indexes created in {time.time() - t0:.1f}s")

            # 5. Analyze
            print("--> Executing Section 3 (ANALYZE)...")
            cur.execute(ddl_analyze)
            conn.commit()

            # 6. Final verification summary
            print("\n=======================================================")
            print(f" CAB Vocabulary Lookup Verification ({TARGET_SCHEMA})")
            print("=======================================================")
            for table in TABLES:
                cur.execute(f"SELECT COUNT(*) FROM {TARGET_SCHEMA}.{table};")
                cnt = cur.fetchone()[0]
                print(f"  {TARGET_SCHEMA}.{table:<35} : {cnt:>10,} rows")
            print("=======================================================\n")


if __name__ == "__main__":
    main()
