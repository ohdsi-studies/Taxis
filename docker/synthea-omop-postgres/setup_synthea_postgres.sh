#!/usr/bin/env bash
# ==============================================================================
# TAXIS: Dockerized Synthea OMOP PostgreSQL Setup & Runner (Bash)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "======================================================================"
echo " TAXIS Dockerized Synthea-OMOP PostgreSQL Setup & Execution"
echo "======================================================================"

echo "--> Step 1: Checking Docker engine..."
docker --version

echo "--> Step 2: Starting PostgreSQL container via docker compose..."
cd "${SCRIPT_DIR}"
docker compose up -d

echo "--> Step 3: Waiting for PostgreSQL healthcheck..."
max_attempts=30
attempt=0
until [ "$(docker inspect --format='{{.State.Health.Status}}' taxis-synthea-postgres 2>/dev/null || true)" == "healthy" ]; do
    attempt=$((attempt + 1))
    if [ "${attempt}" -ge "${max_attempts}" ]; then
        echo "Error: PostgreSQL container failed to become healthy."
        docker logs taxis-synthea-postgres
        exit 1
    fi
    echo "    Waiting for postgres to become healthy (${attempt}/${max_attempts})..."
    sleep 2
done
echo "    PostgreSQL is ready and healthy on localhost:5433."

echo "--> Step 4: Loading Synthetic OMOP CDM data..."
python3 "${SCRIPT_DIR}/load_synthea.py" --host localhost --port 5433 --db synthea --user ohdsi_app --password ohdsi_app_pass_2026

echo "--> Step 5: Executing TAXIS integration test on PostgreSQL..."
python3 "${ROOT_DIR}/extras/test_postgres_synthea_integration.py" --port 5433

echo "======================================================================"
echo " PostgreSQL Synthea-OMOP Setup & Integration Test Complete!"
echo "======================================================================"
