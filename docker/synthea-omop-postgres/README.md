# TAXIS Dockerized Synthea-OMOP PostgreSQL Environment

This directory provides a turn-key, containerized **PostgreSQL OMOP CDM v5.4** database pre-configured for TAXIS synthetic integration testing and cross-database validation.

---

## Architecture Overview

```
docker/synthea-omop-postgres/
├── docker-compose.yml          # Postgres 16 container definition with healthchecks
├── init_scripts/
│   └── 01_omop_cdm_ddl.sql     # Automated DDL: cdm, cohort, work schemas + indices
├── load_synthea.py             # High-speed data loader streaming official OHDSI Synthea tables
├── setup_synthea_postgres.ps1  # Automated turn-key setup for Windows PowerShell
├── setup_synthea_postgres.sh   # Automated turn-key setup for Linux / macOS
└── README.md                   # This specification
```

---

## Connection Specifications

| Parameter | Default Value | Notes |
|---|---|---|
| **Host** | `localhost` | Exposed on host machine |
| **Port** | `5432` | Standard PostgreSQL port |
| **Database** | `synthea` | Initialized OMOP database |
| **Username** | `ohdsi_app` | Dedicated application user |
| **Password** | `ohdsi_app_pass_2026` | Default non-production testing secret |
| **CDM Schema** | `cdm` | Contains standard OMOP tables (`person`, `condition_occurrence`, etc.) |
| **Cohort Schema**| `cohort` | Target schema for `CohortGenerator` tables |
| **Work Schema** | `work` | Scratch schema for intermediate TAXIS mining pairs |

---

## Quickstart Execution

### Option 1: Automated Turn-Key Run (PowerShell)
```powershell
.\docker\synthea-omop-postgres\setup_synthea_postgres.ps1
```

### Option 2: Automated Turn-Key Run (Bash)
```bash
./docker/synthea-omop-postgres/setup_synthea_postgres.sh
```

### Option 3: Manual Step-by-Step
1. **Start the database container**:
   ```bash
   cd docker/synthea-omop-postgres
   docker compose up -d
   ```
2. **Populate synthetic OMOP tables**:
   ```bash
   python load_synthea.py --host localhost --port 5432 --db synthea
   ```
3. **Execute integration suite**:
   ```bash
   python ../../extras/test_postgres_synthea_integration.py
   ```
4. **Shutdown container**:
   ```bash
   docker compose down -v
   ```

---

## Data Governance & Privacy Safeguards
- **100% Synthetic Data**: Uses the official public OHDSI Synthea / Eunomia synthetic datasets. Zero patient-level Protected Health Information (PHI) or real clinical identifiers.
- **Fail-Closed Suppression**: Applies mandatory privacy floor normalization ($\min < 5 \to 5$) and small-cell masking across all evaluated cohorts and derived ratios.
