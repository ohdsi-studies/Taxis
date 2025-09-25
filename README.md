# TAXIS
![Study Status](https://img.shields.io/badge/Study%20Status-Active-brightgreen.svg) ![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)

---

## Project Overview
TAXIS (Transparent Analytic Knowledge Graph for Interoperable Science) is an OHDSI-led methodological infrastructure project that derives, evaluates, and validates clinically meaningful relationships between coded health concepts using retrospective, de-identified data in the **OMOP Common Data Model (CDM)**. The project combines large-scale co-occurrence statistics with **large language model (LLM)** classification to characterize semantic relationships (e.g., causal, confusable, hierarchical). Human reviewers validate discordant or uncertain classifications.

The name **TAXIS** comes from the Greek word *τάξις* (*táxis*), meaning *order*, *arrangement*, or *structured framework*. The project reflects this sense of systematic organization, aiming to bring order and transparency to the complex web of clinical relationships.

The resulting **knowledge graph** provides a foundational analytic resource that can be used to:
- Simplify phenotype and cohort development
- Accelerate quality measurement
- Support clinical decision support rules
- Enable hypothesis generation at scale
- Advance applied clinical analytics in learning health systems

Importantly, **no personally identifiable (PII) or protected health information (PHI)** is used at any stage.

---

## How to Engage
We invite OHDSI collaborators and external researchers to **participate directly**:

1. **Run the Study Package**  
   - Clone and execute the TAXIS study package against your OMOP CDM instance.  
   - SQL scripts (e.g., `concept_ab.sql`) compute co-occurrence statistics, directionality ratios, odds ratios, and related measures.

2. **Upload Step 5 Output**  
   - Once the study package produces a **step_5 CSV file**, upload it to the [TAXIS web portal](https://taxis.netlify.app/).  
   - The portal will process the data, apply LLM-based classification of relationships, and provide validated outputs.

3. **Download Validated Results**  
   - Retrieve enriched files containing both statistical evidence and semantic validation.  
   - Sample outputs are provided in the examples directory.

By contributing, you:
- Help build the **world’s most comprehensive, data-driven clinical knowledge graph**.
- Gain early access to validated relationship datasets for local analytic use.
- Contribute to open science infrastructure that supports reproducible, scalable analytics.

---

## Concept AB Package
The first deliverable of TAXIS is the **Concept AB (CONCEPT_CF_AB) package**, which creates a curated, clinically meaningful, and analytically useful library of relationships between pairs of OMOP “clinical finding” concepts. This supports everyday analytic tasks such as cohort definition and outcome specification.

### How It Works
- **Input**: The package reads from OMOP CDM tables (`condition_occurrence`, `concept`, `concept_relationship`, `concept_ancestor`).
- **Processing**: It computes frequent, statistically significant person-level co-occurrences within a configurable ±30-day window. It then materializes a final output table, `concept_ab_step_5`, with co-occurrence counts and statistical measures (lift, odds ratio, directionality ratio, etc.).
- **Classification**: Concept pairs are categorized using an LLM into relationship types (e.g., causal, subset, similar presentation).
- **Portability**: Parameterized, SqlRender-compatible SQL is orchestrated in R, enabling execution across supported DBMSs.

### Environment & Prerequisites
- OS: Windows, macOS, or Linux
- R ≥ 4.2; Java ≥ 8 (17 LTS recommended)
- Required R packages: **SqlRender**, **DatabaseConnector**
- Database: OMOP CDM with vocabulary loaded
- A DBA-provisioned least-privilege account with:
  - SELECT on required CDM and curated lookup tables
  - DDL/DML rights only in a designated results schema

### Configuration (.Renviron)
- Connection fields: DBMS, DB_SERVER, DB_PORT, DB_USER, DB_AUTH_MODE, JDBC folder
- Schemas: CDM schema, lookup schema, results schema
- Runtime controls: co-occurrence window (days), minimum persons, batch counts, index settings

### Running the Pipeline
1. Edit `.Renviron` with site-specific values.
2. Install dependencies; run `concept_cf_ab_precheck.R` to validate environment.
3. Run `concept_cf_ab_run.R` to execute init → batch loop → finalize.
4. Review outputs in the designated results schema.

### Troubleshooting
- Ensure `.Renviron` settings match CAB_SQL_* entries.
- Confirm JDBC drivers are installed.
- Check database permissions if create/drop/index fails.
- Load the lookup CSV (`concept_ab_cf_rollup`) into the project schema.

### Security
- TAXIS does not modify system-level security.
- Connections use OHDSI’s DatabaseConnector with least-privilege credentials.

OHDSI references: [DatabaseConnector Docs](https://ohdsi.github.io/DatabaseConnector/), [SqlRender Docs](https://ohdsi.github.io/SqlRender/)

---

## Timeline
2024: Foundational work on diagnostic hierarchies and early relationship table
Sep 2025: Launch of TAXIS OHDSI Network Study, protocol published
Oct 2025: First large-scale outputs: v1 Diagnosis–Diagnosis Relationship Tables and network engagement launch at OHDSI Symposium
Oct-Nov 2025: Participating site run study package for disagnosis-diagnosis relationships locally and upload results thorught TAXIS website for validation and aggregation, Public domain Medication relationships aggregated and published
Dec 2025: Diagnosis-diagnosis relationships based on Network data review and cleanup
Jan 2026: Add Service Relationships to study package and Diagnosis-Diagnosis relationships V1 availablel
Feb-Mar 2026: Participating site run updated study package for service relationships locally and upload results thorught TAXIS website for validation and aggregation
Mar 2026: Service relationships based on Network data review and cleanup
Apr 2026: Diagnosis, Service and Medication relationships V1 available
2026: Work with OMOP vocabulary team to incorporate results where appropriate into standard and evaluate how to leverage the relatinships fully in ATLAS.

---

## Repository Contents
- **docs/**
  - Study protocol, concept papers, symposium drafts, technical documentation, timeline.
- **study_package/**
  - `concept_ab.sql` – Core OMOP condition co-occurrence analysis pipeline.
- **examples/**
  - `sample_step5.csv` – Example OMOP site output for upload.
  - `sample_validated_output.csv` – Example download after LLM validation.
- **publications/**
  - OHDSI Symposium brief report and related materials.

---

## Next Steps
- Expand from diagnosis–diagnosis pairs to **multi-domain relationships** (diagnosis–service, diagnosis–medication).
- Improve handling of large file uploads and watchdog functions for failed jobs.
- Extend schema to capture **per-upload site statistics** in addition to aggregate master record counts.
- Publish reproducible pipelines for public use via OHDSI GitHub.

---

## Citation
If you use TAXIS outputs in your work, please cite:

> Overhage JM, Bandeian S, et al. *TAXIS: Enhancing OMOP Capabilities Through Knowledge Graphs*. OHDSI Symposium 2025 (forthcoming).

---

## Contact
- **Study Leads**:  
  - J. Marc Overhage, MD, PhD – Indiana University / Elevance Health  
  - Stephen H. Bandeian, MD, JD – Johns Hopkins University

- **OHDSI Forums Tag**: [TAXIS](https://forums.ohdsi.org/u/TAXIS)

---
