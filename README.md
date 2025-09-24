# TAXIS: 
![Study Status](https://img.shields.io/badge/Study%20Status-Active-brightgreen.svg)

---

## Project Overview
TAXIS is an OHDSI-led methodological infrastructure project that derives, evaluates, and validates clinically meaningful relationships between coded health concepts using retrospective, de-identified data in the **OMOP Common Data Model (CDM)**. The project combines large-scale co-occurrence statistics with **large language model (LLM)** classification to characterize semantic relationships (e.g., causal, confusable, hierarchical). Human reviewers validate discordant or uncertain classifications. 

The name **TAXIS** comes from the Greek word *τάξις* (táxis), meaning *order*, *arrangement*, or *structured framework*. The project reflects this sense of systematic organization, aiming to bring order and transparency to the complex web of clinical relationships.

The resulting **knowledge graph** provides a foundational analytic resource that can be used to:
- Simplify phenotype and cohort development
- Accelerate quality measurement
- Support clinical decision support rules
- Enable hypothesis generation at scale
- Advance applied clinical analytics in learning health systems

Importantly, **no personally identifiable (PII) or protected health information (PHI)** is used at any stage.

---

## Timeline
- **2024**: Foundational work on diagnostic hierarchies and early relationship table
- **Sep 2025**: Launch of TAXIS OHDSI Network Study, protocol published
- **Oct 2025**: First large-scale outputs: v1 Diagnosis–Diagnosis Relationship Tables and network engagement launch at OHDSI Symposium
- **Oct-Nov 2025**: Participating site run study package for disagnosis-diagnosis relationships locally and upload results thorught TAXIS website for validation and aggregation, Public domain Medication relationships aggregated and published
- **Dec 2025**: Diagnosis-diagnosis relationships based on Network data review and cleanup
- **Jan 2026**: Add Procedure Relationships to study package and Diagnosis-Diagnosis relationships V1 availablel
- **Feb-Mar 2026**: Participating site run updated study package for procedure relationships locally and upload results thorught TAXIS website for validation and aggregation
- **Mar 2026**: Procedure relationships based on Network data review and cleanup
- **Apr 2026**: Diagnosis, Procedue and Medication relationships V1 available
 

- **2026 (planned)**: Expansion to service–diagnosis and medication–diagnosis relationships; integration into a public knowledge graph

---

## How to Engage
We invite OHDSI collaborators and external researchers to **participate directly**:

1. **Run the Study Package**  
   - Clone and execute the TAXIS study package against your OMOP CDM instance.  
   - SQL scripts (e.g., `concept_ab.sql`) compute co-occurrence statistics, directionality ratios, odds ratios, and related measures

2. **Upload Step 5 Output**  
   - Once the study package produces a **step_5 CSV file**, upload it to the [TAXIS web portal](https://taxis.netlify.app/).  
   - The portal will process the data, apply LLM-based classification of relationships, and provide validated outputs.

3. **Download Validated Results**  
   - Retrieve enriched files containing both statistical evidence and semantic validation.  
   - Sample outputs are provided (see below).

By contributing, you:
- Help build the **world’s most comprehensive, data-driven clinical knowledge graph**.
- Gain early access to validated relationship datasets for local analytic use.
- Contribute to open science infrastructure that supports reproducible, scalable analytics.

---

## Repository Contents
- **docs/**
  - `TAXIS Network Study Protocol 15-Sep-2025.docx` – Detailed study protocol with analytic methods and governance.
  - `Concept Paper V7 2025.docx` – Conceptual framework linking TAXIS to the broader Knowledge Graph and learning health system agenda【24†Concept Paper V7 2025.docx】.
 
  - `Technical Documentation.docx` – Environment setup, database schemas, Netlify/Neon architecture, and developer notes.
  - `OHDSI TAXIS timeline.pptx` – Project milestones and rollout plan.

- **study_package/**
  - `concept_ab.sql` – SQL implementation of the core OMOP condition co-occurrence analysis pipeline.

- **examples/**
  - `sample_step5.csv` – Example OMOP site output for upload.
  - `sample_validated_output.csv` – Example download after LLM validation.

- **publications/**
 - `OHDSI Symposium 2025 Bandeian_Stephen_TAXIS_Enhancing_OMOP_Capabilities_2025symposium.docx` – OHDSI Symposium presentation draft【27†bandeian_stephen_THEMIS_Enhancing_OMOP_Capabilities_2025symposium.pdf.pdf】.
  - Draft chapters and peer-reviewed conceptual foundations【26†sbandeian_book_chapters.pdf】.

---

## Next Steps
- Expand the TAXIS knowledge base from diagnosis–diagnosis pairs to **multi-domain relationships** (diagnosis–service, diagnosis–medication).
- Improve handling of large file uploads and watchdog functions for failed jobs.
- Extend schema to capture **per-upload site statistics** in addition to aggregate master record counts.
- Publish reproducible pipelines for public use via OHDSI GitHub.

---

## Citation
If you use TAXIS outputs in your work, please cite:

> Overhage JM, Bandeian S, et al. *TAXIS: Enhancing OMOP Capabilities Through Knowledge Graphs*. OHDSI Symposium 2025

---

## Contact
- **Study Leads**:  
  - J. Marc Overhage, MD, PhD – Indiana University / Regenstrief Institute
  - Stephen H. Bandeian, MD, JD – Johns Hopkins University

- **OHDSI Forums Tag**: [TAXIS](https://forums.ohdsi.org/u/TAXIS)

---
