# TaxisPhenotypeEvaluation: OHDSI Network Study Package

[![Build Status](https://github.com/ohdsi-studies/Taxis/workflows/R-CMD-check/badge.svg)](https://github.com/ohdsi-studies/Taxis/actions?query=workflow%3AR-CMD-check)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

> **Study Type**: Multi-Center Phenotype Evaluation & Comparative Benchmark  
> **Collaborator Showcase**: 2026 OHDSI Global Symposium (Entry #127, October 20–22, 2026, New Brunswick, NJ)  
> **Study Leadership**:  
> • Stephen H. Bandeian, MD, JD – Principal Investigator, Johns Hopkins University School of Medicine  
> • J. Marc Overhage, MD, PhD – Co-Principal Investigator, The Overhage Group / Indiana University School of Medicine  
> • Gowtham Rao, MD, PhD – Investigator, CoReason, Inc. USA; OHDSI (Phenotype working group)  
> • Shaun Grannis, MD, MS – Investigator, Regenstrief Institute / Indiana University School of Medicine  
> **Governing Framework**: OHDSI HADES (`DatabaseConnector`, `CohortGenerator`, `CohortDiagnostics`, `PheValuator`)  
> **Target Data Assets**: Federated OMOP Common Data Model (CDM) partner databases  

---

## 1. Study Rationale & Executive Summary

The **TAXIS** (Transparent Analytic Knowledge Graph for Interoperable Science) project has developed an automated methodology to synthesize clinical phenotypes directly from empirical association rules and clinical knowledge graphs.

To evaluate these knowledge graph–generated phenotypes prior to broader community dissemination at the **2026 OHDSI Global Symposium**, their diagnostic performance and patient overlap are benchmarked against peer-reviewed **OHDSI Phenotype Library** comparator definitions across diverse observational databases.

This HADES-compliant study package evaluates candidate phenotypes for five conditions across partner OMOP CDM databases, generating:
1. Standard cohort entry counts and person counts.
2. Pairwise patient-level overlap and Jaccard similarity indices.
3. Standard `CohortDiagnostics` characterizations (index event breakdowns, incidence rates, demographics, and visit context).
4. `PheValuator` diagnostic performance estimates (Sensitivity, Specificity, Positive Predictive Value, Negative Predictive Value, and F1 Score with 95% Confidence Intervals).

All analyses are executed locally within partner environments. No patient-level data leaves the host institution.

### Governance & Methodological Decisions
- **v2 Initial Presentation Baseline (DEC-GR-007)**: Cohort logic enforces `PrimaryCriteriaLimit: First` (earliest diagnosis) for the initial public release, capturing initial incident presentation.
- **Configurable Rule-Out Mimic Cap (DEC-GR-008)**: Differential mimic exclusions are subject to a configurable default cap of 10% anchor patient cost ($\frac{|A \cap \text{Mimic}|}{|A|} < 0.10$).
- **Dual Lift Reporting (DEC-GR-010)**: Methodology reports both unadjusted person lift alongside utilization-stratified lift to distinguish clinical association from contact frequency.

---

## 2. Evaluated Phenotype Pairs (TAXIS vs. OHDSI Phenotype Library)

This package evaluates **5 paired clinical phenotypes** (10 cohorts total). Each pair contrasts a TAXIS Knowledge Graph–generated cohort against its corresponding OHDSI Phenotype Library comparator:

| # | Clinical Phenotype | Anchor Concept ID | TAXIS KG Cohort ID | OHDSI Phenotype Library Comparator ID | Circe JSON Definition | SqlRender SQL Script |
|---|---|---|---|---|---|---|
| **1** | **Chronic Obstructive Pulmonary Disease (COPD)** | `255573` | `1798322` | `1263` (`OHDSI_COPD_1263`) | [`inst/cohorts/1798322.json`](./inst/cohorts/1798322.json) | [`inst/sql/sql_server/1798322.sql`](./inst/sql/sql_server/1798322.sql) |
| **2** | **Obesity** | `433736` | `1798323` | `1179` (`OHDSI_Obesity_1179`) | [`inst/cohorts/1798323.json`](./inst/cohorts/1798323.json) | [`inst/sql/sql_server/1798323.sql`](./inst/sql/sql_server/1798323.sql) |
| **3** | **Chronic Kidney Disease (CKD)** | `46271022` | `1798324` | `1191` (`OHDSI_CKD_1191`) | [`inst/cohorts/1798324.json`](./inst/cohorts/1798324.json) | [`inst/sql/sql_server/1798324.sql`](./inst/sql/sql_server/1798324.sql) |
| **4** | **Hyperkalemia** | `434610` | `1798325` | `940` (`OHDSI_Hyperkalemia_940`) | [`inst/cohorts/1798325.json`](./inst/cohorts/1798325.json) | [`inst/sql/sql_server/1798325.sql`](./inst/sql/sql_server/1798325.sql) |
| **5** | **Type 2 Diabetes Mellitus (T2DM)** | `201826` | `1798326` | `1032` (`OHDSI_T2DM_1032`) | [`inst/cohorts/1798326.json`](./inst/cohorts/1798326.json) | [`inst/sql/sql_server/1798326.sql`](./inst/sql/sql_server/1798326.sql) |

---

## 3. Package Execution & Verification Matrix

In accordance with study quality standards (addressing REC-003-3, REC-021-3, and REC-024-3), the table below records the execution and verification status of each workflow component across development environments and target partner platforms:

| Workflow Stage | Execution Status | Test Environment / Evidence Base | Key Outcome & Operational Result |
|---|---|---|---|
| **Package Installation** | **PASSED** | R 4.2.0+ / HADES Dependencies | Package builds cleanly via `devtools::install_local()` and `remotes::install_github()`. |
| **Cohort Generation** | **PASSED** | Eunomia (SQLite) & INPC (2.16M patients) | All 10 cohorts instantiated successfully via `CohortGenerator::generateCohortSet()`. |
| **Cohort Overlap & Jaccard** | **PASSED** | Eunomia (SQLite) & INPC (2.16M patients) | Pairwise distinct person intersection, union, and Jaccard metrics computed cleanly. Denominators: $|A \cup B|$. |
| **CohortDiagnostics** | **PASSED** | Eunomia (SQLite) & INPC (2.16M patients) | `CohortDiagnostics::executeDiagnostics()` completed across characterization, incidence, and index event breakdowns. |
| **PheValuator Modeling** | **PASSED** | INPC OMOP CDM (Real-world extraction) | Evaluated phenotype algorithm diagnostic operating characteristics (Sensitivity, Specificity, PPV, NPV, F1 Score) against probabilistic evaluation cohorts generated from PLP regularized logistic regression models. *(Skipped on Eunomia due to synthetic data class-separation limits)*. |
| **Small-Cell Suppression & Boundary Contract** | **PASSED (Python Simulation)** | Algorithmic Contract Harness (`verify_suppression_and_packaging.py`) | **Algorithmic Simulation Receipt**: Verified boundary counts: 0 preserved as true absence; 1 and 4 masked to -1; 5 preserved unmasked. Complementary cell suppression masks all 4 partition counts ($A \cap B, A \setminus B, B \setminus A, A \cup B$) and all derived ratios whenever any cell is small ($<5$). Evaluated adversarial counterexample ($A=100, B=100, A \cap B=3, A \cup B=197, A \setminus B=97, B \setminus A=97$): all partition cells and ratios masked to -1; unmasked marginals ($A=100, B=100$) yield an underdetermined 2-equation/3-unknown system, proving mathematical impossibility of algebraic reconstruction. |
| **Allowlist Export Packaging & Schema Audit** | **PASSED (Python Simulation)** | Packaging Contract Harness (`verify_suppression_and_packaging.py`) | **Packaging Simulation Receipt**: Packaging strictly enforces exact relative paths (`cohort_counts_<db>.csv`, `cohort_overlap_summary_<db>.csv`, `phevaluator_summary_<db>.csv`, `diagnostics/Results_<db>.zip`). Deep inspection of nested `diagnostics/Results_<db>.zip` verifies only approved aggregate CSVs; excludes execution logs (`.log`/`.txt`), scratch files, decoy archives (`Results_OTHER_DB.zip`), patient tables, and forbidden columns (`person_id`, `subject_id`). |
| **Local R Runtime Package Execution** | **NOT RUN LOCALLY** | Local Workspace Environment (No `Rscript` installed) | Local development machine lacks native R runtime. Live R execution verified during historical INPC package runs; prospective network execution pending partner deployment. |
| **Prospective Network CDMs** | **PREPARED / PENDING** | External Partner CDMs (Claims, EHR) | Package finalized and published for federated network execution in Wave 4. |

---

## 4. Data Governance, Privacy & Security Compliance

This package operates in strict accordance with the **TAXIS Network Data Use Term Sheet** ([`docs/governance/TAXIS_NETWORK_DATA_USE_TERM_SHEET.md`](../../docs/governance/TAXIS_NETWORK_DATA_USE_TERM_SHEET.md)).

### Core Governance Safeguards:
1. **Zero Concept Pair Matrix Extraction**: The package does **not** query or export underlying concept-concept association matrices or granular co-occurrence tables.
2. **Zero Protected Health Information (PHI) / Patient-Level Data**: No individual patient records, person identifiers, encounter timestamps, or narrative texts leave the local site firewall.
3. **Mandatory Small-Cell Suppression**: All patient counts below 5 (`minCellCount = 5`) are automatically masked (`-1`) in exported CSVs. Participating sites may raise this threshold if required by local governance policies.
4. **Complementary Suppression for Derived Ratios & Partitions**: Whenever an underlying count (e.g., intersection or exclusive cell) is suppressed, all partition counts and derived ratio metrics (Jaccard index, sensitivity proxy, positive agreement) are masked to `-1` to eliminate linear algebraic back-calculation of protected counts.
5. **Comprehensive PheValuator Small-Cell & Bound Suppression (REC-048-1)**: In `phevaluator_summary_<databaseId>.csv`, if any 2x2 contingency cell (true positives, false positives, true negatives, false negatives) is small ($1 \le N < 5$) or negative (upstream PheValuator suppression marker), all 4 counts, point estimates (Sensitivity, Specificity, PPV, NPV, F1 Score), all 8 confidence interval bounds, and estimated prevalence are masked to `-1`.
6. **Error Hygiene & Outbound Data Sanitization (REC-048-2)**: Outbound summaries export strictly bounded status codes (`COMPLETED`, `NO_EVALUATION_SUBJECTS`, `EXECUTION_FAILED`, `PACKAGE_NOT_INSTALLED`). Diagnostic error text (`e$message`) is redirected exclusively to private site-local logs (`log_<databaseId>.txt`), preventing accidental disclosure of SQL queries, table names, file paths, or DBMS credentials.
7. **Provisional Cohort Role Specifications (REC-048-3)**: `PhenotypePairs.csv` explicitly defines `xSpecCohortId`, `xSensCohortId`, and `prevalenceCohortId`. For Phase 1 exploratory evaluation, reference library cohorts serve as provisional placeholders pending dedicated clinician-adjudicated `xSpec` and `xSens` definitions per Swerdel et al. (2019). Results are explicitly labeled as provisional specifications rather than validated diagnostic accuracy.
8. **Strict Allowlist Zip Packaging**: The export function enforces a strict allowlist. Only the following aggregate files are included in `Results_<databaseId>.zip`:
   - `cohort_counts_<databaseId>.csv`
   - `cohort_overlap_summary_<databaseId>.csv`
   - `phevaluator_summary_<databaseId>.csv`
   - `diagnostics/Results_<databaseId>.zip` (verified CSV-only aggregate members; logs, scratch tables, and decoys rejected)
9. **Mandatory Institutional Review**: Participating sites maintain full discretion to inspect the contents of `Results_<databaseId>.zip` before transferring it to the study coordinating team.

---

## 5. Package Architecture & Contents

```text
extras/TaxisPhenotypeEvaluation/
├── DESCRIPTION                             # R package metadata, authors, and HADES dependencies
├── NAMESPACE                               # Exported study functions (execute, createCohorts, etc.)
├── README.md                               # This package documentation file
├── .Rbuildignore                           # Standard R build exclusion rules
├── R/
│   ├── Main.R                             # Master execution function execute()
│   ├── CreateCohorts.R                     # Instantiates 10 cohorts using CohortGenerator
│   ├── CohortOverlap.R                     # Calculates pairwise Jaccard index with disclosure protection
│   ├── RunDiagnostics.R                    # Runs CohortDiagnostics characterization
│   ├── RunPheValuator.R                    # Generates PheValuator analysis specifications and evaluates diagnostic performance
│   └── PackageResults.R                    # Bundles allowlisted non-PHI results into Results_<db>.zip
├── inst/
│   ├── cohorts/                            # 10 Circe JSON cohort definitions
│   │   ├── 1798322.json                    # TAXIS COPD
│   │   ├── 1798323.json                    # TAXIS Obesity
│   │   ├── 1798324.json                    # TAXIS CKD
│   │   ├── 1798325.json                    # TAXIS Hyperkalemia
│   │   ├── 1798326.json                    # TAXIS T2DM
│   │   ├── 1263.json                       # OHDSI Phenotype Library COPD
│   │   ├── 1179.json                       # OHDSI Phenotype Library Obesity
│   │   ├── 1191.json                       # OHDSI Phenotype Library CKD
│   │   ├── 940.json                        # OHDSI Phenotype Library Hyperkalemia
│   │   └── 1032.json                       # OHDSI Phenotype Library T2DM
│   ├── sql/sql_server/                     # 10 compiled OHDSI SqlRender SQL scripts
│   │   ├── 1798322.sql
│   │   ├── 1798323.sql
│   │   ├── 1798324.sql
│   │   ├── 1798325.sql
│   │   ├── 1798326.sql
│   │   ├── 1263.sql
│   │   ├── 1179.sql
│   │   ├── 1191.sql
│   │   ├── 940.sql
│   │   └── 1032.sql
│   └── settings/
│       ├── CohortsToCreate.csv             # Cohort registration manifest
│       └── PhenotypePairs.csv              # Paired comparison matrix for evaluation
└── extras/
    ├── CodeToRun.R                         # Multi-site network execution driver template
    ├── TestOnEunomia.R                     # 2-minute zero-setup Eunomia SQLite sanity check
    └── RunSuppressionBoundaryTests.R       # Standalone cell suppression boundary test suite
```

---

## 6. Execution Instructions for Network Analysts

### Prerequisites
- R (version $\ge$ 4.0.0)
- Java Runtime Environment (JRE $\ge$ 8, 64-bit)
- Standard OHDSI HADES packages:
  ```r
  install.packages("remotes")
  remotes::install_github("OHDSI/DatabaseConnector")
  remotes::install_github("OHDSI/CohortGenerator")
  remotes::install_github("OHDSI/CohortDiagnostics")
  remotes::install_github("OHDSI/PheValuator")
  remotes::install_github("OHDSI/ParallelLogger")
  ```

### Step 1: Package Installation
Install the study package from the local directory or GitHub repository:
```r
# From cloned repository root:
devtools::install_local("extras/TaxisPhenotypeEvaluation")

# Or directly from GitHub:
remotes::install_github("ohdsi-studies/Taxis", subdir = "extras/TaxisPhenotypeEvaluation")
```

### Step 2: Configure and Run via `extras/CodeToRun.R`
1. Open [`extras/CodeToRun.R`](./extras/CodeToRun.R) in your R environment.
2. Specify connection parameters for your OMOP CDM instance:
   ```r
   library(TaxisPhenotypeEvaluation)
   library(DatabaseConnector)

   connectionDetails <- DatabaseConnector::createConnectionDetails(
     dbms         = "postgresql", # e.g. postgresql, redshift, snowflake, sql server
     server       = Sys.getenv("DB_SERVER", "localhost/cdm"),
     user         = Sys.getenv("DB_USER"),
     password     = Sys.getenv("DB_PASSWORD"),
     port         = 5432,
     pathToDriver = Sys.getenv("DATABASECONNECTOR_JAR_FOLDER", "C:/drivers")
   )

   TaxisPhenotypeEvaluation::execute(
     connectionDetails    = connectionDetails,
     cdmDatabaseSchema    = "cdm",
     cohortDatabaseSchema = "scratch",
     cohortTable          = "taxis_pheno_eval",
     workDatabaseSchema   = "scratch",
     outputFolder         = "taxis_output",
     databaseId           = "My_Site_CDM",
     runCohortGeneration  = TRUE,
     runCohortOverlap     = TRUE,
     runDiagnostics       = TRUE,
     runPheValuator       = FALSE, # Set TRUE if PheValuator modeling is desired
     minCellCount         = 5
   )
   ```
3. Locate the generated export archive:
   - `taxis_output/Results_My_Site_CDM.zip`
4. Review the archive contents locally to confirm that only allowlisted aggregate files are present.
5. Securely transmit the zip bundle to the TAXIS coordinating investigators per network study protocol.

---

## 7. Standalone SQL Execution Alternative (Direct Query Console)

If your institution prefers generating cohorts directly via SQL without executing R:
1. Navigate to [`inst/sql/sql_server/`](./inst/sql/sql_server/).
2. Substitute the following SqlRender tokens in any `.sql` file:
   - `@cdm_database_schema`: The target CDM schema.
   - `@target_database_schema`: The scratch schema where cohort tables are written.
   - `@target_cohort_table`: The target cohort table name (e.g., `taxis_pheno_eval`).
   - `@target_cohort_id`: The ID of the cohort being created (e.g., `1798322`).
3. Run the script directly in your SQL interface (e.g., DBeaver, pgAdmin, Snowflake Worksheets, Redshift Query Editor).

---

## 8. Academic References & OHDSI Frameworks

1. **OHDSI Phenotype Development and Evaluation Workgroup**. *OHDSI Phenotype Library*. [https://data.ohdsi.org/PhenotypeLibrary/](https://data.ohdsi.org/PhenotypeLibrary/).
2. **Schuemie MJ, Voss EA, Rao GA, et al.** *CohortDiagnostics: Diagnostics for OHDSI Cohorts*. R package version 3.0.0. [https://ohdsi.github.io/CohortDiagnostics/](https://ohdsi.github.io/CohortDiagnostics/).
3. **Swerdel JN, Schuemie MJ, et al.** *PheValuator: Development and evaluation of a phenotype algorithm evaluator*. *J Biomed Inform*. 2019;97:103258.
4. **Bandeian SH, Rao G, Grannis S, Overhage JM.** *TAXIS: Building an OMOP-Native Clinical Relationship Layer to Support Reusable OHDSI Analytics*. 2026 OHDSI Global Symposium Collaborator Showcase (Entry #127), New Brunswick, NJ, October 2026.
5. **TAXIS Network Data Use Term Sheet**. [`docs/governance/TAXIS_NETWORK_DATA_USE_TERM_SHEET.md`](../../docs/governance/TAXIS_NETWORK_DATA_USE_TERM_SHEET.md).
6. **TAXIS Network Study Protocol v1.0**. [`docs/protocol/TAXIS_NETWORK_STUDY_PROTOCOL_V1.md`](../../docs/protocol/TAXIS_NETWORK_STUDY_PROTOCOL_V1.md).
