# TAXIS Network Study — Release Notes: Version 1.0.0
## Data Partner Testing & Multi-Site Verification Release

> **Release Version**: `v1.0.0` (Data Partner Testing Release)  
> **Release Target**: OHDSI Federated Network Data Partners  
> **Target Environment**: OMOP Common Data Model (CDM v5.4)  
> **Repository**: [ohdsi-studies/Taxis](https://github.com/ohdsi-studies/Taxis)  
> **Date**: October 2026  
>  
> **Original Authorship & Intellectual Attribution**:  
> All SQL code, database architectures, 40-batch random partitioning strategies, healthcare utilization decile stratification, continuity-corrected directionality formulations, measurement key packing schemes, and core analytical algorithms in Pipeline v57 were conceived, designed, and authored by:  
> **Stephen H. Bandeian, MD, JD** — Principal Investigator, [Johns Hopkins University School of Medicine](https://www.hopkinsmedicine.org).  
>  
> **Study Leadership**:  
> • Stephen H. Bandeian, MD, JD — Principal Investigator & Author of all SQL & Analytic Code, [Johns Hopkins University School of Medicine](https://www.hopkinsmedicine.org)  
> • J. Marc Overhage, MD, PhD — Co-Principal Investigator, The Overhage Group / [Indiana University School of Medicine](https://medicine.iu.edu)  
> • Gowtham Rao, MD, PhD — Study Package Architect & Maintainer, [CoReason, Inc.](https://www.coreason.ai) / OHDSI  
> • Shaun Grannis, MD, MS — Investigator, [Regenstrief Institute](https://www.regenstrief.org) / [Indiana University School of Medicine](https://medicine.iu.edu)  

---

## 1. Executive Summary

We are pleased to announce the **TAXIS v1.0.0 Data Partner Testing Release**. The Temporal Association eXploration for Clinical Inference Studies (TAXIS) initiative is an international OHDSI network study designed to discover, quantify, and evaluate longitudinal clinical concept associations across observational healthcare data.

Benchmark tested on the Indiana Network for Patient Care (INPC) across 2.16 million patients, 11.3 million person-years, and 1.88 billion clinical events, TAXIS quantifies empirical co-occurrence and temporal precedence across six OMOP CDM cross-domain intersections.

This release marks the study package as **ready for distributed execution by OHDSI network data partners**.

---

## 2. What's Included in This Release

The repository provides a complete, tripartite open-source ecosystem conforming to OHDSI HADES standards:

### 2.1 Core Package: `Taxis` (Concept AB Association Mining Engine v57)
* **Distributed SQL Execution**: Executes encounter-level and population-level co-occurrence mining across 6 clinical domains (Conditions, Drugs, Measurements, Procedures, Devices, Observations).
* **40-Batch Hash Partitioning**: Partitions the CDM cohort into 40 balanced segments (`md5(person_id) % 40`) to maintain a predictable, bounded memory and disk footprint.
* **Epidemiological Estimands**:
  * Crude Poisson Event Lift ($Lift_{obs} = O_{AB} / E_{obs}$) with Wilson-Hilferty asymmetrical 95% Poisson confidence intervals.
  * Healthcare Utilization Decile Stratification (10 deciles) to eliminate contact density and surveillance confounding ($E_{MH}$).
  * Cochran-Mantel-Haenszel Common Odds Ratio ($OR_{MH}$) and Continuity-Corrected Directionality Ratios ($DR_{corrected} = (O_{after} + 0.5) / (O_{before} + 0.5)$).
  * Symmetric reflection of within-domain pairs (`1010`, `2020`, `3030`, `4040`, `6060`).

### 2.2 Extension Package: `TaxisPhenotypeCreator` (Neuro-Symbolic Phenotyping)
* Synthesizes computable OHDSI Circe JSON phenotype definitions directly from empirical concept-pair associations.
* Deterministic 4-slot clinical architecture:
  1. Primary Entry Criteria
  2. Confirmatory Laboratory Measurements
  3. Indicated First-Line Pharmacotherapies
  4. Differential Diagnosis Rule-Out Exclusions
* Compiles dialect-specific cohort SQL via `CirceR::buildCohortQuery()`.
* Bundles 5 benchmark clinical phenotypes: Type 2 Diabetes Mellitus, Chronic Kidney Disease, COPD, Hyperkalemia, and Obesity.

### 2.3 Extension Package: `TaxisPhenotypeEvaluation` (Comparative Evaluation)
* Benchmarks TAXIS-derived phenotypes against comparator definitions from the OHDSI Phenotype Library.
* Computes pairwise patient-level cohort overlap and Jaccard similarity matrices.
* Pre-configured integration hooks for `CohortDiagnostics` characterization and `PheValuator` diagnostic performance evaluation.

---

## 3. Privacy, Data Governance & Security Guarantees

As an OHDSI network study, TAXIS strictly adheres to the principle of federated local computation:

* **Zero Patient-Level Data Transmission**: All patient-level data stays strictly behind your institution's firewall. No person IDs, event dates, or free text are ever exported.
* **Mandatory Small-Cell Suppression**: Counts between 1 and 4 are automatically masked to `-1` across all exported summary tables (`DEC-GR-005`).
* **Mathematical Anti-Reconstruction Protection**: Companion fields (e.g. gap distribution fractions and patient totals) are jointly suppressed to prevent subtraction attacks (`REC-038-2`, `REC-039-1`).
* **Auditable Non-PHI Archive**: The runner generates a single verified zip archive (`Results_Mining_<databaseId>.zip`) containing non-identifiable, aggregate-only summary tables. Data partners may inspect every CSV before returning results.

---

## 4. Platform Compatibility & Validation Status

The study package has undergone comprehensive continuous integration and multi-platform testing:

| Operating System | R CMD check Status | Target Dialects Validated |
|---|---|---|
| **Ubuntu 22.04 LTS** | :white_check_mark: 100% Pass | PostgreSQL 14+, Redshift |
| **macOS (Apple Silicon & Intel)** | :white_check_mark: 100% Pass | PostgreSQL, Snowflake, BigQuery |
| **Windows Latest** | :white_check_mark: 100% Pass | Microsoft SQL Server, Oracle, PostgreSQL |

* **HADES Conformance**: Seamless database execution via `DatabaseConnector` (>= 5.0.0) and `SqlRender` (>= 1.15.0).
* **Columnar Warehouse Optimization**: Toggle `createIndexDdl = FALSE` for native execution on cloud data warehouses without secondary indexes (Snowflake, BigQuery, Databricks).
* **JDBC Driver Hardening**: Uses statement splitting and whitespace filtering (`executeSqlSafely`) to eliminate JDBC driver empty-statement crashes (`REC-063-1`).

---

## 5. Quick-Start Guide for Data Partners

### Step 1: Software Prerequisites
* **R (>= 4.0.0)** (R 4.2+ recommended).
* **Java 17 (64-bit)** (Required for DatabaseConnector JDBC bridge).
* Target database JDBC driver in a local directory (e.g., `C:/drivers` or `/opt/drivers`).

### Step 2: Install the Study Package
Open R or RStudio and run:
```r
# Install remotes if not already installed
if (!requireNamespace("remotes", quietly = TRUE)) install.packages("remotes")

# Install the TAXIS study package from GitHub
remotes::install_github("ohdsi-studies/Taxis@develop")
```

### Step 3: Configure Database Connection & Run
Open and edit [`extras/CodeToRun.R`](file:///c:/files/git/github/ohdsi-studies/Taxis/extras/CodeToRun.R):

```r
library(Taxis)
library(DatabaseConnector)

# Configure database connection
connectionDetails <- createConnectionDetails(
  dbms     = "postgresql", # "sql server", "redshift", "snowflake", etc.
  server   = "localhost/cdm",
  user     = "cdm_user",
  password = Sys.getenv("DB_PASSWORD"),
  pathToDriver = "C:/drivers"
)

# Phase A: Pre-Flight Verification (Takes ~5-15 minutes)
# Verifies connectivity, permissions, and tables on 1/40th of cohort (~2.5% workload)
Taxis::execute(
  connectionDetails      = connectionDetails,
  cdmDatabaseSchema      = "cdm",
  resultsDatabaseSchema  = "taxis_results",
  projectReferenceSchema = "concept_ab_vocab",
  outputFolder           = "./taxis_output",
  databaseId             = "MySite",
  batchCount             = 40,
  partialRunBatchLimit   = 1,   # Phase A: 1 test batch
  createIndexDdl         = TRUE,
  runMining              = TRUE,
  packageResults         = TRUE
)

# Phase B: Full Production Run
# Once Phase A completes cleanly, run all 40 batches:
# partialRunBatchLimit = 40
```

### Step 4: Verify and Return Results
Upon completion, the output zip file will be located at:
```text
./taxis_output/Results_Mining_<databaseId>.zip
```
1. Inspect the generated aggregate CSV tables inside the zip file to confirm privacy compliance.
2. Email or securely transmit the zip file to the study coordination team.

---

## 6. Study Leadership & Support

If you encounter any issues during configuration or execution, please reach out to the study leadership team:

* **Study Coordination & Technical Support**:
  - Dr. Gowtham Rao (`gowtham.rao@coreason.ai`)
  - Dr. Stephen H. Bandeian (`sbandeian@gmail.com`)
* **GitHub Issues**: Please report any bugs or database-specific dialect issues on [GitHub Issues](https://github.com/ohdsi-studies/Taxis/issues).
