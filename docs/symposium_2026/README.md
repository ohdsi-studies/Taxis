# 2026 OHDSI Global Symposium: Collaborator Showcase #127

> **Title**: TAXIS: Building an OMOP-Native Clinical Relationship Layer to Support Reusable OHDSI Analytics  
> **Showcase Designation**: Entry #127  
> **Conference**: 2026 OHDSI Global Symposium  
> **Dates**: October 20–22, 2026  
> **Venue**: Hyatt Regency New Brunswick, New Brunswick, NJ  
> **Submission Deadline**: Friday, October 9, 2026 (Brief Report PDF & Poster Walkthrough Script to Craig Sachson)  

---

## 1. Executive Summary & Conceptual Foundations

At the 2026 OHDSI Global Symposium, the TAXIS research team presents a methodological framework that bridges observational health data co-occurrences with structured clinical taxonomies and multi-model consensus to establish a computable clinical knowledge layer for the OMOP Common Data Model.

### The Problem: Beyond "One-at-a-Time" Research
Observational health research has long been constrained by a project-by-project craftsmanship model. To overcome this, the **OHDSI Phenotype Development and Evaluation Workgroup** established the **OHDSI Phenotype Library**—advancing the vision of systematic reuse of peer-reviewed, computable phenotypes anchored by structured **Clinical Descriptions** (presentation, confirmatory laboratory criteria, first-line treatments, and differential exclusions).

However, authoring rich phenotypes at scale faces a fundamental barrier:
- Across **1,104 cohorts in the OHDSI Phenotype Library**, two-thirds remain basic single-concept code lists without logic rules, and **only ~2%** incorporate multi-domain laboratory or medication criteria.
- **The 0.4% Vocabulary Limitation**: Controlled vocabularies (SNOMED-CT, RxNorm, LOINC) capture *what things are* via *is-a* hierarchies, but in empirical testing across **26,901 clinical concept pairs**, existing standard vocabularies carried relationships for **only 0.4%** (119 pairs, 72 of which were simply *is-a* links). Over 99% of operational care relationships (which drug treats what disease, which lab confirms what diagnosis) are absent from standard terminology tables.

### Methodological Framework
TAXIS investigates whether empirical association rule mining combined with structured clinical taxonomies can help generate and evaluate candidate cohort definitions by uniting three components:
1. **Association Rule Mining**: Applying association rule mining across **2.16 million longitudinal patient records (11.3M person-years)** in the Indiana Network for Patient Care (INPC), adjusting for observation windows and healthcare utilization frequency.
2. **Standardized Clinical Taxonomy**: Applying a 112-code clinical taxonomy to categorize observational co-occurrences into a typed clinical knowledge graph.
3. **Multi-Domain Phenotype Synthesis**: Using the resulting knowledge graph to link index conditions with associated laboratories, medications, and differential diagnoses, generating candidate Circe cohort definitions compatible with the OHDSI Phenotype Library.

### Phenotyping Workflow Optimization: One Conceptual Application of TAXIS
While structured clinical knowledge graphs provide a computable foundation across multiple stages of observational research—including candidate negative control identification, informing study design to reduce confounding, and evaluating residual bias—**phenotyping workflow optimization using TAXIS represents one primary conceptual application**.

- **Resolving the Phenotype Reproducibility Crisis**: Systematic reviews of published observational literature across complex indications have revealed striking heterogeneity in phenotype algorithms, with independent research teams producing up to a **tenfold difference in cohort sizes** for the identical condition (Shoaibi et al., AMIA 2024).
- **Clinical Descriptions as Semantic Anchors**: To eliminate subjective ambiguity, the OHDSI community established that an *a priori* written **Clinical Description** across standardized domains (presentation, assessment, confirmatory labs, differential diagnoses/exclusions, indicated treatments) must serve as the **semantic anchor** before translating clinical intent into computable queries (Shoaibi, Ostropolets, Murphy, Rao, et al.).
- **The Neuro-Symbolic Proposer-Validator Framework**: Drawing on cognitive architecture principles (Kahneman System 1 vs. System 2) formalized for clinical informatics (Rao et al., 2026), TAXIS operationalizes a **Neuro-Symbolic Proposer-Validator Framework**:
  - **Neural / Associative Proposer (System 1)**: Traverses empirical co-occurrences mined across 2.16M longitudinal patients in the INPC OMOP CDM paired with the two-stage screen-and-code LLM ensemble (112-code taxonomy) to discover and type candidate multi-domain clinical associations, mitigating ungrounded hallucinations through empirical data grounding.
  - **Symbolic Structural Compiler & Validator (System 2)**: The automated phenotype builder (`build_1032.py`) compiles candidate edges into formal, deterministic, and syntactically auditable Circe JSON cohort definitions structured by the Clinical Description semantic anchor. Substantive clinical validity and phenotype diagnostic performance are evaluated separately through expert clinical adjudication and empirical measurement across partner CDMs using `CohortDiagnostics` and `PheValuator`.
- **Harmonized Prompt-to-Circe Slot Mapping**: Directly ingests the OHDSI Phenotype Workgroup's standard Clinical Description schema (`clinicalDescriptionPromptBriefWithExclusions.txt`), mapping clinical prompt sections 1-to-1 into computable Circe criteria blocks:
  - *Condition Overview & Presentation* $\rightarrow$ Primary Anchor Disorder (`PrimaryCriteria.CriteriaList`).
  - *Laboratory Tests & Diagnostic Values* $\rightarrow$ Confirmatory Labs (`InclusionRules` with `Measurement` domain criteria, guideline cutoffs, and $[-7, +30]$ day windows).
  - *Medications Usually Given* $\rightarrow$ Indicated Drug Exposures (`InclusionRules` with `DrugExposure` criteria: acute $\le 24\text{h}$, chronic $\le 30\text{d}$).
  - *Differential Diagnoses & Excluded Conditions* $\rightarrow$ Rule-Out Mimics (`InclusionRules` with Occurrence = 0 or `CensoringCriteria`, strictly capped at $<10\%$ anchor patient cost).
  - *Comorbid Conditions* $\rightarrow$ Baseline Patient Characterization & Covariate Balance (explicitly segregated to prevent false exclusions).
  - *Prognosis & Follow-up* $\rightarrow$ Post-Index Observation Windows (`PostDays`) and persistence logic.
  - *References* $\rightarrow$ Circe Definition Metadata & Provenance Tags.
- **Closed-Loop Phenotype Critic via Diagnostic Frameworks**: Standardized execution of `CohortDiagnostics` (characterization, incidence rates, orphan concept detection) paired with `PheValuator` diagnostic predictive models creates a closed-loop feedback mechanism: high-weight model covariates and orphan concepts are fed back to iteratively refine concept sets and cohort logic.
- **Independent Development vs. Final Evaluation Protocol**: To guard against circular overfitting—where an algorithm is iteratively tuned merely to reproduce an evaluator model rather than true clinical cases—the closed-loop refinement loop enforces a strict development-versus-evaluation boundary: exploratory model feedback is restricted to development data, Circe definitions are frozen prior to final validation, and performance characteristics are confirmed on independent held-out partitions or external partner CDMs.
- **Dynamic Knowledge Engine for Autonomous Phenotyping Agents**: Emerging community frameworks in autonomous cohort engineering (such as `PhenotypingAgent`, implemented as a LangGraph state machine) automate cohort development from clinical definitions through iterative design, Capr code generation, cohort measurement, and profile evaluation. While autonomous agents typically rely on pre-computed concept sets or manual single-concept lookups, TAXIS provides a computable clinical knowledge layer that supplies structured, multi-domain concept sets (anchor conditions, confirmatory labs, indicated medications, and exclusionary mimics) across 1.9M graded edges. Furthermore, during agent error-profile diagnosis, TAXIS's typed clinical relationships provide the clinical mechanism explaining observed discrepancies, informing grounded cohort refinement.
- **Algorithmic Concept Set Condensation & Optimization**: Observational association mining can identify extensive concept sets across OMOP vocabularies. Downstream integration with concept set optimization tools (such as `ConceptSetCondenser`) enables finding the shortest, most parsimonious Circe concept set expression (combining `includeDescendants = TRUE` and explicit exclusions) that covers *exactly* the specified concepts without changing cohort membership, producing clean, human-auditable definitions for the OHDSI Phenotype Library and ATLAS.

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│               TAXIS IN THE OHDSI PHENOTYPE DEVELOPMENT & EVALUATION LIFECYCLE          │
└───────────────────────────────────────────┬────────────────────────────────────────────┘
                                            │
               ┌────────────────────────────┴────────────────────────────┐
               ▼                                                         ▼
    ┌───────────────────────┐                                 ┌───────────────────────┐
    │  Researcher Question  │                                 │ Clinical Definition   │
    │  Structured T/C/I/O   │────────────────────────────────►│ "What it is"          │
    │  Intake Templates     │                                 │ Clinical intent       │
    └───────────────────────┘                                 └───────────┬───────────┘
                                                                          │
         ┌────────────────────────────────────────────────────────────────┴───────┐
         ▼                                                                        ▼
┌──────────────────────────────┐                                ┌──────────────────────────────┐
│ PHOEBE Network Concept Info  │                                │ TAXIS Knowledge Graph        │
│ • Empirical CDM prevalence   │                                │ • 112-code clinical taxonomy │
│ • Co-occurrence statistics   │                                │ • 1.9M graded clinical edges │
│ • Vocabulary roll-up counts  │                                │ • Directional ratios (DR)    │
└──────────────┬───────────────┘                                └──────────────┬───────────────┘
               │                                                               │
               └──────────────────────────────┬────────────────────────────────┘
                                              │
                                              ▼
                                ┌──────────────────────────────┐
                                │ Phenotype Designer           │
                                │ (TAXIS Circe Synthesis)      │
                                │ • Confirmatory labs & drugs  │
                                │ • Rule-out mimics (<10% cap) │
                                └──────────────┬───────────────┘
                                               │
                                               ▼
                                ┌──────────────────────────────┐
                                │ Phenotype Algorithm (Circe)  │
                                │ Executable cohort definition │
                                └──────────────┬───────────────┘
                                               │
               ┌───────────────────────────────┴───────────────────────────────┐
               ▼                                                               ▼
┌──────────────────────────────┐                                ┌──────────────────────────────┐
│ CohortDiagnostics            │                                │ PheValuator                  │
│ • Multi-CDM characterization │                                │ • Diagnostic predictive model│
│ • Orphan concept detection   │                                │ • ROC-AUC, sensitivity, PPV  │
│ • Index event breakdown      │                                │ • Non-zero model covariates  │
└──────────────┬───────────────┘                                └──────────────┬───────────────┘
               │                                                               │
               └──────────────────────────────┬────────────────────────────────┘
                                              │
                                              ▼
                                ┌──────────────────────────────┐
                                │ Phenotype Critic Feedback    │
                                │ • Matches covariates to graph│
                                │ • Evaluates orphan concepts  │
                                │ • Iterates Circe definition  │
                                └──────────────┬───────────────┘
                                               │
                                               └──────── (Iterative Loop) ─────────►
```

---

## 2. Study Investigators & Institutional Leadership

| Investigator | Role & Primary Institutional Affiliation |
|---|---|
| **Stephen H. Bandeian, MD, JD** | Principal Investigator, Johns Hopkins University School of Medicine (Biomedical Informatics & Data Science) |
| **Gowtham Rao, MD, PhD** | Investigator, CoReason, Inc. USA; OHDSI (Phenotype working group) |
| **Shaun Grannis, MD, MS** | Investigator, Regenstrief Institute / Indiana University School of Medicine |
| **J. Marc Overhage, MD, PhD** | Investigator, The Overhage Group / Indiana University School of Medicine |

---

## 3. Key Quantitative Findings & Showcase Results

The 2026 Collaborator Showcase presentation highlights results derived from large-scale empirical mining and multi-model consensus auditing:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        TAXIS EMPIRICAL SCALE                           │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
    ┌───────────────────────────────┼───────────────────────────────┐
    ▼                               ▼                               ▼
┌────────────────────────┐    ┌────────────────────────┐    ┌────────────────────────┐
│ 2.16M Longitudinal     │    │ 5.52M Candidate Pairs  │    │ 1.9M Published Edges   │
│ INPC Patients          │───►│ Support ≥ 100          │───►│ 112 Taxonomy Codes     │
│ 11.3M Person-Years     │    │ 14 Domain-Pair Classes │    │ Strong & Moderate Only │
└────────────────────────┘    └────────────────────────┘    └────────────────────────┘
```

* **Empirical Scale**: Mined over **5.52 million candidate concept pairs** ($N_{AB} \ge 100$) across 14 domain-pair classes from **2.16 million patients** (11.3 million person-years) in the Indiana Network for Patient Care (INPC) OMOP CDM.
* **Knowledge Graph Volume**: Materialized $\approx 1.9\text{ million graded clinical edges}$ across $\approx 17,000\text{ standard concepts}$.
* **Vocabulary Comparison**: Standard terminologies define relationships for **0.4%** of evaluated frequently co-occurring pairs, reflecting differing design objectives.
* **Clinical Relevance (ClinVec Benchmark)**: Edge existence vote count achieves an **AUC of 0.81** (95% CI: 0.79–0.83) against clinician relevance ratings.
* **Temporal Directionality (PACES Benchmark)**: Achieves **99% directionality agreement** with the PACES clinical benchmark (100% on evaluated intervention–disorder pairs).
* **Blinded Physician Review**: Blinded clinician review of 291 INPC pairs confirms **88% agreement on broad relationship group** (58% exact 112-code taxonomy match).
* **Cohort Concordance**: Candidate Circe cohorts generated from graph traversals achieve **Jaccard similarities of 0.97 to 0.995** against established OHDSI Phenotype Library definitions.

---

## 4. The 5 Target Benchmark Phenotypes

TAXIS evaluates 5 target clinical phenotypes generated directly from graph traversals against established OHDSI Phenotype Library comparator cohorts:

| Target Phenotype | Atlas Demo ID | Phenotype Library Standard | Primary Criteria Focus | Rule-Out Mimic Handling (<10% Cap) |
|---|---|---|---|---|
| **Chronic Obstructive Pulmonary Disease (COPD)** | [1798322](https://atlas-demo.ohdsi.org/#/cohortdefinition/1798322) | Library 1263 | Chronic obstructive airway disease | Excludes Asthma with $<10\%$ anchor patient cost |
| **Obesity** | [1798323](https://atlas-demo.ohdsi.org/#/cohortdefinition/1798323) | Library 1179 | BMI $\ge 30$ / Obesity diagnosis | Requires confirmatory metabolic observation |
| **Chronic Kidney Disease (CKD)** | [1798324](https://atlas-demo.ohdsi.org/#/cohortdefinition/1798324) | Library 1191 | Stage 3–5 CKD diagnoses | Incorporates eGFR lab criteria; excludes acute renal failure |
| **Hyperkalemia** | [1798325](https://atlas-demo.ohdsi.org/#/cohortdefinition/1798325) | Library 940 | Serum Potassium $> 5.0\text{ mEq/L}$ | Differentiates true elevation from hemolyzed specimen |
| **Type 2 Diabetes Mellitus (T2DM)** | [1798326](https://atlas-demo.ohdsi.org/#/cohortdefinition/1798326) | Library 1032 | T2DM diagnosis + antidiabetic drugs | Excludes Type 1 DM & secondary diabetes |

---

## 5. Collaborator Showcase Deliverables (Due October 9, 2026)

Submission and dissemination deliverables for Collaborator Showcase Entry #127:

1. **4-Page Brief Report Manuscript**: Adhering to OHDSI author guidelines, submitted for the 2026 Collaborator Showcase proceedings. Covers clinical knowledge graph construction, validation benchmarks (ClinVec, PACES, INPC blinded adjudication), and phenotype recreation performance.
2. **Digital Poster Suite (48" x 36" Horizontal)**: Visual diagrams detailing the Concept AB association mining pipeline, the Two-Stage Screen-and-Code Ensemble (112-code clinical taxonomy), and the 5-Phenotype evaluation framework.
3. **Network Study Protocol (v1.0)**: Formal study protocol detailing the multi-site federated study design, eventization rules, hazard windows, and two-stage ensemble. Located at [`docs/protocol/TAXIS_NETWORK_STUDY_PROTOCOL_V1.md`](../protocol/TAXIS_NETWORK_STUDY_PROTOCOL_V1.md).
4. **Network Evaluation Package (`TaxisPhenotypeEvaluation`)**: HADES-compliant R study package for multi-database evaluation across partner OMOP CDMs. Located in [`extras/TaxisPhenotypeEvaluation/`](../../extras/TaxisPhenotypeEvaluation/README.md).
5. **Network Data Governance Term Sheet**: Institutional privacy specification guaranteeing local aggregate-only execution, zero patient-level data export, and $<5$ small-cell suppression. Located at [`docs/governance/TAXIS_NETWORK_DATA_USE_TERM_SHEET.md`](../governance/TAXIS_NETWORK_DATA_USE_TERM_SHEET.md).

---

## 6. Community Integration & Methodological Roadmap (2026–2027)

Following the 2026 symposium demonstration, TAXIS will advance across two parallel, complementary workstreams:

### Track A: Phenotype Ecosystem Integration & Community Governance
1. **OHDSI Phenotype Library Version 3.0 Integration (Autonomous Governance)**:
   - **Automated Intake & Schema Mapping**: Connect TAXIS-generated Circe cohort definitions directly into the agentic intake pipeline of **OHDSI Phenotype Library 3.0**, enabling automated metadata annotation and schema standardization.
   - **Redundancy Detection & Variant Mapping**: Leverage Library 3.0 similarity evaluation (concept set Jaccard and logic flow comparisons) to evaluate whether TAXIS-generated phenotypes represent novel definitions or entity variants of existing library cohorts.
   - **Longitudinal Semantic Monitoring**: Couple TAXIS knowledge graph updates with Library 3.0 drift detection to monitor concept obsolescence across OMOP vocabulary releases and suggest updated criteria.

2. **PHOEBE Network Prevalence Integration**:
   - **Empirical Concept Ranking**: Integrate concept prevalence counts and co-occurrence statistics from **PHOEBE** (PHenotype Optimization Expressed via Browser Experience) to inform concept set selection.
   - **Balancing Clinical Semantics & Real-World Frequency**: Combine TAXIS clinical relationship semantics (confirmatory labs, indicated medications, exclusionary mimics) with PHOEBE network-wide frequency data to prioritize clinically relevant concepts while avoiding ultra-rare or obsolete codes.
   - **Calibrating Exclusion Thresholds**: Utilize network concept prevalence to tune rule-out criteria, ensuring exclusions eliminate clinical mimics without excessively restricting target populations.

3. **CohortDiagnostics & PheValuator Evaluation Lifecycle**:
   - **CohortDiagnostics in Phenotype Development & Evaluation**:
     - Systematically embed `CohortDiagnostics` execution as an integral step in phenotype development and evaluation across partner OMOP CDMs.
     - Characterize candidate cohorts across index event breakdowns (identifying which concepts drive cohort entry across data sources), incidence rates, demographics, visit context (inpatient vs. outpatient proportions), and inclusion rule attrition.
     - Leverage orphan concept evaluation to identify clinically related codes within the OMOP vocabulary that were omitted from initial TAXIS concept sets, informing concept set expansion.
   - **PheValuator Covariate-Driven Iterative Refinement**:
     - Quantitatively evaluate diagnostic operating characteristics (sensitivity, specificity, positive predictive value) across partner databases using `PheValuator`.
     - Extract non-zero predictive covariates and feature weights from `PheValuator` diagnostic predictive models (e.g., LASSO penalized regression).
     - Utilize high-weight predictive covariates as a data-driven feedback loop into the TAXIS knowledge graph traversal:
       - *Positive predictive covariates* not captured in initial criteria are cross-referenced with high-lift, high-consensus graph edges (e.g., confirmatory laboratory tests or specific therapies) to expand or refine inclusion logic.
       - *Negative predictive covariates* or features associated with false positives are evaluated against differential diagnosis and mimic edges (`EXCLUSIONARY_MIMIC`, `DIFFERENTIAL_DIAGNOSIS`) to calibrate rule-out criteria.
     - Enable an iterative, closed-loop cycle of phenotype refinement that harmonizes algorithmic graph traversal with empirical CDM predictive modeling.

4. **Autonomous Agentic Phenotyping & Concept Set Condensation**:
   - **Autonomous Cohort Engineering Integration**: Connect TAXIS clinical relationship queries into autonomous phenotyping agents (such as `PhenotypingAgent`) via Model Context Protocol (MCP) services. TAXIS replaces static, pre-computed concept sets with dynamic, multi-domain graph traversals across anchor conditions, confirmatory labs, indicated medications, and exclusionary mimics, while providing the clinical mechanism rationale required during agent error-profile diagnostic routines.
   - **Optimal Concept Set Expressions**: Pair TAXIS candidate concept generation with algorithmic set-covering optimization (such as `ConceptSetCondenser`) to synthesize minimal, performant Circe expressions that cover target concepts exactly without changing cohort membership, ensuring readability and computational efficiency for ATLAS and the Phenotype Library.

5. **Feedback Loop, Quality Ranking & Community Review**:
   - **Multi-Dimensional Quality Ranking**: Establish a transparent quality scoring rubric for candidate phenotypes incorporating:
     - *Graph Evidence Grade*: Confidence weighting of underlying clinical edges (Strong/Moderate consensus).
     - *Network Feasibility*: PHOEBE empirical prevalence across diverse network CDMs.
     - *Diagnostic Performance*: Standardized `CohortDiagnostics` characterization and `PheValuator` operating characteristics (ROC-AUC, sensitivity, specificity).
     - *Metadata Completeness*: Intake hygiene and documentation scores from Phenotype Library 3.0.
   - **Workgroup Peer Review**: Support human-in-the-loop review within the **OHDSI Phenotype Development and Evaluation Workgroup**, providing clinicians and epidemiologists with structured rationale and validation data to evaluate candidate definitions for official library adoption.

### Track B: Causal Study Design, Negative Controls & Error Calibration
6. **Candidate Negative Control Generation & Empirical Error Calibration**:
   - **Candidate Negative Control Hypothesis Screening**: Systematically identify candidate negative control outcomes by querying the clinical relationship layer for concept pairs with an absence of documented pathophysiologic, etiologic, or therapeutic mechanisms across all 112 taxonomy codes.
   - **Causal Null Candidacy vs. Observational Diagnostics**: Rather than conditioning candidate eligibility on observed null association in evaluation data (which risks discarding the very confounding bias calibration is meant to measure), TAXIS uses clinical relationship absence to generate causal-null candidates for independent clinical and literature review. Baseline observational metrics ($\text{Lift}$, $DR$) are reported as characterization diagnostics. Pre-specified negative control sets are then evaluated across partner CDMs to generate empirical null distributions that calibrate residual systematic error in comparative studies.

7. **Confounder Identification & Confounder Balance Evaluation**:
   - **Informing Study Design Choices**: Leverage explicit clinical relationship semantics (causal, manifestation, contraindication) to assist investigators in identifying true common-cause confounders when defining cohort inclusion and baseline covariate criteria.
   - **Protecting Intermediate Mediators & Colliders**: Use directional relationship data to differentiate intermediate variables on the causal pathway (preventing over-adjustment bias) and avoid collider conditioning.
   - **Evaluating Confounder Balance & Residual Confounding**: Complement causal inference workflows by using clinical relationship graphs to inspect whether recognized clinical confounders achieve empirical balance across treatment arms, and inform sensitivity analyses for residual unmeasured confounding.

8. **Network Evidence Adjudication & Bias Evaluation**:
   - **Contextualizing Distributed Findings**: Provide a structured clinical knowledge layer to assist investigators in evaluating observed associations across data networks.
   - **Adjudicating Alternative Explanations**: Distinguish genuine therapeutic effects from confounding by indication, protopathic bias (early manifestations treated prior to formal diagnosis), or detection artifacts.

---

## 7. Key References & Literature

1. **Shoaibi A, Ostropolets A, Weaver J, Rao G, et al.** *Variation in phenotype definitions in observational clinical research: a review of three conditions*. *AMIA Annu Symp Proc*. 2024.
2. **Shoaibi A, Ostropolets A, Murphy JD, Rao GA, et al.** *Clinical Descriptions as Semantic Anchors: A Best Practice in OHDSI Phenotype Development*. *OHDSI Phenotype Development and Evaluation Workgroup Consensus Statement*; 2025.
3. **Rao GA, et al.** *Neuro-Symbolic Conceptual Workflows for Phenotyping in Observational Research: The Proposer-Validator Architecture*. *OHDSI Phenotype Development and Evaluation Workgroup*; 2026.
4. **Rao GA.** *OHDSI Phenotype Library Version 3.0: An Agentic Architecture for Autonomous Governance*. 2026 OHDSI Global Symposium Collaborator Showcase, New Brunswick, NJ, October 2026.
5. **Ostropolets A, et al.** *PHOEBE 2.0: selecting the right concept sets for the right patients using lexical, semantic, and data-driven recommendations*. *OHDSI Symposium*; 2022. (Available: https://www.ohdsi.org/wp-content/uploads/2022/10/6-Ostropolets_Phoebe2.0-abstract.pdf).
6. **Bandeian SH, Rao G, Grannis S, Overhage JM.** *TAXIS: Building an OMOP-Native Clinical Relationship Layer to Support Reusable OHDSI Analytics*. 2026 OHDSI Global Symposium Collaborator Showcase (Entry #127), New Brunswick, NJ, October 2026.


