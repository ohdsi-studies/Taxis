# Running the TAXIS Concept AB Mining Pipeline

This guide walks you through running the SQL-based Concept AB Mining Engine (Pipeline v57) on your OMOP Common Data Model (CDM v5.4) database.

---

## Study Leadership and Authorship

All of the SQL algorithms, database schemas, 40-batch partitioning strategies, measurement packing logic, and original analytic code in this pipeline were conceived, designed, and authored by:
- **Stephen H. Bandeian, MD, JD** – Principal Investigator, Johns Hopkins University School of Medicine

Study Leadership:
- **Stephen H. Bandeian, MD, JD** – Principal Investigator, Johns Hopkins University School of Medicine
- **J. Marc Overhage, MD, PhD** – Co-Principal Investigator, The Overhage Group / Indiana University School of Medicine
- **Gowtham Rao, MD, PhD** – Investigator, [CoReason, Inc.](https://www.coreason.ai) USA; OHDSI Phenotype Development & Evaluation Workgroup
- **Shaun Grannis, MD, MS** – Investigator, Regenstrief Institute / Indiana University School of Medicine

---

## Epidemiological Purpose & Pipeline Overview

In observational health research and pharmacoepidemiology, a fundamental objective is characterizing empirical co-occurrence and temporal associations between clinical events across longitudinal patient care.

The Concept AB Mining Engine performs standardized, large-scale association mining across eight OMOP CDM clinical domains (conditions, procedures, devices, drug exposures, measurements, and clinical observations) to estimate bivariate association statistics and temporal precedence for pairs of clinical concepts.

In the production benchmark on the Indiana Network for Patient Care (INPC), the engine analyzed 2,157,525 patients across 11.3 million person-years and 1.88 billion clinical events. It identified 14.2 million observed concept pairs and screened 5.52 million high-support pairs, producing 1.9 million graded clinical knowledge edges.

The analytical pipeline executes entirely within the database engine via parameterized OHDSI SQL. To process massive cohorts while preserving database performance and preventing computational resource exhaustion, the pipeline partitions execution across three sequential phases:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        PIPELINE EXECUTION ARCHITECTURE                 │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   Phase 1: Initialization (concept_ab_init.sql)                        │
│   • Verifies CDM schema integrity and vocabulary mappings              │
│   • Partitions eligible population into 40 balanced hash partitions    │
│   • Instantiates empty cumulative tables in results schema             │
│                                                                        │
│   Phase 2: Iterative Partition Execution (concept_ab_batch.sql)        │
│   • Sequentially executes partitions 1 through N                       │
│   • Deduplicates clinical events at person-day grain                   │
│   • Evaluates temporal sequence and directionality                     │
│   • Materializes partition increments into cumulative tables           │
│                                                                        │
│   Phase 3: Final Consolidation (concept_ab_finalize.sql)               │
│   • Consolidates cumulative counts across all partitions               │
│   • Stratifies by healthcare utilization deciles to adjust for         │
│     surveillance and contact density bias                              │
│   • Calculates crude and stratified lift, odds ratios, and             │
│     continuity-corrected directionality ratios (DR)                    │
│   • Materializes final analytical tables (cab_s55_pair_all, etc.)      │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Concept Entities & Mathematical Formulations

The mining engine evaluates empirical bivariate associations anchored on standardized OMOP clinical entities:
- **Concept A (Anchor / Index Concept)**: The reference clinical entity representing an eligible patient's index diagnosis or exposure.
- **Concept B (Target / Associated Concept)**: The target clinical entity evaluated for co-occurrence and temporal lag relative to Concept A.
- **Concept AB (Longitudinal Concept Pair)**: The pairwise co-occurrence observed within a defined longitudinal window ($W = \pm 30$ or $\pm 365$ days), partitioned across three mutual temporal intervals:
  - **Interval 1 (Same-Day / Contemporaneous, $\Delta t = 0$)**: Evaluates co-documentation on the identical calendar day; segregated from directional calculations.
  - **Interval 2 (Forward Precedence $A \to B$, $+1 \le \Delta t \le +W$)**: Quantifies sequential prospective incidence ($O_{\text{after}} = N_{A \to B}$).
  - **Interval 3 (Reverse Precedence $B \to A$, $-W \le \Delta t \le -1$)**: Quantifies antecedent reverse incidence ($O_{\text{before}} = N_{B \to A}$).

### Core Statistical Estimands
1. **Crude Event Lift**: $\text{Lift}_{\text{obs}} = \frac{O_{AB}}{E_{\text{obs}}}$, where $E_{\text{obs}} = \frac{O_A \cdot O_B \cdot w}{T_{\text{total}}}$ is derived from background Poisson event rates.
2. **Utilization-Stratified Lift**: $\text{Lift}_{\text{strat}} = \frac{O_{AB}}{E_{\text{MH}}}$, where $E_{\text{MH}} = \sum_{k=1}^{10} \frac{O_{A, k} \cdot O_{B, k} \cdot (2W+1)}{T_k}$ sums expected co-occurrences across 10 healthcare contact density deciles to eliminate surveillance confounding.
3. **Wilson-Hilferty Poisson Confidence Intervals**: Exact asymmetrical 95% Poisson confidence limits for event lift computed directly in SQL (`concept_ab_finalize.sql`).
4. **Directionality Metrics**: Directional share $\text{dir\_ab} = \frac{O_{\text{after}}}{O_{\text{after}} + O_{\text{before}}}$ and continuity-corrected Directionality Ratio $DR_{\text{corrected}} = \frac{O_{\text{after}} + 0.5}{O_{\text{before}} + 0.5}$.
5. **Cochran-Mantel-Haenszel Common Odds Ratio**: Stratified contingency cell counts materialized in `cab_s33_strat_all` enabling exact odds ratio computation ($OR_{\text{MH}}$).

For complete derivations, consult the [Concept AB Mining Engine Technical Specification](../CONCEPT_AB_MINING_ENGINE_V57.md) and the [Federated Unified Data Model & Meta-Analysis Specification](../FEDERATED_TAXIS_UNIFIED_DATA_MODEL_AND_META_ANALYSIS.md).

---

## Technical Prerequisites

### 1. Software Environment
- **R (version 4.0 or higher)**: Validated on R 4.6.1.
- **64-bit Java Runtime Environment (JRE 8, 17, or 21)**: Required by `DatabaseConnector` for JDBC execution. Ensure the `JAVA_HOME` environment variable designates the active JRE path.
- **Database-Specific JDBC Driver**: Place the database platform JAR (e.g., `postgresql-42.7.3.jar` for PostgreSQL) in `extras/testdata/jdbc/` or designated system driver directory.
- **Required R Packages**:
  ```r
  install.packages(c("SqlRender", "DatabaseConnector", "ParallelLogger", "jsonlite", "digest", "zip"))
  ```

### 2. Database Permissions and Required Schemas
The executing database user requires:
- **Read access (`SELECT`)** to OMOP CDM tables: `person`, `observation_period`, `visit_occurrence`, `condition_occurrence`, `procedure_occurrence`, `device_exposure`, `drug_exposure`, `measurement`, and `observation`.
- **Read access (`SELECT`)** to OMOP vocabulary tables: `concept`, `concept_ancestor`, and `concept_relationship`.
- **Read access (`SELECT`)** to the **6 pre-loaded project reference tables** in `concept_ab_vocab`:
  1. `cab_vocab_all_visit_hierarchy` (20 rows): Visit hierarchy classification.
  2. `cab_vocab_all_procedure` (151,868 rows): Procedure domain mappings.
  3. `cab_vocab_all_device` (32,517 rows): Device domain classifications.
  4. `cab_vocab_all_chronic_conditions` (29,346 rows): Chronic condition indicators.
  5. `cab_vocab_all_meas_obs_test` (299,934 rows): Laboratory and observation test mappings.
  6. `cab_vocab_all_drug_ing_form` (2,996,686 rows): RxNorm clinical ingredient and dose form mappings.
  *(These comprise 3.51 million pre-indexed rows; load via `Load/cab_vocab_lookups_postgres.sql` or `extras/load_cab_vocab_postgres.py`.)*
- **Full DDL/DML permissions (`CREATE`, `DROP`, `INSERT`, `UPDATE`, `SELECT`)** on the designated **results schema** (e.g., `work_cab_test` or `taxis_results`). The pipeline creates, populates, and indexes tables exclusively within this schema.

---

## Pipeline Execution Modalities

The mining engine supports three standardized execution modalities based on study site requirements:

### Modality 1: Minimal Local Verification Run (Recommended Initial Step)
To validate database connectivity, schema permissions, and driver compatibility prior to full execution:
```bash
Rscript extras/run_cab_pipeline_postgres_minimal.R
```
This executes a single-partition verification run (`batchCount = 1`, `partialRunBatchLimit = 1`) against PostgreSQL with fail-closed error handling, records dynamic SHA-256 SQL file digests, and outputs an auditable run receipt (`extras/pipeline_v57_run_receipt.json`).

Following execution, run the automated verification suite:
```bash
python extras/test_pipeline_v57_postgres_execution.py
```
This suite verifies receipt integrity, validates schema table creation, and evaluates known-answer statistical associations directly against raw CDM fact co-occurrences.

### Modality 2: Standalone Environment-Configured Execution (`concept_ab_run.R`)
For direct command-line execution using environment variables:
1. Copy `concept_ab.env.template` to `concept_ab.env`.
2. Configure database host, port, credentials, and schema specifications.
3. Execute the runner:
   ```bash
   Rscript docs/mining/sql/concept_ab_run.R
   ```
The script establishes connection via `DatabaseConnector`, instantiates the results schema, executes partition iterations, and records execution metrics to `cab_process_log`.

### Modality 3: Federated Network Study Execution (`CodeToRun.R`)
For official OHDSI network study participation, execute the package driver:
```bash
Rscript extras/CodeToRun.R
```
This executes the association mining pipeline and invokes `packageMiningResults()` to generate a privacy-preserving aggregate archive (`Results_Mining_<databaseId>.zip`) with mandatory small-cell suppression ($<5 \to -1$).

Aggregate summaries from participating network sites will be pooled to construct an open-access public dataset of empirical concept-pair associations. This public resource provides the empirical foundation for downstream informatics applications, including computable phenotype development, negative control calibration, and confounding diagnostics.

---

## Semicolon Handling in JDBC Drivers

In SQL Server T-SQL syntax, statement terminators frequently follow comments prior to Common Table Expressions (CTEs). When translated to PostgreSQL via `SqlRender::translate()`, JDBC drivers may throw a `NullPointerException` upon encountering empty statement blocks resulting from split semicolons.

To ensure robust multi-dialect execution while preserving bit-for-bit SHA-256 binary identity across released SQL files, all R execution drivers implement statement-splitter filtering:
```r
statements <- SqlRender::splitSql(sql)
statements <- statements[nchar(trimws(statements)) > 0]
```
This partitions the script into discrete executable statements and strips empty statement tokens, ensuring consistent execution across PostgreSQL, Redshift, and other target database platforms.

---

## Materialized Schema Tables

Upon completion of all three pipeline phases, the results schema contains 43 analytical tables. Key relational outputs include:

### Primary Association Tables
- **`cab_s55_pair_all`**: Master association table. Each record represents a concept pair ($A$ and $B$) with total observed counts (`obs_all`), same-day counts (`obs_same_day`), forward incident counts (`obs_after`), reverse incident counts (`obs_before`), directional share (`dir_ab`), and crude and stratified lift metrics.
- **`cab_s50_all`**: Unpivoted longitudinal counts across prospective risk intervals (30 days, 90 days, 365 days, 730 days, and complete follow-up).
- **`cab_s40_all`**: Contingency matrix counts joined with marginal concept frequencies and expected joint counts.
- **`cab_s30_all`**: Observed pairwise co-occurrence frequencies across clinical domain intersections.
- **`cab_s13_strat_all`**: Healthcare utilization decile denominators (patient counts and person-days per decile).
- **`cab_s23_strat_all`**: Marginal concept frequencies stratified across healthcare utilization deciles.
- **`cab_s33_strat_all`**: Observed concept-pair counts stratified across healthcare utilization deciles.
- **`cab_s33_mh_all`**: Cochran-Mantel-Haenszel expected counts adjusted for healthcare utilization.
- **`cab_vocab_all_output`**: Decoded concept metadata, including standard concept names, domains, vocabularies, and packed measurement parameters.
- **`cab_process_log`**: Detailed execution log recording step durations across all partition runs.

### Longitudinal Profiles and Data Diagnostics
- **`cab_s37_lag_all`**: Empirical distribution of inter-event latency intervals across concept pair categories.
- **`cab_s38_profile_all`**: Domain-specific data profiling metrics.
- **`cab_s39_pattern_all`**: Longitudinal recording gap distributions and event density metrics.
- **`cab_s54_grain_guide`**: Recording granularity classifications per concept (acute episodic vs. chronic maintenance recording).

---

## Data Governance and Patient Privacy

TAXIS is engineered specifically for federated, code-to-data network studies:
- **Federated Local Execution**: All analytical operations execute entirely within the local institutional firewall.
- **Zero Transmission of Person-Level Data**: Individual patient identifiers, clinical dates, and unaggregated co-occurrence matrices remain strictly local.
- **Mandatory Cell Suppression**: All exported summary tables mask cell counts below 5 to -1.
- **Auditable Aggregate Export**: Only approved aggregate summary tables and execution receipts are packaged into `Results_Mining_<databaseId>.zip`. Site investigators may inspect all archive CSVs prior to external transmission.

For comprehensive governance protocols, consult the [TAXIS Network Data Use Term Sheet](../../governance/TAXIS_NETWORK_DATA_USE_TERM_SHEET.md).

For complete governance details, see the [TAXIS Network Data Use Term Sheet](../../governance/TAXIS_NETWORK_DATA_USE_TERM_SHEET.md).
