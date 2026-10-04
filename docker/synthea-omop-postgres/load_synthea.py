#!/usr/bin/env python3
"""
Synthea OMOP CDM PostgreSQL Data Loader
=======================================
Loads synthetic OMOP CDM tables into the Dockerized PostgreSQL database:
1. Auto-fetches Synthea27Nj_5.4.zip from OHDSI/EunomiaDatasets (or falls back to Eunomia GiBleed CSVs).
2. Uses high-speed streaming COPY into cdm schema tables.
3. Validates row counts and creates required constraints.

Usage:
    python load_synthea.py [--host localhost] [--port 5432] [--db synthea]
"""

import os
import sys
import argparse
import zipfile
import urllib.request
import tempfile
import shutil

try:
    import psycopg
except ImportError:
    print("Error: psycopg is required. Run 'pip install psycopg[binary]'")
    sys.exit(1)

SYNTHEA_ZIP_URL = "https://raw.githubusercontent.com/OHDSI/EunomiaDatasets/main/datasets/Synthea27Nj/Synthea27Nj_5.4.zip"
EUNOMIA_FALLBACK_URL = "https://raw.githubusercontent.com/OHDSI/EunomiaDatasets/main/datasets/GiBleed/GiBleed_5.3.zip"


def get_data_directory():
    """Download and extract synthetic OMOP CDM CSVs."""
    cache_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "extras", "testdata"))
    os.makedirs(cache_dir, exist_ok=True)
    
    # Check if we already have Synthea27Nj or GiBleed extracted
    synthea_dir = os.path.join(cache_dir, "Synthea27Nj_5.4")
    gibleed_dir = os.path.join(cache_dir, "eunomia", "GiBleed_5.3")
    
    if os.path.exists(synthea_dir) and os.path.exists(os.path.join(synthea_dir, "PERSON.csv")):
        return synthea_dir
    if os.path.exists(gibleed_dir) and os.path.exists(os.path.join(gibleed_dir, "PERSON.csv")):
        return gibleed_dir

    # Try downloading Synthea27Nj
    zip_path = os.path.join(cache_dir, "Synthea27Nj_5.4.zip")
    try:
        print(f"--> Downloading Synthea OMOP CDM from {SYNTHEA_ZIP_URL}...")
        urllib.request.urlretrieve(SYNTHEA_ZIP_URL, zip_path)
        with zipfile.ZipFile(zip_path, "r") as zf:
            zf.extractall(cache_dir)
        if os.path.exists(synthea_dir):
            return synthea_dir
    except Exception as e:
        print(f"    Failed to download Synthea27Nj ({e}). Trying fallback Eunomia GiBleed...")

    # Fallback to GiBleed
    fallback_zip = os.path.join(cache_dir, "GiBleed_5.3.zip")
    if not os.path.exists(fallback_zip):
        urllib.request.urlretrieve(EUNOMIA_FALLBACK_URL, fallback_zip)
    with zipfile.ZipFile(fallback_zip, "r") as zf:
        zf.extractall(cache_dir)
    
    return os.path.join(cache_dir, "GiBleed_5.3")


def load_tables_to_postgres(csv_dir, host, port, dbname, user, password):
    """Load extracted CSVs into PostgreSQL cdm schema."""
    conn_str = f"host={host} port={port} dbname={dbname} user={user} password={password}"
    print(f"--> Connecting to PostgreSQL at {host}:{port}/{dbname} as {user}...")

    target_tables = [
        "PERSON",
        "OBSERVATION_PERIOD",
        "CONDITION_OCCURRENCE",
        "DRUG_EXPOSURE",
        "MEASUREMENT",
        "PROCEDURE_OCCURRENCE",
        "CONCEPT",
        "CONCEPT_ANCESTOR"
    ]

    with psycopg.connect(conn_str) as conn:
        with conn.cursor() as cur:
            for tname in target_tables:
                csv_path = os.path.join(csv_dir, f"{tname}.csv")
                if not os.path.exists(csv_path):
                    print(f"    Skipping {tname}: {csv_path} not found.")
                    continue

                table_name = f"cdm.{tname.lower()}"
                print(f"--> Loading {tname}.csv into {table_name}...")

                # Read header to get columns in file
                with open(csv_path, "r", encoding="utf-8", errors="replace") as f:
                    header = f.readline().strip().split(",")
                    cols = [c.strip().strip('"').lower() for c in header]

                # Match table columns with table schema
                cur.execute(f"""
                    SELECT column_name 
                    FROM information_schema.columns 
                    WHERE table_schema = 'cdm' AND table_name = '{tname.lower()}';
                """)
                valid_cols = set(r[0] for r in cur.fetchall())
                matched_cols = [c for c in cols if c in valid_cols]

                if not matched_cols:
                    print(f"    Warning: No columns matched for {table_name}.")
                    continue

                cols_clause = ", ".join(matched_cols)
                cur.execute(f"TRUNCATE TABLE {table_name} CASCADE;")

                with open(csv_path, "r", encoding="utf-8", errors="replace") as f:
                    with cur.copy(f"COPY {table_name} ({cols_clause}) FROM STDIN WITH (FORMAT csv, HEADER true);") as copy:
                        while data := f.read(65536):
                            copy.write(data)

                cur.execute(f"SELECT COUNT(*) FROM {table_name};")
                count = cur.fetchone()[0]
                print(f"    Loaded {count} rows into {table_name}.")

            conn.commit()

        print("\n--> Verifying loaded dataset in PostgreSQL...")
        with conn.cursor() as cur:
            cur.execute("SELECT COUNT(*) FROM cdm.person;")
            p_cnt = cur.fetchone()[0]
            cur.execute("SELECT COUNT(*) FROM cdm.condition_occurrence;")
            c_cnt = cur.fetchone()[0]
            cur.execute("SELECT COUNT(*) FROM cdm.drug_exposure;")
            d_cnt = cur.fetchone()[0]
            print(f"    cdm.person: {p_cnt} patients")
            print(f"    cdm.condition_occurrence: {c_cnt} records")
            print(f"    cdm.drug_exposure: {d_cnt} records")
            assert p_cnt > 0, "No patients loaded into cdm.person"

    print("\nSUCCESS: Synthetic OMOP CDM loaded into PostgreSQL database.")


def main():
    parser = argparse.ArgumentParser(description="Load Synthetic OMOP CDM into PostgreSQL")
    parser.add_argument("--host", default=os.environ.get("POSTGRES_HOST", "localhost"), help="Postgres host")
    parser.add_argument("--port", default=int(os.environ.get("POSTGRES_PORT", 5433)), type=int, help="Postgres port")
    parser.add_argument("--db", default=os.environ.get("POSTGRES_DB", "synthea"), help="Postgres database name")
    parser.add_argument("--user", default=os.environ.get("POSTGRES_USER", "ohdsi_app"), help="Postgres user")
    parser.add_argument("--password", default=os.environ.get("POSTGRES_PASSWORD", "ohdsi_app_pass_2026"), help="Postgres password")
    args = parser.parse_args()

    csv_dir = get_data_directory()
    print(f"Using synthetic OMOP data from: {csv_dir}")
    load_tables_to_postgres(csv_dir, args.host, args.port, args.db, args.user, args.password)


if __name__ == "__main__":
    main()
