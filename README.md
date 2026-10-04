# TAXIS: Transparent Analytic Knowledge Graph for Interoperable Science

[![Build Status](https://github.com/ohdsi-studies/Taxis/workflows/R-CMD-check/badge.svg)](https://github.com/ohdsi-studies/Taxis/actions?query=workflow%3AR-CMD-check)
[![Study Status](https://img.shields.io/badge/Study%20Status-Active-brightgreen.svg)](https://github.com/ohdsi-studies/Taxis)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![OHDSI 2026 Symposium](https://img.shields.io/badge/OHDSI%202026%20Symposium-Showcase%20%23127-blue.svg)](docs/symposium_2026/README.md)

---

> ### 2026 OHDSI Global Symposium Collaborator Showcase (Entry #127)
> **Dates**: October 20–22, 2026  
> **Venue**: Hyatt Regency New Brunswick, New Brunswick, NJ  
> **Showcase Deliverables**:  
> - [Showcase #127 Brief Report Manuscript v6.0](docs/symposium_2026/TAXIS_Brief_Report_v6.md) (4-page submission text)  
> - [48"x36" Digital Poster Presentation Guide](docs/symposium_2026/Poster_Presentation_Guide.md) (tri-panel layout & walkthrough script)  
> - [2026 Symposium Dissemination Overview](docs/symposium_2026/README.md)  
> **Study Leadership**:  
> - **Stephen H. Bandeian, MD, JD** – Principal Investigator, Johns Hopkins University School of Medicine (Original SQL & Analytic Code Author)  
> - **J. Marc Overhage, MD, PhD** – Co-Principal Investigator, The Overhage Group / Indiana University School of Medicine  
> - **Gowtham Rao, MD, PhD** – Investigator, CoReason, Inc. USA; OHDSI Phenotype Development & Evaluation Workgroup  
> - **Shaun Grannis, MD, MS** – Investigator, Regenstrief Institute / Indiana University School of Medicine  

---

## 1. Executive Summary & Background

**TAXIS** (*Transparent Analytic Knowledge Graph for Interoperable Science*) is an open-science OHDSI methodological research initiative that derives, structures, and evaluates clinical relationships from observational healthcare data mapped to the **OMOP Common Data Model (CDM v5.4)**.

The project name originates from the Greek ***τάξις*** (*táxis*), denoting *order*, *arrangement*, or *classification*. TAXIS investigates methods for structuring and evaluating observed relationships across longitudinal patient records.

### Background: Reusable Phenotypes in Observational Research

Observational health research often relies on bespoke, study-by-study development of cohort definitions, covariate sets, and exclusion criteria. Developing these elements independently for each investigation requires substantial effort and can limit comparability across studies.

To address this challenge, the **OHDSI Phenotype Development and Evaluation Workgroup** established the **OHDSI Phenotype Library**—advancing the vision of a centralized, open-science repository promoting the systematic reuse of peer-reviewed, computable phenotypes grounded in structured **Clinical Descriptions** (presentation, confirmatory laboratory criteria, first-line treatments, and differential exclusions).

However, authoring multi-domain phenotypes across clinical medicine remains labor-intensive:
- Across the **1,104 cohorts in the OHDSI Phenotype Library**, two-thirds remain basic single-concept code lists without logic rules.
- **Fewer than 2%** incorporate multi-domain laboratory or medication qualification criteria.
- **Terminology Characteristics**: Standard clinical vocabularies (SNOMED-CT, RxNorm, LOINC) standardize terminology (*what things are* via *is-a* hierarchies), while observational analyses often require understanding clinical relationships (*which treatments or tests associate with a given diagnosis in practice*).

| Vocabulary Domain | Standard Vocabulary Focus (*Taxonomy*) | Observational Care Context |
|---|---|---|
| **SNOMED-CT** (Conditions) | *"Type 2 Diabetes is an Endocrine Disorder"* (`is-a`) | Associated confirmatory lab test (`HbA1c > 6.5%`) |
| **RxNorm** (Drugs) | *"Metformin is a Biguanide"* (`ingredient_of`) | Associated indicated condition (`Type 2 Diabetes`) |
| **LOINC** (Measurements) | *"4548-4 measures Hemoglobin A1c in Blood"* | Role of measurement (confirmatory, monitoring, screening) |

- **Vocabulary Coverage in Observational Data**: In an analysis of **26,901 frequently co-occurring concept pairs** mined from 2.16M patient records in the Indiana Network for Patient Care (INPC) OMOP CDM:
  - Existing standard terminologies (SNOMED, RxNorm, LOINC, MED-RT, NCI, UMLS) contained a documented relationship for **119 pairs (0.4%)**.
  - Of those 119 relationships, **72 were hierarchical `is-a` subsumption links**.
  - For the remaining pairs, standard terminologies do not explicitly define operational clinical relationships (such as drug indications or laboratory confirmatory links). Where standard vocabularies do document relationships, TAXIS shows high concordance (0.99 PPV), indicating that empirical mining can complement existing vocabularies by capturing operational relationships.

### Methodological Framework

TAXIS investigates whether empirical association rule mining combined with structured clinical taxonomies can help generate and evaluate candidate cohort definitions by uniting three components:
1. **Association Rule Mining**: Applying association rule mining across **2.16 million longitudinal patient records (11.3M person-years)** in the Indiana Network for Patient Care (INPC), adjusting for observation windows and healthcare utilization frequency.
2. **Standardized Clinical Taxonomy**: Applying a 112-code clinical taxonomy to categorize observational co-occurrences into a typed clinical knowledge graph.
3. **Multi-Domain Phenotype Synthesis**: Using the resulting knowledge graph to link index conditions with associated laboratories, medications, and differential diagnoses, generating candidate Circe cohort definitions compatible with the OHDSI Phenotype Library.

---

## 2. Conceptual Applications of TAXIS: Phenotyping Workflow Optimization & Beyond

Observational health research encompasses multiple interconnected disciplines: cohort definition, negative control identification, study design, covariate selection, and evidence interpretation. **Phenotyping workflow optimization using TAXIS is one conceptual application of the TAXIS clinical knowledge layer.** While structured clinical knowledge graphs provide a computable foundation across the entire observational research lifecycle, phenotyping workflow optimization serves as the primary initial demonstration for the 2026 Collaborator Showcase.

### Areas of Methodological Application

TAXIS is designed to explore applications across four areas of observational research:

```
┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                       TAXIS METHODOLOGICAL AREAS                                       │
└───────────────────────────────────────────────────┬────────────────────────────────────────────────────┘
                                                    │
    ┌───────────────────────────┬───────────────────┴───────────────┬────────────────────────────┐
    ▼                           ▼                                   ▼                            ▼
┌───────────────────────┐   ┌───────────────────────┐   ┌───────────────────────┐   ┌───────────────────────┐
│ 1. PHENOTYPING        │   │ 2. NEGATIVE CONTROLS  │   │ 3. STUDY DESIGN &     │   │ 4. STUDY              │
│    WORKFLOW OPTIMIZ.  │   │    & CALIBRATION      │   │    CONFOUNDING REDUCT.│   │    INTERPRETATION     │
│    (INITIAL FOCUS)    │   │                       │   │                       │   │                       │
│ • Reusable cohort     │   │ • Candidate negative  │   │ • Informs study design│   │ • Contextualizing     │
│   definitions for     │   │   control outcome     │   │   choices to reduce   │   │   network study       │
│   Phenotype Library   │   │   generation          │   │   confounding         │   │   estimates           │
│ • Multi-domain "Bill  │   │ • Graph screening for │   │ • Graph-guided DAGs   │   │ • Evaluates residual  │
│   of Materials"       │   │   absence of clinical │   │   identifying true    │   │   systematic bias     │
│   (Labs, Drugs,       │   │   mechanism (Lift≈1)  │   │   confounders         │   │ • Distinguishes true  │
│   Exclusions)         │   │ • Enables empirical   │   │ • Distinguishes       │   │   effects from        │
│ • Reduces one-off     │   │   calibration battery │   │   mediators to avoid  │   │   protopathic bias or │
│   manual authoring    │   │   synthesis           │   │   over-adjustment     │   │   indication bias     │
└───────────────────────┘   └───────────────────────┘   └───────────────────────┘   └───────────────────────┘
```

1. **Phenotyping Workflow Optimization (Primary Initial Demonstration)**:
   - Supports the transition from study-by-study phenotype authoring by translating structured clinical criteria (presentation, confirmatory laboratory criteria, first-line therapies, and differential exclusions) into candidate Circe cohort definitions.
   - Complements existing vocabularies by identifying multi-domain clinical associations to support the **OHDSI Phenotype Library**.
2. **Candidate Negative Control Generation & Hypothesis Screening**:
   - Assists investigators in candidate negative control generation by querying the clinical relationship layer for concept pairs that lack documented pathophysiologic, etiologic, or therapeutic mechanisms across all 112 taxonomy codes.
   - Importantly, candidate selection is driven by substantive clinical and literature review (establishing causal independence) rather than conditioning on observed statistical nulls; baseline observational metrics (such as lift and directionality in a given dataset) are retained strictly as descriptive diagnostics. This ensures that valid negative controls exhibiting non-null observed associations due to residual confounding are preserved, allowing empirical calibration batteries to detect and quantify network systematic error.
3. **Informing Study Design Choices & Confounding Reduction**:
   - Supports comparative observational research by providing structured clinical knowledge to inform study design choices, covariate specifications, and cohort boundary definitions.
   - Leverages typed clinical relationships and temporal directionality ratios ($DR \ge 1.50$) to help investigators identify potential common-cause confounders while distinguishing intermediate mediators (to avoid over-adjustment bias) and potential colliders.
   - Complements causal inference workflows by providing explicit clinical semantics to evaluate residual confounding and guide sensitivity analyses.
4. **Network Evidence Interpretation & Residual Bias Evaluation**:
   - Provides a structured clinical knowledge layer to help contextualize network findings and evaluate potential residual bias.
   - Assists investigators in evaluating whether an observed empirical association may be influenced by confounding by indication, protopathic bias (early disease symptoms treated prior to diagnosis), or detection artifacts.

### Phenotyping Workflow Optimization: Closed-Loop Lifecycle & Evaluation

**Phenotyping workflow optimization using TAXIS represents one conceptual application of computable clinical knowledge.** TAXIS focuses its initial evaluation on cohort definition and phenotyping because:
- **Resolving the Phenotype Reproducibility Crisis**: Systematic evaluations of published observational literature across complex diseases have revealed dramatic heterogeneity in phenotype algorithms, with independent research teams producing up to a **tenfold difference in cohort sizes** for the identical target condition (Shoaibi et al., AMIA 2024).
- **Clinical Descriptions as Semantic Anchors**: To eliminate subjective ambiguity, the OHDSI community established that an *a priori* written **Clinical Description** across standardized domains (presentation, assessment, confirmatory labs, differential diagnoses/exclusions, indicated treatments) must serve as the **semantic anchor** before translating clinical intent into computable queries (Shoaibi, Ostropolets, Murphy, Rao, et al.).
- **The Neuro-Symbolic Proposer-Validator Framework**: Drawing on cognitive architecture principles (Kahneman System 1 vs. System 2) formalized for clinical informatics (Rao et al., 2026), TAXIS operationalizes a **Neuro-Symbolic Proposer-Validator Framework**:
  - **Neural / Associative Proposer (System 1)**: Traverses empirical co-occurrences mined across 2.16M longitudinal patients in the INPC OMOP CDM paired with the two-stage screen-and-code LLM ensemble (112-code taxonomy) to discover and type candidate multi-domain clinical associations, mitigating ungrounded hallucinations through empirical data grounding.
  - **Symbolic Structural Compiler & Validator (System 2)**: The automated phenotype builder (`build_1032.py`) compiles candidate relationships into formal, deterministic, and syntactically auditable Circe JSON cohort definitions structured by the Clinical Description semantic anchor. Substantive clinical validity and phenotype diagnostic performance are evaluated separately through expert clinical adjudication and empirical measurement across partner CDMs using `CohortDiagnostics` and `PheValuator`.
- **Harmonized Prompt-to-Circe Slot Mapping**: Directly ingests the OHDSI Phenotype Workgroup's standard Clinical Description schema (`clinicalDescriptionPromptBriefWithExclusions.txt`), mapping clinical prompt sections 1-to-1 into computable Circe criteria blocks:
  - *Condition Overview & Presentation* $\rightarrow$ Primary Anchor Disorder (`PrimaryCriteria.CriteriaList`).
  - *Laboratory Tests & Diagnostic Values* $\rightarrow$ Confirmatory Labs (`InclusionRules` with `Measurement` domain criteria, guideline cutoffs, and $[-7, +30]$ day windows).
  - *Medications Usually Given* $\rightarrow$ Indicated Drug Exposures (`InclusionRules` with `DrugExposure` criteria: acute $\le 24\text{h}$, chronic $\le 30\text{d}$).
  - *Differential Diagnoses & Excluded Conditions* $\rightarrow$ Rule-Out Mimics (`InclusionRules` with Occurrence = 0 or `CensoringCriteria`, strictly capped at $<10\%$ anchor patient cost).
  - *Comorbid Conditions* $\rightarrow$ Baseline Patient Characterization & Covariate Balance (explicitly segregated to prevent false exclusions).
  - *Prognosis & Follow-up* $\rightarrow$ Post-Index Observation Windows (`PostDays`) and persistence logic.
  - *References* $\rightarrow$ Circe Definition Metadata & Provenance Tags.
- **Closed-Loop Phenotype Critic via Diagnostic Frameworks**: Phenotyping offers established community validation tools (`CohortDiagnostics` and `PheValuator`) that enable continuous algorithmic refinement:
  - **CohortDiagnostics (Development & Characterization)**: Integrates standard execution of `CohortDiagnostics` to assess cohort counts, incidence rates, index event breakdowns, visit contexts, and detect **orphan concepts** omitted from initial concept sets.
  - **PheValuator (Semi-Automated Phenotype Performance Evaluation)**: Quantitatively evaluates phenotype algorithm diagnostic operating characteristics (Sensitivity, Specificity, Positive Predictive Value [PPV], Negative Predictive Value [NPV], and F1 Score with 95% Confidence Intervals) without manual chart review (*Swerdel et al., 2019*). PheValuator develops a diagnostic predictive model (via `PatientLevelPrediction` regularized logistic regression) trained on an extremely specific cohort (`xSpec`, noisy positives) and a random sample of noisy negatives (excluding `xSens`). The model assigns predicted probabilities of having the health outcome of interest across a large representative evaluation cohort (up to 2,000,000 subjects). Candidate phenotype algorithms are then evaluated against this probabilistic gold standard via continuous Expected Value (`EV`) or decision cut-points. Secondarily, feature inspection of non-zero predictive covariates and weights from the calibrated diagnostic model provides empirical feedback to identify missing clinical criteria or uncaptured mimics during exploratory development.
- **Independent Development vs. Final Evaluation Protocol**: To guard against circular overfitting—where an algorithm is iteratively tuned merely to reproduce an evaluator model rather than true clinical cases—the closed-loop refinement loop enforces a strict development-versus-evaluation boundary:
  - *Exploratory Refinement Partition*: PheValuator predictive model training and graph-matching feedback are executed exclusively on a designated exploratory development CDM or patient partition.
  - *Algorithm Freezing*: Once inclusion/exclusion criteria are finalized, the Circe JSON definition is **frozen** and versioned.
  - *Independent Validation*: Final diagnostic operating characteristics (Sensitivity, Specificity, PPV, NPV, F1 Score) and characterization metrics are evaluated on held-out test partitions or independent external partner CDMs.
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

### Phenotype Phebruary 2026: 6-Bucket Clinical Elements & Multi-Tiered Cohorts

During the **OHDSI Phenotype Development & Evaluation Workgroup's Phenotype Phebruary / Aphril 2026** initiative, the community highlighted the critical need for an empirically grounded, reproducible pipeline to solve the **Phenotyping Input Bottleneck**—namely, how to systematically construct input concept sets across distinct clinical elements without manual bespoke guesswork. Furthermore, community case adjudication using KEEPER demonstrated that diagnosis codes alone suffer from substantial false-positive contamination from Emergency Department "rule-out" visits, while genuine acute cases cluster multi-domain corroboration (confirmatory biomarkers and invasive interventions).

To operationalize these insights, TAXIS establishes:
1. **The 6-Bucket Clinical Element Slot Architecture**: Maps the 6 core clinical elements defined in Workgroup presentations directly to TAXIS association edges, temporal precedence ratios ($DR$), and Circe rules:
   - *Bucket 1 (Primary Anchor)*: Incident diagnosis of interest in inpatient/ED setting (`PrimaryCriteria`).
   - *Bucket 2 (Symptoms & Presentation)*: Non-specific co-presenting findings (`ASSOC_SYMPTOM`, `ASSOC_SIGN`) in $[-7, +1]$ days.
   - *Bucket 3 (Diagnostic Labs & Procedures)*: Confirmatory laboratory tests and diagnostic testing (`DIAG_LAB_CONFIRMATORY`, `DIAG_TEST_INDICATED`) in $[-1, +3]$ days.
   - *Bucket 4 (Therapeutic Interventions)*: Definitive event procedures (e.g., PCI, CABG) and acute pharmacotherapy (`THER_INTERVENTION_PROC`, `THER_FIRST_LINE`) in $[0, +2]$ days—the decisive separator between true cases and rule-outs.
   - *Bucket 5 (Complications & Progression)*: Downstream organ failures and clinical sequelae (`PROG_COMPLICATION`) in $[+1, +30]$ days.
   - *Bucket 6 (Alternative Diagnoses & Mimics)*: Competing causes and rule-out mimics (`ASSOC_MIMIC`, `DIAG_RULE_OUT`) in $[0, +7]$ days.
2. **Multi-Tiered Circe Phenotype Synthesis**:
   - *Tier 1 (Strict / Epidemiologic)*: Formulated as a treatment-enriched cohort requiring confirmed therapeutic interventions within $[0, +2]$ days to achieve high Positive Predictive Value (prospective target $\ge 92\%$) for comparative trials and active-comparator studies.
   - *Tier 2 (Broad / Surveillance)*: Captures hospital and emergency encounters with diagnostic work-up without restricting to invasive procedures, maximizing sensitivity (prospective target $\ge 95\%$) for disease incidence tracking.
   - *Tier 3 (PheValuator Evaluators)*: Automatically synthesizes calibrated `xSpec` (noisy positive training cases) and `xSens` (broad non-case exclusion zone preventing control contamination) cohorts to train diagnostic predictive models without manual chart review.
3. **Flagship Acute Myocardial Infarction (AMI) Case Study**: Demonstrates complete 6-bucket slot compilation for AMI across synthetic educational case vignettes, differentiating true acute events from outpatient carry-forwards and single-day emergency rule-outs.
4. **Interactive Adjudication Module for ATLAS v3.0 & Pythia**: Provides an interactive adjudication bridge ("Phinding Phenotypes with Phriends") enabling real-time slot evaluation, evidence summarization, and case certainty scoring strictly behind the institutional firewall.
Detailed specification: see [`docs/phenotyping/PHENOTYPE_PHEBRUARY_2026_TAXIS_INTEGRATION.md`](docs/phenotyping/PHENOTYPE_PHEBRUARY_2026_TAXIS_INTEGRATION.md).

---

## 3. Tripartite Technical Methodology

### Pillar 1: Empirical Association Rule Mining (Pipeline v57)

> **Original Scientific & Analytic Authorship**:  
> All SQL algorithms, database schemas, 40-batch partitioning strategies, continuity-corrected directionality formulations ($DR$), and original analytic code of the Concept AB Mining Engine (Pipeline v57) were conceived, designed, and authored by **Stephen H. Bandeian, MD, JD** (Principal Investigator, Johns Hopkins University School of Medicine).

- **Empirical Scale**: Deployed across **2.16 million longitudinal patient records** (11.3 million person-years) in the Indiana Network for Patient Care (INPC) OMOP CDM, surveying 1.88 billion clinical events across 8 domains.
- **Empirical Benchmark Tables (Tables 1–7)**:
  - *Headline Universe*: 2,157,525 patients; 11,299,055 person-years; 95,968 distinct concepts; 24 pair-type categories; 14,233,528 observed concept pairs ($N_{AB} \ge 5$); 36.1 billion event-pair observations; 4.01 billion person-pair observations.
  - *Data Sparsity*: 99.1% of theoretically possible concept pairs never co-occur (overall density 0.9%), demonstrating that observational co-occurrence acts as a powerful natural candidate filter.
  - *Screened Candidate Pairs*: 5.52 million high-support pairs ($N_{AB} \ge 100$), yielding 1.9 million clinically relevant graded knowledge edges.
  - *ClinVec Benchmark Validation*: Monotonic precision enrichment gradient rising from 47.9% (unobserved) to 61.1% (co-occurring), 82.9% ($Lift \ge 1.0$), and 92.2% ($Lift \ge 2.0$), strongly confirmed by independent clinician ratings (mean 3.88 / 5.0).
  - *Full Documentation & Concordance Audit*: See [`docs/mining/CONCEPT_AB_MINING_ENGINE_V57.md`](docs/mining/CONCEPT_AB_MINING_ENGINE_V57.md#5-empirical-benchmark-indiana-network-for-patient-care-inpc-216m-patient-run).
- **Confounding Control & Mathematical Formulations**:
  - *Chronic-Onset Hazard Windows*: Requires $\ge 365$ days of continuous baseline observation prior to incident anchor diagnoses to separate chronic etiology from acute acute-care encounters.
  - *Utilization-Decile Stratification*: Computes expected co-occurrences within patient encounter-frequency deciles (`cab_s13`, `cab_s23`, `cab_s33`, `cab_s33_mh_all`), substantially mitigating bias induced by hyper-monitored, multi-morbid patients (`DEC-GR-010`).
  - *Directionality Ratios ($DR$)*: Categorizes temporal precedence mathematically using Haldane-Anscombe continuity correction:
    $$\text{Forward Directed: } DR \ge 1.50 \quad (p < 0.01)$$
    $$\text{Reverse Directed: } DR \le 0.67 \quad (p < 0.01)$$
    $$\text{Symmetric Association: } 0.67 < DR < 1.50$$

### Pillar 2: Clinical Knowledge Graph & Ensemble Semantic Typing (Taxonomy v6.0)
- **Comprehensive Taxonomy**: 112 granular relationship codes grouped into 32 semantic families and 5 core relationship groups:
  - *Causal / Pathophysiologic* (causes, complicates, precipitates)
  - *Manifestation / Clinical Finding* (presents with, symptom of, sign of)
  - *Diagnostic & Evaluative* (indicates test, confirms diagnosis, laboratory marker)
  - *Therapeutic / Interventional* (first-line therapy, symptom mitigation, contraindication)
  - *Differential / Mimic* (shares presentation, confusable with, exclusionary mimic)
- **Two-Stage Screen-and-Code Ensemble**:
  1. *Gate Screen*: Screening models filter unrelated co-occurrences (requiring 3-of-4 consensus).
  2. *Typed Classification*: Multi-model ensemble assigns taxonomy codes, directions, qualifiers, and rationales.
- **Evidence Grading**: Edges include versioned evidence vectors and ordinal grades (**Strong**, **Moderate**, **Candidate**, **Weak**, **Refuted**). Strong and Moderate edges are prioritized for cohort evaluation.

### Pillar 3: Automated Phenotype Recreation & Multi-Database Evaluation
- **Automated Phenotype Creation Package (`TaxisPhenotypeCreator`)**: Dedicated HADES R package for translating clinical descriptions and knowledge graph association edges into standards-compliant Circe JSON cohort expressions and target DBMS SQL queries. Located in [`extras/TaxisPhenotypeCreator/`](extras/TaxisPhenotypeCreator/README.md).
- **Multi-CDM Evaluation Package (`TaxisPhenotypeEvaluation`)**: HADES-compliant R study package developed to evaluate target phenotypes against comparator cohorts from the OHDSI Phenotype Library across partner OMOP CDM databases. Located in [`extras/TaxisPhenotypeEvaluation/`](extras/TaxisPhenotypeEvaluation/README.md).
- **Concept AB Mining Network Study Package (`Taxis`)**: The root repository forms the official OHDSI Network Study Package executing Dr. Stephen H. Bandeian's 40-batch association mining engine across federated OMOP CDMs. Configured via [`extras/CodeToRun.R`](extras/CodeToRun.R).

---

## 4. Empirical Validation & Benchmarks

| Evaluation Dimension | Benchmark Reference Set | Observed Performance | Clinical & Methodological Interpretation |
|---|---|---|---|
| **Semantic Edge Existence** | ClinVec Clinician Relevance Panel (1–5 ratings) | **AUC 0.81** (95% CI: 0.79–0.83) | Discrimination between clinically relevant relationships and incidental observational co-occurrence. |
| **Temporal Precedence** | PACES Clinical Benchmark | **99% Directional Concordance** | High agreement on temporal directionality (100% on evaluated intervention–disorder pairs). |
| **Blinded Physician Adjudication** | 291 Blinded INPC Pair Reviews | **88% Broad Group Agreement**<br>(58% Exact Taxonomy Code) | Clinician agreement on primary relationship family and edge qualifiers. |
| **Cohort Overlap** | OHDSI Phenotype Library Circe Cohorts | **Jaccard: 0.97 – 0.995** | Concordance in reproducing cohort membership for evaluated phenotypes (T2DM, CKD, COPD). |
| **Vocabulary Coverage Comparison** | SNOMED-CT / UMLS Native Relationships | **0.4% Documented Pairs** | Standard terminologies document relationships for 0.4% of frequently co-occurring pairs, reflecting differing design objectives. |

---

## 5. Network Data Governance & Privacy Architecture

TAXIS operates strictly under an **aggregate-only, code-to-data** federated paradigm:
1. **Local Behind-Firewall Execution**: Study packages run locally within institutional partner environments (Johnson & Johnson, Indiana University, Columbia, Georgia Tech).
2. **Zero PHI / Cell Suppression**: No patient-level records ever leave partner firewalls. All aggregate counts $<5$ are strictly suppressed.
3. **Sensitive Pair Protection & Diagnostic Performance**: Raw concept-concept co-occurrence tables remain strictly local. Only aggregate cohort overlap indices (Jaccard) and PheValuator diagnostic performance statistics (Sensitivity, Specificity, PPV, NPV, F1 Score with 95% CIs) are exported in `Results_<db>.zip`. Evaluation cohort specifications in Phase 1 are provisional exploratory definitions pending clinician-adjudicated dedicated xSpec/xSens cohorts.
4. **Complementary Cell Protection & Error Hygiene**: Small-cell suppression ($<5$) automatically applies complementary masking to all dependent overlap ratios, contingency cells, 8 confidence intervals, and estimated prevalence (-1). Outbound error logging is restricted to bounded status codes, routing diagnostic runtime messages exclusively to private site-local logs.

Review the formal [TAXIS Network Study Protocol v1.0](docs/protocol/TAXIS_NETWORK_STUDY_PROTOCOL_V1.md), the companion [TAXIS Network Data Use Term Sheet](docs/governance/TAXIS_NETWORK_DATA_USE_TERM_SHEET.md), the [Concept AB Association Mining Engine (v57) Specifications](docs/mining/CONCEPT_AB_MINING_ENGINE_V57.md), the [TAXIS Clinical Pair Taxonomy v6.0](docs/knowledge_graph/Clinical_Pair_Taxonomy_6.md), the [Two-Stage LLM Semantic Classification Framework](examples/taxonomy/prompts_and_examples.md), the [Phenotype Recreation Engine Specifications](docs/phenotyping/Phenotype_Recreation_Engine.md), and the [ClinVec Empirical Benchmark Report](docs/validation/ClinVec_Benchmark_Results.md) for complete study design, institutional governance, SQL pipeline specifications, and semantic taxonomy catalogs.

---

## 6. Study Milestones & Methodological Roadmap

```
2024 ──────────► Sep 2025 ──────────► Q1-Q2 2026 ────────► Jul-Aug 2026 ───────► Oct 2026 ────────► 2026–2027 (Parallel Tracks)
Foundational     Network Protocol     INPC 2.16M Mining    Automated Circe       OHDSI Symposium     Track A: Library 3.0, PHOEBE, Agents & Diagnostics
Hierarchies      v0.5 Published       Taxonomy v6.0        Phenotype Builder     Showcase #127       Track B: Controls, Confounder Balance & Calib.
```

### Study Milestones:
- **2024**: Foundational diagnostic hierarchies and early pairwise co-occurrence formulations.
- **Sep 2025**: Publication of initial TAXIS Network Study Protocol (v0.5).
- **Q1–Q2 2026**: Scaled Concept AB pipeline (v57) to 2.16M INPC cohort; established Taxonomy v6.0 (112 codes).
- **Jul–Aug 2026**: Implemented automated Circe phenotype generation (`build_1032.py`) and HADES validation suite.
- **Oct 9, 2026**: Delivery of Collaborator Showcase #127 Brief Report and Digital Poster Suite to Craig Sachson.
- **Oct 20–22, 2026**: Presentation and live demonstration at the **2026 OHDSI Global Symposium** (New Brunswick, NJ).
- **Q4 2026**: Planned multi-site federated evaluation across partner CDMs.

### 2026–2027 Parallel Roadmap:

Following the 2026 symposium demonstration, TAXIS will advance across two parallel, complementary workstreams:

#### Track A: Phenotype Ecosystem Integration & Community Governance
1. **OHDSI Phenotype Library Version 3.0 Integration (Autonomous Governance)**:
   - **Automated Intake & Schema Mapping**: Connect TAXIS-generated Circe cohort definitions directly into the agentic intake pipeline of **OHDSI Phenotype Library 3.0**, enabling automated metadata annotation, documentation completeness scoring, and schema standardization.
   - **Redundancy Detection & Variant Mapping**: Leverage Library 3.0 similarity evaluation (concept set Jaccard and logic flow comparisons) to classify TAXIS-generated phenotypes as novel entities or variants of existing library cohorts.
   - **Longitudinal Semantic Monitoring**: Pair TAXIS knowledge graph updates with Library 3.0 drift detection to monitor concept obsolescence across OMOP vocabulary releases and suggest updated criteria.

2. **PHOEBE Network Prevalence Integration**:
   - **Empirical Concept Ranking**: Incorporate empirical concept prevalence counts and co-occurrence data from **PHOEBE** (PHenotype Optimization Expressed via Browser Experience) to inform concept set selection.
   - **Balancing Clinical Semantics & Real-World Frequency**: Combine TAXIS clinical relationship semantics (confirmatory labs, indicated medications, exclusionary mimics) with PHOEBE network-wide frequency data to prioritize clinically relevant concepts while avoiding ultra-rare or obsolete codes.
   - **Calibrating Exclusion Thresholds**: Utilize network concept prevalence to tune rule-out criteria, ensuring exclusions eliminate clinical mimics without excessively restricting target populations.

3. **CohortDiagnostics & PheValuator Evaluation Lifecycle**:
   - **CohortDiagnostics in Phenotype Development & Evaluation**:
     - Systematically embed `CohortDiagnostics` execution as an integral step in phenotype development and evaluation across partner OMOP CDMs.
     - Characterize candidate cohorts across index event breakdowns (identifying which concepts drive cohort entry across data sources), incidence rates, demographics, visit context (inpatient vs. outpatient proportions), and inclusion rule attrition.
     - Leverage orphan concept evaluation to identify clinically related codes within the OMOP vocabulary that were omitted from initial TAXIS concept sets, informing concept set expansion.
   - **PheValuator Semi-Automated Phenotype Performance Evaluation**:
     - Quantitatively evaluate diagnostic operating characteristics (Sensitivity, Specificity, Positive Predictive Value, Negative Predictive Value, F1 Score with 95% Confidence Intervals) across partner databases using `PheValuator` without manual chart review (*Swerdel et al., 2019*).
     - Construct probabilistic evaluation cohorts using `PatientLevelPrediction` regularized logistic regression trained on `xSpec` (extremely specific noisy positives) and noisy negatives (excluding `xSens`) with condition-specific feature extraction windows.
     - Evaluate candidate phenotype algorithms against continuous expected values (`EV`) and decision cut-points of the probabilistic evaluation cohort to benchmark performance against standard Phenotype Library definitions.
     - Secondarily, inspect non-zero predictive covariates and feature weights from the calibrated diagnostic predictive models:
       - *Positive predictive covariates* with strong weights not captured in initial criteria are cross-referenced with high-lift, high-consensus graph edges (e.g., confirmatory laboratory tests or specific therapies) to identify potential inclusion logic refinements.
       - *Negative predictive covariates* or features associated with false positives are evaluated against differential diagnosis and mimic edges (`EXCLUSIONARY_MIMIC`, `DIFFERENTIAL_DIAGNOSIS`) to calibrate rule-out criteria.
     - Enable an iterative, closed-loop cycle of phenotype refinement that harmonizes algorithmic graph traversal with empirical CDM predictive modeling while preserving strict algorithmic freezing prior to final validation.

4. **Autonomous Agentic Phenotyping & Concept Set Condensation**:
   - **Autonomous Cohort Engineering Integration**: Connect TAXIS clinical relationship queries into autonomous phenotyping agents (such as `PhenotypingAgent`) via Model Context Protocol (MCP) services. TAXIS replaces static, pre-computed concept sets with dynamic, multi-domain graph traversals across anchor conditions, confirmatory labs, indicated medications, and exclusionary mimics, while providing the clinical mechanism rationale required during agent error-profile diagnostic routines.
   - **Optimal Concept Set Expressions**: Pair TAXIS candidate concept generation with algorithmic set-covering optimization (such as `ConceptSetCondenser`) to synthesize minimal, performant Circe expressions that cover target concepts exactly without changing cohort membership, ensuring readability and computational efficiency for ATLAS and the Phenotype Library.

5. **Feedback Loop, Quality Ranking & Community Review**:
   - **Multi-Dimensional Quality Ranking**: Establish a transparent quality scoring rubric for candidate phenotypes incorporating:
     - *Graph Evidence Grade*: Confidence weighting of underlying clinical edges (Strong/Moderate consensus).
     - *Network Feasibility*: PHOEBE empirical prevalence across diverse network CDMs.
     - *Diagnostic Performance*: Standardized `CohortDiagnostics` characterization and `PheValuator` operating characteristics (Sensitivity, Specificity, PPV, NPV, F1 Score).
     - *Metadata Completeness*: Intake hygiene and documentation scores from Phenotype Library 3.0.
   - **Workgroup Peer Review**: Support human-in-the-loop review within the **OHDSI Phenotype Development and Evaluation Workgroup**, providing clinicians and epidemiologists with structured rationale and validation data to evaluate candidate definitions for official library adoption.

6. **ATLAS v3.0, Pythia AI Agent & TrexSQL Native Integration**:
   - **Pythia AI Empirical Tooling**: Author ClojureScript tools (`taxis_recommend_associations`, `taxis_get_lag_window`, `taxis_evaluate_phenotype`) for the `@ohdsi/pythia-agent` in ATLAS v3.0, grounding conversational card proposals in empirical CDM co-occurrence ($N \ge 5$), Stratified Lift, and Directionality Ratios ($DR$) rather than lexical matching or static Library regexes.
   - **TrexSQL DuckDB Query Cache Acceleration**: Ingest TAXIS pre-computed marginal and pair co-occurrence tables into TrexSQL's DuckDB cache (`TREXSQL_CACHE_PATH=/data/cache`). Enables prospective $O(1)$ dead-end query short-circuiting when zero marginal counts are certified ($N(A)=0$ or $N(B)=0$) and pruning of verified zero-marginal descendants from concept sets. When pairs are merely absent from threshold-filtered pair tables (`@cab_min_ab_obs` suppression), queries fall back safely to standard cohort SQL. These acceleration optimizations represent prospective, unbenchmarked design targets aimed at reducing Circe SQL complexity and execution overhead by up to $80\%$.
   - **ATLAS v3.0 Single-SPA UI Plugin (`@ohdsi/taxis-atlas-plugin`)**: Develop a native Vue 3 / `@ohdsi/atlas-ui` parcel providing an interactive ECharts knowledge-graph visualizer, empirical lag decay curves $[-400, +400]$ days, and one-click cohort injection via `pythiaBridge.ts`.
   - **WebMCP Browser Agent Capability Surface**: Register TAXIS capabilities into ATLAS v3 `CAPABILITIES` (`src/plugins/host/capabilities/registry.ts`) under `navigator.modelContext`, enabling in-browser AI agents and multi-agent study orchestrators to programmatically design and validate phenotypes.
   - **In-Browser Real-Time Phenotype Evaluation**: Integrate `TaxisPhenotypeEvaluation` (2x2 Jaccard Overlap and HADES `PheValuator` operating curves) directly into ATLAS v3 cohort definitions with strict small-cell suppression ($<5 \to -1$). Detailed in [TAXIS Atlas3 & Pythia Integration Architecture](docs/phenotyping/TAXIS_Atlas3_Pythia_Integration_Architecture.md).

#### Track B: Causal Study Design, Negative Controls & Error Calibration
7. **Candidate Negative Control Generation & Empirical Error Calibration**:
   - **Candidate Negative Control Hypothesis Screening**: Systematically identify candidate negative control outcomes by querying the clinical relationship layer for concept pairs with an absence of documented pathophysiologic, etiologic, or therapeutic mechanisms across all 112 taxonomy codes.
   - **Causal Null Candidacy vs. Observational Diagnostics**: Rather than conditioning candidate eligibility on observed null association in evaluation data (which risks discarding the very confounding bias calibration is meant to measure), TAXIS uses clinical relationship absence to generate causal-null candidates for independent clinical and literature review. Baseline observational metrics ($\text{Lift}$, $DR$) are reported as characterization diagnostics. Pre-specified negative control sets are then evaluated across partner CDMs to generate empirical null distributions that calibrate residual systematic error in comparative studies.

8. **Confounder Identification & Confounder Balance Evaluation**:
   - **Informing Study Design Choices**: Leverage explicit clinical relationship semantics (causal, manifestation, contraindication) to assist investigators in identifying true common-cause confounders when defining cohort inclusion and baseline covariate criteria.
   - **Protecting Intermediate Mediators & Colliders**: Use directional relationship data to differentiate intermediate variables on the causal pathway (preventing over-adjustment bias) and avoid collider conditioning.
   - **Evaluating Confounder Balance & Residual Confounding**: Complement causal inference workflows by using clinical relationship graphs to inspect whether recognized clinical confounders achieve empirical balance across treatment arms, and inform sensitivity analyses for residual unmeasured confounding.

9. **Network Evidence Adjudication & Bias Evaluation**:
   - **Contextualizing Distributed Findings**: Provide a structured clinical knowledge layer to assist investigators in evaluating observed associations across data networks.
   - **Adjudicating Alternative Explanations**: Distinguish genuine therapeutic effects from confounding by indication, protopathic bias (early manifestations treated prior to formal diagnosis), or detection artifacts.

---

## 7. Repository Organization & R Package Ecosystem
 
 ```
 ├── DESCRIPTION                  # Official OHDSI Study Package definition (Package: Taxis)
 ├── NAMESPACE                    # Package exports: execute(), runConceptMining(), packageMiningResults()
 ├── R/                           # Core R study functions for Concept AB Mining Engine
 │   ├── Main.R                   # Primary execute() entry point
 │   ├── RunMining.R              # 3-phase SqlRender pipeline orchestrator
 │   └── PackageMiningResults.R   # Non-PHI aggregate packaging with <5 suppression
 ├── inst/                        # Bundled package resources
 │   ├── sql/sql_server/          # Canonical OHDSI T-SQL scripts (init, batch, finalize)
 │   └── settings/                # Environment configuration templates
 ├── docs/                        # Public study documentation & scientific specifications
 │   ├── symposium_2026/          # 2026 OHDSI Global Symposium showcase materials
 │   ├── governance/              # Network data use agreements & privacy policies
 │   ├── protocol/                # Study protocol & design specifications
 │   ├── mining/                  # Concept AB association mining engine specifications
 │   ├── knowledge_graph/         # Clinical Pair Taxonomy v6.0 definitions
 │   ├── phenotyping/             # Automated phenotype builder specifications
 │   └── validation/              # ClinVec empirical benchmark and concordance results
 ├── extras/                      # Multi-site study packages and execution drivers
 │   ├── CodeToRun.R              # Push-button network execution driver for root Taxis package
 │   ├── TaxisPhenotypeEvaluation/# Standalone HADES study package for phenotype evaluation
 │   └── TaxisPhenotypeCreator/   # Standalone HADES R package for automated Circe phenotype creation
 ├── examples/                    # Sanitized output schemas and reference data
 └── README.md                    # Repository overview and entry point
 ```

---

## 8. Citation & Academic References

If you utilize TAXIS algorithms, knowledge graphs, or phenotype recreation packages, please cite:

> Bandeian SH, Rao G, Grannis S, Overhage JM. *TAXIS: Building an OMOP-Native Clinical Relationship Layer to Support Reusable OHDSI Analytics*. 2026 OHDSI Global Symposium Collaborator Showcase (Entry #127), New Brunswick, NJ, October 2026.

### Foundational References:
1. **Bandeian S, Tompkins CP, Davison A.** *A Future Health Care Analytic System: Part 1—What the Destination Looks Like & Part 2—Building Blocks and Implementation Roadmap*. In: Kiel JM, Kim GR, Ball MJ, eds. *Healthcare Information Management Systems: Cases, Strategies, and Solutions*. 5th ed. Springer; 2022:401-440.
2. **Donabedian A.** *Evaluating the quality of medical care*. *Milbank Q*. 1966;44(3):166-206.
3. **Prentice RL.** *Surrogate endpoints in clinical trials: definition and operational criteria*. *Stat Med*. 1989;8(4):431-440.
4. **VanderWeele TJ.** *Explanation in Causal Inference: Methods for Mediation and Interaction*. Oxford University Press; 2015.
5. **Rao GA.** *OHDSI Phenotype Library Version 3.0: An Agentic Architecture for Autonomous Governance*. 2026 OHDSI Global Symposium Collaborator Showcase, New Brunswick, NJ, October 2026.
6. **Ostropolets A, et al.** *PHOEBE 2.0: selecting the right concept sets for the right patients using lexical, semantic, and data-driven recommendations*. *OHDSI Symposium*; 2022. (Available: https://www.ohdsi.org/wp-content/uploads/2022/10/6-Ostropolets_Phoebe2.0-abstract.pdf).
7. **Swerdel JN, Hripcsak G, et al.** *PheValuator: Development and evaluation of a phenotype evaluation tool*. *J Biomed Inform*. 2019;99:103294.
8. **Schuemie MJ.** *PhenotypingAgent: Autonomous Cohort Development via LangGraph State Machine*. OHDSI Community GitHub Repository, 2026.
9. **Schuemie MJ.** *ConceptSetCondenser: Optimal Concept Set Expression Generation*. OHDSI Community GitHub Repository, 2025.
10. **Shoaibi A, Ostropolets A, Weaver J, Rao G, et al.** *Variation in phenotype definitions in observational clinical research: a review of three conditions*. *AMIA Annu Symp Proc*. 2024.
11. **Shoaibi A, Ostropolets A, Murphy JD, Rao GA, et al.** *Clinical Descriptions as Semantic Anchors: A Best Practice in OHDSI Phenotype Development*. *OHDSI Phenotype Development and Evaluation Workgroup Consensus Statement*; 2025.
12. **Rao GA, et al.** *Neuro-Symbolic Conceptual Workflows for Phenotyping in Observational Research: The Proposer-Validator Architecture*. *OHDSI Phenotype Development and Evaluation Workgroup*; 2026.

---

## 9. Contact & Community Engagement

- **OHDSI Forums**: [TAXIS Study Discussion](https://forums.ohdsi.org/u/TAXIS)
- **Workgroups**: OHDSI Phenotype & Vocabulary Workgroups
- **Issue Tracker**: Propose enhancements or report issues via [GitHub Issues](https://github.com/ohdsi-studies/Taxis/issues).

