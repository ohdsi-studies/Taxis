# TAXIS Concept AB Mining Pipeline: SQL Engine Execution Guide

> **Component**: Concept AB Association Mining Engine (Pipeline v57)  
> **Source Pipeline**: Indiana Network for Patient Care (INPC) 2.16M Patient Run  
> **Study Leadership**:  
> • Stephen H. Bandeian, MD, JD – Principal Investigator, Johns Hopkins University School of Medicine (Original SQL & Analytic Code Author)  
> • J. Marc Overhage, MD, PhD – Co-Principal Investigator, The Overhage Group / Indiana University School of Medicine  
> • Gowtham Rao, MD, PhD – Investigator, CoReason, Inc. USA; OHDSI (Phenotype working group)  
> • Shaun Grannis, MD, MS – Investigator, Regenstrief Institute / Indiana University School of Medicine  
>  
> **Original Scientific & Analytic Authorship**:  
> All SQL scripts (`concept_ab_init.sql`, `concept_ab_batch.sql`, `concept_ab_finalize.sql`), database architectures, 40-batch partitioning strategies, measurement packing schemes, and original analytic algorithms in the Concept AB Mining Engine were conceived, designed, and authored by **Stephen H. Bandeian, MD, JD** (Principal Investigator, Johns Hopkins University School of Medicine).  
> **Governing Framework**: OHDSI HADES (`DatabaseConnector`, `SqlRender`)  
> **Licensing**: Apache 2.0 Open Source  

---

## 1. Overview & Architecture

The **Concept AB Mining Engine** computes population-level and encounter-level association statistics across pairs of standardized OMOP concepts across **8 clinical domains and 24 cross-domain pair permutations**:
- Core Domains: `Condition` (10), `Procedure` (20), `Device` (30), `Drug` (40), `Obs Test` (50), `Obs Result` (51), `Meas Test` (60), `Meas Result` (61).
- **Production INPC Benchmark Scale**: Evaluated across **2,157,525 patients** spanning **11,299,055 person-years** and **1.88 billion fact events**, observing **14,233,528 concept pairs** backed by **36.1 billion event-pairs** and **4.01 billion person-pairs**.
- Complete empirical tables (Tables 1–7) and SQL concordance audit: see [`../CONCEPT_AB_MINING_ENGINE_V57.md`](../CONCEPT_AB_MINING_ENGINE_V57.md#5-empirical-benchmark-indiana-network-for-patient-care-inpc-216m-patient-run).

The pipeline executes entirely inside the partner's database engine via **OHDSI SqlRender** parameterized scripts driven by an R runner script (`concept_ab_run.R`):

```text
┌────────────────────────────────────────────────────────────────────────┐
│                      R DRIVER: concept_ab_run.R                        │
│   • Loads environment variables from concept_ab.env                    │
│   • Connects via DatabaseConnector (least-privilege credentials)       │
│   • Orchestrates batching loops, error recovery, and status checks     │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                   SQL WORKFLOW (SqlRender Compatible)                  │
│                                                                        │
│   1. concept_ab_init.sql                                               │
│      - Verifies CDM v5.4 tables and vocabulary crosswalks              │
│      - Randomly partitions eligible person population into N batches   │
│      - Materializes cumulative scaffolding tables in results schema    │
│                                                                        │
│   2. concept_ab_batch.sql (Iterative Loop Across Batches 1..N)        │
│      - Extracts and deduplicates patient-level domain events           │
│      - Computes person-level and event-level co-occurrences            │
│      - Evaluates temporal precedence and asymmetric hazard windows     │
│      - Appends batch counts to shared cumulative tables                │
│                                                                        │
│   3. concept_ab_finalize.sql                                           │
│      - Rolls up cumulative batch tables into global master tables      │
│      - Applies healthcare utilization decile stratification (DEC-GR-010)│
│      - Computes Unadjusted Person Lift, Stratified Lift, Event Lift,   │
│        Odds Ratios, and Directionality Ratios (DR)                     │
│      - Materializes final export tables (cab_s55_pair_all, etc.)        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Prerequisites & Setup

### Software Requirements
1. **R (version $\ge$ 4.0.0)** (tested on R 4.6.1).
2. **Java Runtime Environment (JRE $\ge$ 8, 17, or 21, 64-bit)** for DatabaseConnector JDBC connectivity (e.g. OpenJDK 21). Ensure `JAVA_HOME` is set.
3. **Target Database JDBC Driver** (e.g., PostgreSQL JDBC `postgresql-42.7.3.jar` placed in `extras/testdata/jdbc` or site driver folder).
4. **Required R Packages**:
   ```r
   install.packages(c("SqlRender", "DatabaseConnector", "ParallelLogger", "jsonlite", "getPass"))
   ```

### Database Permissions
The executing database user requires:
- `SELECT` permission on the OMOP CDM schema (`person`, `observation_period`, `visit_occurrence`, `condition_occurrence`, `procedure_occurrence`, `device_exposure`, `drug_exposure`, `measurement`, `observation`).
- `SELECT` permission on the OMOP vocabulary schema (`concept`, `concept_ancestor`, `concept_relationship`).
- `SELECT` permission on the project lookup schema (`PROJECT_REFERENCE_SCHEMA`, e.g. `concept_ab_vocab`) containing the **6 pre-loaded reference tables**:
  1. `cab_vocab_all_visit_hierarchy` (20 rows) — visit level hierarchy
  2. `cab_vocab_all_procedure` (151,868 rows) — procedure concept classification
  3. `cab_vocab_all_device` (32,517 rows) — device concept classification
  4. `cab_vocab_all_chronic_conditions` (29,346 rows) — chronic condition definitions
  5. `cab_vocab_all_meas_obs_test` (299,934 rows) — measurement and observation test classification
  6. `cab_vocab_all_drug_ing_form` (2,996,686 rows) — ingredient and clinical drug form mappings
  *(Total: 3,510,371 rows; loaded via `Load/cab_vocab_lookups_postgres.sql` and `extras/load_cab_vocab_postgres.py`)*.
- `CREATE`, `DROP`, `INSERT`, `UPDATE`, `SELECT` permissions on the designated **results schema** (the pipeline creates, drops, and populates tables *only* in this schema).

---

## 3. Configuration via `concept_ab.env`

1. Copy the provided template to `concept_ab.env`:
   ```bash
   cp concept_ab.env.template concept_ab.env
   ```
2. Edit `concept_ab.env` to set your site-specific database host, port, credentials, and schema names.

### Key Parameter Descriptions:
| Setting | Recommended Value | Purpose |
|---|---|---|
| `DBMS` | `postgresql`, `redshift`, `sql server`, `snowflake` | Drives `DatabaseConnector` connection and `SqlRender` translation. |
| `DB_SERVER` | `<host>/<database>` | Database host and database name. |
| `CDM_SCHEMA` | e.g. `cdm` | Read-only OMOP CDM schema. |
| `PROJECT_REFERENCE_SCHEMA` | e.g. `concept_ab_vocab` | Read-only schema holding the 6 vocabulary lookup tables. |
| `OMOP_REFERENCE_SCHEMA` | e.g. `cdm` | Read-only OMOP vocabulary schema. |
| `RESULTS_SCHEMA` | e.g. `work_cab_test` or `taxis_results` | Read/write schema where all output tables are built. |
| `CAB_BATCH_COUNT` | `40` (default; `1` for minimal test) | Partitions the patient cohort to optimize disk and memory utilization. |
| `CAB_PARTIAL_RUN_BATCH_LIMIT` | `40` (or `1` for test) | Number of batches to process. Set to 1 for a fast end-to-end dry-run. |
| `CAB_CREATE_INDEX_DDL` | `true` (default; set `false` for Snowflake/BigQuery) | Controls generation of `CREATE INDEX` and `UPDATE STATISTICS` DDL. Columnar platforms must disable this. |

> **Statement-Splitter & Empty-Statement Filter Protocol (`REC-063-1`)**: In the released T-SQL batch script (`concept_ab_batch.sql`), standalone semicolons follow comments preceding CTEs to satisfy SQL Server syntax requirements. When transpiled via `SqlRender::translate()` for PostgreSQL, standard JDBC drivers crash with a NullPointerException if empty statements are executed. All execution runners implement the statement-splitter protocol: `statements <- splitSql(sql); statements <- statements[nchar(trimws(statements)) > 0]`, ensuring seamless execution while preserving 100% SHA256 binary identity of all released SQL files.

---

## 4. Execution Options

### Option A: Bounded Minimal PostgreSQL Execution Runner (Recommended for Verification)
Executes a bounded, partition-isolated run (`batch_count=1`, `partial_run_batch_limit=1`) against PostgreSQL with fail-closed error handling and generates an audit receipt:
```bash
Rscript extras/run_cab_pipeline_postgres_minimal.R
```
Upon completion, verify the execution with the automated known-answer test harness:
```bash
python extras/test_pipeline_v57_postgres_execution.py
```
This suite verifies:
- Audit of `extras/pipeline_v57_run_receipt.json` (asserts `"status": "SUCCESS"`).
- Presence and population of all 43 materialized output tables.
- 3 independent known-answer test vectors in `cab_s55_pair_all` (Acute bronchitis $\leftrightarrow$ acetaminophen, Otitis media $\leftrightarrow$ acetaminophen, Suture open wound $\leftrightarrow$ acetaminophen).
- Synthetic fixture boundaries (noting 0 device exposures in synthetic GiBleed CDM as an explicit fixture limit).

### Option B: Standalone SQL Runner (`concept_ab_run.R`)
Executes the full pipeline via environment-driven configuration:
```bash
Rscript docs/mining/sql/concept_ab_run.R
```
The runner loads `concept_ab.env`, establishes a JDBC connection, and orchestrates:
1. **Scaffolding (`init`)**: Verifies table dependencies, assigns patients to random batches, and creates cumulative summary tables.
2. **Batch Processing Loop (`batch`)**: Loops across batches $1 \dots N$, logging step execution times to `cab_process_log`.
3. **Statistical Finalization (`finalize`)**: Aggregates batch counts, applies utilization stratification, computes lifts and directionality ratios, and outputs final analytical tables.

### Option C: Study Package Network Execution Driver (`CodeToRun.R`)
For federated OHDSI network studies, sites execute the packaged R study module:
```bash
Rscript extras/CodeToRun.R
```
This invokes `Taxis::execute()`, running both mining (`runMining = TRUE`) and non-PHI aggregate packaging with small-cell suppression ($<5 \to -1$, `packageResults = TRUE`).

---

## 5. Output Tables Summary (43 Materialized Tables)

Upon completion of the 3 phases, the results schema contains 43 materialized tables:

### Master Association & Longitudinal Tables
| Table Name | Description | Key Analytical Fields |
|---|---|---|
| **`cab_s55_pair_all`** | Master association summary table per concept pair | `concept_id_a`, `concept_id_b`, `concept_name_a`, `concept_name_b`, `obs_all`, `obs_same_day`, `obs_after`, `obs_before`, `dir_ab`, `lift_to_read`, `lift_same_day`, `lift_after`, `lift_before` |
| **`cab_s50_all`** | Unpivoted longitudinal interval counts | Temporal counts across follow-up windows: $[1, 30]$, $[1, 90]$, $[1, 365]$, $[1, 730]$ days, and all follow-up |
| **`cab_s40_all`** | Contingency counts joined with marginals | Observed counts, expected counts, marginal totals |
| **`cab_s30_all`** | Raw observed co-occurrence counts | Pair counts across all domain intersections |
| **`cab_s13_strat_all`** | Utilization decile denominators | Person counts and person-days per utilization decile ($U_1 \dots U_{10}$) |
| **`cab_s23_strat_all`** | Concept marginals by decile | Person and event marginals stratified across utilization deciles |
| **`cab_s33_strat_all`** | Stratified observed pair counts | Observed pair co-occurrences within each contact decile |
| **`cab_s33_mh_all`** | Stratified expected counts | Cochran-Mantel-Haenszel expected counts adjusted for contact frequency |
| **`cab_vocab_all_output`** | Decoded concept metadata | Human-readable concept names, domains, vocabularies, and packed measurement results |
| **`cab_process_log`** | Step-by-step performance metrics | Execution durations per step and batch for auditability |
| **`cab_timing_all`** | Step-by-step summary timings | Aggregated execution metrics |

### Profile & Diagnostic Tables
- `cab_s37_lag_all`: Distribution of longitudinal lag days across pair types.
- `cab_s38_profile_all`: Data profiling summaries across clinical domains.
- `cab_s39_pattern_all`: Concept recording gap patterns and event densities.
- `cab_s54_grain_guide`: Longitudinal recording granularity guide per concept.
- Staging tables: Domain-specific staging (`cab_s10_10`, `cab_s10_20`, `cab_s10_30`, `cab_s10_40`, `cab_s10_50`, `cab_s10_60`, `cab_s10_80`) and cumulative batch tables (`cab_s20_marginal_cum`, `cab_s30_cum`, `cab_s40_cum`, `cab_s50_cum`).

---

## 6. Data Governance & Non-PHI Compliance

In accordance with the **TAXIS Network Data Use Term Sheet** ([`docs/governance/TAXIS_NETWORK_DATA_USE_TERM_SHEET.md`](../../governance/TAXIS_NETWORK_DATA_USE_TERM_SHEET.md)):
- The mining pipeline executes **100% locally** behind institutional firewalls.
- No patient-level records, person IDs, or encounter dates leave the local database.
- Raw concept-pair co-occurrence matrices remain stored strictly in the local `RESULTS_SCHEMA` and are not shared across institutions without separate, formal data use agreements.

---

## 7. Pipeline Verification Suite

To verify template integrity, token balance, and mathematical consistency prior to production execution:
```bash
python extras/verify_mining_engine_and_sql.py
```

The verification suite automatically audits:
1. **Asset Sanitization**: Ensures zero local system paths, IP addresses, database hostnames, or credentials exist.
2. **SqlRender Parameterization**: Checks presence and balance of all required schema and configuration tokens (`@source_cdm_schema`, `@results_database_schema`, `@batch_count`, etc.).
3. **Directionality Ratio (DR) Continuity Correction**: Validates mathematical boundaries ($DR = \frac{N_{A \to B} + 0.5}{N_{B \to A} + 0.5}$) and reciprocal symmetry.
4. **Utilization Stratification Math**: Validates expected count calculations across 10 contact deciles ($E_{AB} = \sum_k \frac{N_{A,k} N_{B,k}}{N_k}$).
5. **Measurement Key Packing**: Confirms bijective 64-bit integer encoding/decoding (`test_concept_id * 1e9 + result_code`).
6. **Data Dictionary Coverage**: Confirms schema definitions for all 16 analytical and profiling tables.

