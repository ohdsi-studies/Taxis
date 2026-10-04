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

The **Concept AB Mining Engine** computes population-level and encounter-level association statistics across pairs of standardized OMOP concepts across 6 domain pairs:
- `Condition - Drug`
- `Condition - Measurement`
- `Condition - Procedure`
- `Condition - Condition`
- `Drug - Procedure`
- `Drug - Drug`

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
1. **R (version $\ge$ 4.0.0)**.
2. **Java Runtime Environment (JRE $\ge$ 8 or 17, 64-bit)** for DatabaseConnector JDBC connectivity.
3. **Target Database JDBC Driver** (e.g., PostgreSQL, Redshift, Snowflake, SQL Server JARs placed in a local folder).
4. **Required R Packages**:
   ```r
   install.packages(c("SqlRender", "DatabaseConnector", "getPass"))
   ```

### Database Permissions
The executing database user requires:
- `SELECT` permission on the OMOP CDM schema (`person`, `observation_period`, `visit_occurrence`, `condition_occurrence`, `procedure_occurrence`, `device_exposure`, `drug_exposure`, `measurement`, `observation`).
- `SELECT` permission on the OMOP vocabulary schema (`concept`, `concept_ancestor`, `concept_relationship`).
- `SELECT` permission on the project lookup schema containing the 6 pre-loaded reference tables (`cab_vocab_all_*`).
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
| `PROJECT_REFERENCE_SCHEMA` | e.g. `taxis_lookups` | Read-only schema holding the 6 vocabulary lookup tables. |
| `OMOP_REFERENCE_SCHEMA` | e.g. `vocabulary` | Read-only OMOP vocabulary schema. |
| `RESULTS_SCHEMA` | e.g. `taxis_results` | Read/write schema where all output tables are built. |
| `CAB_BATCH_COUNT` | `40` (default) | Partitions the patient cohort to optimize disk and memory utilization. |
| `CAB_PARTIAL_RUN_BATCH_LIMIT` | `40` (or `1` for test) | Number of batches to process. Set to 1 for a fast end-to-end dry-run. |
| `CAB_CREATE_INDEX_DDL` | `true` (default; set `false` for Snowflake/BigQuery) | Controls generation of `CREATE INDEX` and `UPDATE STATISTICS` DDL. Columnar platforms must disable this. |

> **Portability & Dialect Status Note**: The SQL pipeline templates have undergone static syntax audits to eliminate platform-specific functions (replacing non-standard `GREATEST()` with portable `CASE WHEN` and PostgreSQL-specific default timestamps with standard ANSI `CURRENT_TIMESTAMP`) and enclose all index/statistics DDL inside `{@create_index_ddl}` guards. Live multi-dialect translation and execution across target DBMS engines remain subject to partner-site validation in live HADES environments.

---

## 4. Execution

To run the complete pipeline:
```bash
Rscript concept_ab_run.R
```

The runner automatically executes:
1. **Scaffolding (`init`)**: Verifies table dependencies, assigns patients to random batches, and creates cumulative summary tables.
2. **Batch Processing Loop (`batch`)**: Loops across batches $1 \dots N$, logging step execution times to `cab_process_log`.
3. **Statistical Finalization (`finalize`)**: Aggregates batch counts, applies utilization stratification, computes lifts and directionality ratios, and outputs final analytical tables.

---

## 5. Output Tables Summary

Upon completion, the results schema contains the following finalized tables:

| Table Name | Description | Key Analytical Fields |
|---|---|---|
| **`cab_s55_pair_all`** | Master association summary table per concept pair | `concept_id_a`, `concept_id_b`, `person_lift_unadj`, `person_lift_strat`, `event_lift`, `directionality_ratio`, `contingency_or`, `a_before_b`, `b_before_a`, `same_day_count` |
| **`cab_s50_all`** | Unpivoted longitudinal interval counts | Temporal counts across windows: $[1, 30]$, $[1, 90]$, $[1, 365]$, $[1, 730]$ days, and all follow-up |
| **`cab_s40_all`** | Contingency counts joined with marginals | Observed counts, expected counts, marginal totals |
| **`cab_s30_all`** | Raw observed co-occurrence counts | Pair counts across all 6 domain intersections |
| **`cab_s13_strat_all`** | Utilization decile denominators | Person counts and person-days per utilization decile ($U_1 \dots U_{10}$) |
| **`cab_s33_mh_all`** | Stratified expected counts | Cochran-Mantel-Haenszel expected counts adjusted for encounter frequency |
| **`cab_vocab_all_output`** | Decoded concept metadata | Human-readable concept names, domains, vocabularies, and packed measurement results |
| **`cab_timing_all`** | Step-by-step performance metrics | Execution durations per step and batch for auditability |

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

