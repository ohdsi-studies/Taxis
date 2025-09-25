# TAXIS

## Overview
The **CONCEPT_CF_AB** package computes frequent, statistically significant person-level co-occurrences (within ±30 days) among OMOP clinical finding concepts and materializes a final output table, `concept_ab_step_5`. These pairs are subsequently reviewed and categorized by relationship type using a Large Language Model (LLM). The pipeline is portable across OMOP instances: parameterized, SqlRender-compatible SQL is orchestrated in R, keeping control flow outside SQL and enabling translation to supported DBMSs.

At a high level:
- **Reads from**: `condition_occurrence`, `concept`, `concept_relationship`, and `concept_ancestor` tables.
- **Writes to**: A designated results/workspace schema under user control.
- **Uses**: Curated lookup tables (maintained separately, read-only) for roll-ups and mappings.
- **Execution sequence**: 
  1. **Init** prepares working structures.
  2. **Batch loop** computes intermediate counts/measures.
  3. **Finalize** consolidates results into `concept_ab_step_5` and may create indexes.

Security and connectivity follow OHDSI standards. No users, logins, or grants are created. A DBA must provision a least-privilege run account with:
- **SELECT** on required CDM tables and curated lookups.
- **DDL/DML** only in the results schema.

Connections use **DatabaseConnector**. Configurations are defined in a project-local `.Renviron`, including DBMS, connection settings, schemas, and runtime knobs. SQL is rendered and translated with **SqlRender**, then executed via R driver scripts.

## Distribution Contents
- Project-local `.Renviron` file with configuration parameters.
- Concise documentation.
- Two R drivers.
- Three portable SQL programs (SqlRender style, cross-DBMS execution).
- Lookup CSV mapping ~115,000 OMOP clinical finding concepts to ~5,000 ancestor concepts, enabling clinically interpretable roll-ups.

## Environment & Prerequisites
- **OS**: Windows, macOS, or Linux
- **R**: ≥ 4.2
- **Java**: ≥ 8 (17 LTS recommended)
- **JDBC drivers**: directory set via `DATABASECONNECTOR_JAR_FOLDER`
- **R packages**: `SqlRender`, `DatabaseConnector` (others like `Andromeda`, `rJava`, `readr`, `glue` optional)
- **Database**: OMOP CDM with vocabulary and DBA-provisioned run account
  - `SELECT` on `condition_occurrence`, `concept`, `concept_relationship`, `concept_ancestor`
  - `SELECT` on curated lookup tables
  - `DDL/DML` in designated results schema

## Configuration (`.Renviron`)
**Connection fields**:
- `DBMS`, `DB_SERVER`, `DB_PORT`, `DB_USER`, `CAB_AUTH_MODE`, `DB_EXTRA_SETTINGS`, `DATABASECONNECTOR_JAR_FOLDER`

**Schemas**:
- CDM schema
- Lookup schema (curated helper tables)
- Results schema (optional; defaults to lookup schema if omitted)

**Portable SQL programs**:
- `CAB_SQL_DIR`, `CAB_SQL_INIT`, `CAB_SQL_BATCH`, `CAB_SQL_FINALIZE`

**Lookups**:
- `CAB_LOOKUP_TABLES` as comma-separated schema.table entries

**Runtime controls**:
- `CAB_WINDOW_DAYS` (± days for co-occurrence window)
- `CAB_MIN_PERSONS` (row-level stability/privacy)
- `CAB_BATCH_COUNT` (partition count)
- `CAB_PARTIAL_RUN_BATCH_LIMIT` (small values for smoke tests)
- `CAB_CREATE_INDEX_DDL` (toggle index creation)

## Running the Pipeline
1. Edit `.Renviron` with site-specific values and JDBC path.
2. Install R packages if needed; run `concept_cf_ab_precheck.R` to validate environment.
3. Execute `concept_cf_ab_run.R` → renders/translates SQL and runs init → batch loop → finalize.
4. Verify outputs in results schema (e.g., review top rows by `n_persons_ab`).

## Troubleshooting Tips
- Ensure `.Renviron` matches filenames in `CAB_SQL_*` entries.
- JDBC path must exist with compatible driver.
- Use `CAB_PARTIAL_RUN_BATCH_LIMIT` ≤ `CAB_BATCH_COUNT` for tests.
- Load lookup CSV into schema as `concept_ab_cf_rollup`.
- Missing create/drop/index rights → contact DBA.
- All SQL is SqlRender-style; capture rendered SQL for translation issues.

## Security & Connectivity
- Package does **not** modify security.
- DBA-provisioned least-privilege account required.
- Connections use **DatabaseConnector** with `.Renviron` field-based configuration.

## OHDSI References
- [DatabaseConnector docs](https://ohdsi.github.io/DatabaseConnector/)
- [DatabaseConnector vignette](https://ohdsi.github.io/DatabaseConnector/articles/Connecting.html)
- [JDBC drivers helper](https://ohdsi.github.io/DatabaseConnector/reference/downloadJdbcDrivers.html)
- [DatabaseConnector GitHub](https://github.com/OHDSI/DatabaseConnector)
- [SqlRender docs](https://ohdsi.github.io/SqlRender/)
- [Using SqlRender guide](https://ohdsi.github.io/SqlRender/articles/UsingSqlRender.html)
- [SqlRender CRAN README](https://cran.r-project.org/web/packages/SqlRender/readme/README.html)
