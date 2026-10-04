# TAXIS: Transparent Analytic Knowledge Graph for Interoperable Science

[![Build Status](https://github.com/ohdsi-studies/Taxis/workflows/R-CMD-check/badge.svg)](https://github.com/ohdsi-studies/Taxis/actions?query=workflow%3AR-CMD-check)
[![Study Status](https://img.shields.io/badge/Study%20Status-Active-brightgreen.svg)](https://github.com/ohdsi-studies/Taxis)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![OHDSI 2026 Symposium](https://img.shields.io/badge/OHDSI%202026%20Symposium-Showcase%20%23127-blue.svg)](docs/symposium_2026/README.md)

---

> ### 2026 OHDSI Global Symposium Collaborator Showcase (Entry #127)
> **Dates**: October 20–22, 2026  
> **Venue**: Hyatt Regency New Brunswick, New Brunswick, NJ  
> **Deliverables**:  
> - [Showcase #127 Brief Report Manuscript v6.0](docs/symposium_2026/TAXIS_Brief_Report_v6.md) (4-page submission text)  
> - [48"x36" Digital Poster Presentation Guide](docs/symposium_2026/Poster_Presentation_Guide.md) (tri-panel layout & walkthrough script)  
> - [2026 Symposium Dissemination Overview](docs/symposium_2026/README.md)  
> **Study Leadership**:  
> - **Stephen H. Bandeian, MD, JD** – Principal Investigator, Johns Hopkins University School of Medicine (Original SQL & Analytic Code Author)  
> - **J. Marc Overhage, MD, PhD** – Co-Principal Investigator, The Overhage Group / Indiana University School of Medicine  
> - **Gowtham Rao, MD, PhD** – Investigator, CoReason, Inc. USA; OHDSI Phenotype Development & Evaluation Workgroup  
> - **Shaun Grannis, MD, MS** – Investigator, Regenstrief Institute / Indiana University School of Medicine  

---

## Scientific and Epidemiological Rationale

A central methodological challenge in observational health research, pharmacoepidemiology, and real-world evidence generation is characterizing how clinical events empirically co-occur and temporally associate across longitudinal patient care. Standard biomedical vocabularies and controlled ontologies—such as SNOMED-CT, RxNorm, and LOINC—provide hierarchical classifications based on formal nosology, pharmacologic class, and laboratory analytes. They classify what clinical entities *are* (for example, establishing that metformin is a biguanide antihyperglycemic agent, or that type 2 diabetes mellitus is a disorder of endocrine metabolism). However, these ontologies were not constructed to model how clinical care is operationalized in real-world practice. They do not specify which diagnostic laboratory assays are routinely ordered to achieve clinical confirmation, which pharmacotherapies constitute empirical first-line regimens, or which prodromal signs and symptoms precede formal diagnostic recording.

Empirical investigation underscores this ontology-practice gap. In an analysis of 26,901 frequently co-occurring clinical concept pairs mined across 2.16 million longitudinal patient records in the Indiana Network for Patient Care (INPC), standard biomedical ontologies documented an explicit clinical relationship for only 119 pairs (0.44%). The remaining 99.56% of real-world clinical relationships were completely absent from formal terminology models.

To address this structural gap, the **TAXIS** (*Transparent Analytic Knowledge Graph for Interoperable Science*) network study was established. TAXIS provides an empirical, data-driven association and temporal directionality layer across OMOP Common Data Model (CDM v5.4) databases. Our core focus is engineering, releasing, maintaining, and conducting an international OHDSI network study across heterogeneous health systems. By executing standardized association mining across federated network partners, TAXIS computes comprehensive summary datasets of concept A–B pairs—quantifying joint co-occurrence counts, temporal sequence directionality, and crude and healthcare utilization-stratified lift metrics—which are disseminated as an open, public scientific resource for the observational research community.

---

## Methodological Positioning in Observational Research

To establish clear architectural boundaries: **TAXIS is an empirical association mining engine and OHDSI network study package; it is not an end-user cohort algorithm builder or negative control selector application.** TAXIS provides the foundational empirical data infrastructure upon which advanced informatics tools can be developed.

Within this repository, the primary deliverable is the execution-ready network study package and its underlying association engine. The multi-site study computes standardized concept A–B pair summaries across participating observational databases. In addition, this codebase provides proof-of-concept demonstrations illustrating how translational informatics applications can leverage the empirical concept-pair resource:

### 1. Computable Cohort Specification
We demonstrate proof-of-concept workflows showing how TAXIS empirical associations can inform standardized OHDSI Circe JSON cohort definitions. Rather than relying solely on manual vocabulary curation to enumerate relevant diagnostic markers, co-prescribed therapies, or diagnostic mimics, downstream systems can query the TAXIS empirical layer to surface clinically associated entities. In this repository, our demonstration pipeline illustrates how these entities can be mapped into Circe cohort expressions aligned with peer-reviewed OHDSI Clinical Descriptions for expert clinical review.

### 2. Empirical Negative Control Selection
Negative control outcomes are essential for empirical calibration and residual systematic error quantification in observational study designs. However, selecting valid candidate controls with genuine biological and clinical independence remains challenging. While TAXIS does not ship an interactive selection application, its empirical association matrix provides a systematic foundation for negative control discovery. By querying our computed concept-pair datasets, investigators can identify concept pairs demonstrating clinical independence across multiple healthcare databases to generate candidate control batteries for expert clinical review.

### 3. Epidemiological Study Design & Confounder Selection
In comparative cohort and case-control studies, distinguishing baseline confounders from intermediate mediators or post-baseline colliders is critical for valid causal inference. Because TAXIS tracks both clinical relationship taxonomy and temporal sequence directionality (evaluating whether exposure concept A reliably precedes outcome concept B), the empirical layer assists epidemiologists in identifying true common-cause covariates while safeguarding against conditioning on intermediate causal pathways.

### 4. Interpretation of Distributed Network Evidence
When distributed network studies identify unexpected drug-outcome or disease-disease associations across federated databases, evaluating epidemiological validity requires clinical context. TAXIS provides quantitative empirical metrics to help investigators differentiate authentic clinical associations from confounding by indication, protopathic bias (treatment initiation during undiagnosed prodromal disease stages), or surveillance artifacts.

---

## Proof-of-Concept: Demonstrating How TAXIS Informs Cohort Definitions

A central initiative within the OHDSI Phenotype Development and Evaluation Workgroup is addressing phenotypic misclassification and coding artifacts in electronic health record (EHR) and administrative claims data. In emergency and acute care settings, diagnostic workups frequently generate provisional rule-out diagnostic billing codes. For instance, an acute encounter evaluating chest pain may record an acute myocardial infarction billing code solely because electrocardiography and cardiac biomarkers were ordered, even when serial enzymes are negative and the patient is discharged with gastroesophageal reflux disease. In ambulatory settings, historical conditions frequently persist on active problem lists due to EHR documentation inertia and clinical note replication. Algorithms relying strictly on unconstrained diagnostic codes risk substantial false-positive misclassification and impaired specificity.

To demonstrate how empirical association data can inform phenotype engineering, our proof-of-concept pipeline structures clinical logic across six functional clinical building blocks:
1. **Primary Index Condition**: The core incident diagnosis defining the initial qualifying event.
2. **Clinical Presentation & Prodrome**: Presenting signs, symptoms, and clinical complaints characterizing early disease presentation.
3. **Confirmatory Diagnostic Biomarkers**: Objective laboratory measurements and diagnostic imaging procedures ordered to verify the clinical diagnosis.
4. **Disease-Specific Therapeutics**: Pharmacotherapies and procedural interventions initiated upon diagnostic confirmation, which provide strong discriminatory power against unconfirmed rule-out evaluations.
5. **Clinical Sequelae & Progression**: Longitudinal complications, secondary organ manifestations, and disease progression events occurring during follow-up.
6. **Differential Diagnoses & Diagnostic Mimics**: Competing clinical conditions sharing symptomatic features that warrant explicit rule-out exclusion logic.

By demonstrating how empirical concept-pair associations map into these six functional clinical slots, we illustrate how translational tools can synthesize transparent, auditable cohort definitions from our forthcoming public data release.

```text
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

## The Technical Engine Behind TAXIS

TAXIS is built on three foundational technical pillars:

### 1. Large-Scale Association Mining (Pipeline v57)
The core statistical engine of TAXIS—conceived, designed, and authored by Dr. Stephen H. Bandeian—analyzes longitudinal patient records across multiple clinical domains (conditions, procedures, devices, drugs, measurements, and observations). To evaluate large-scale observational cohorts while preserving database performance and preventing resource exhaustion, the engine partitions patient populations into 40 balanced, hash-derived partitions, computes empirical co-occurrence matrices within configurable risk intervals, and controls for healthcare utilization confounding to prevent surveillance frequency from biasing association estimates.

In the production benchmark on the Indiana Network for Patient Care (INPC), the engine analyzed 2,157,525 patients across 11,299,055 person-years and 1.88 billion fact events, screening 5.52 million high-support pairs and deriving 1.9 million graded clinical knowledge edges.

We have verified this complete three-phase pipeline (`concept_ab_init.sql`, `concept_ab_batch.sql`, `concept_ab_finalize.sql`) natively on PostgreSQL. The execution completed all 250 batch statements and 58 finalization steps, populating 43 analytical tables and identifying 9,118 candidate concept pairs in master table `cab_s55_pair_all`. Every execution generates an audit receipt recording dynamic SHA-256 SQL digests, database run IDs, and verified known-answer checks against raw CDM fact tables.

### 2. The Clinical Knowledge Graph (Taxonomy v6.0)
Statistical co-occurrence in observational data indicates association rather than clinical etiology. To assign explicit clinical semantics, TAXIS incorporates a 112-code clinical relationship taxonomy organized across five core relationship families: causal and pathophysiological mechanisms, clinical manifestations and symptoms, diagnostic laboratory and procedural evaluations, therapeutic interventions, and differential diagnostic mimics. An ensemble of clinical models evaluates co-occurring concept pairs, assigns structured taxonomy codes and empirical evidence grades, and documents the clinical rationale for each relationship.

For an overview of the clinical concept-pair taxonomy, its scientific provenance (Dr. Stephen H. Bandeian's concept-pair architecture and Dr. J. Marc Overhage's clinical validation architecture), and empirical metric coordination, see the [TAXIS Clinical Pair Taxonomy Overview](docs/knowledge_graph/TAXONOMY_OVERVIEW.md).

### 3. Demonstrating Downstream Applications
While our primary focus is releasing and maintaining TAXIS as a network study package, this repository includes proof-of-concept applications and packages illustrating how TAXIS data can be consumed by downstream tools:
- **`Taxis` (this package)**: The core network study package. It executes the large-scale association mining pipeline across local CDM databases and packages privacy-preserving, cell-suppressed aggregate results to help build our public concept pair resource.
- **Concept Pair Classifier Demo (`extras/applications/concept_pair_classifier/`)**: A working proof-of-concept application demonstrating how downstream analytical workflows query mined pairs (`cab_s55_pair_all`), compute continuity-corrected Directionality Ratios, and categorize associations into candidate clinical relationship classes.
- **`TaxisPhenotypeCreator`**: A companion proof-of-concept package showing how clinical descriptions and empirical graph edges could be translated into standards-compliant Circe JSON cohort definitions.
- **`TaxisPhenotypeEvaluation`**: A companion evaluation package demonstrating how to assess cohort diagnostics and evaluate overlap against OHDSI Phenotype Library definitions across partner databases.

### 4. Downstream Application Integration Concepts
TAXIS generates standardized empirical association summaries that can serve as an objective data resource for downstream authoring and evaluation frameworks across the OHDSI ecosystem:
- **Generative AI & Review Systems**: Supplies empirical co-occurrence matrices, continuity-corrected Directionality Ratios ($DR$), and temporal lag decay windows as grounding context for concept set curation tools and clinical review pipelines, reducing reliance on ungrounded lexical matching.
- **Programmatic & Analytical Frameworks**: Provides pre-computed pair counts and marginal summaries that can accelerate query compilation in **Capr** (HADES R domain-specific language) and **ATLAS 3.0** analytical caches (TrexSQL DuckDB).

For conceptual integration blueprints and architectural patterns, see the [TAXIS Downstream Tool Integration Blueprint](docs/phenotyping/TAXIS_COHORT_AND_CONCEPT_SET_BUILDER_ECOSYSTEM.md).

---

## Empirical Validation and Benchmarks

We evaluated the performance of TAXIS across several independent benchmarks:

| Evaluation Dimension | Benchmark Reference Set | Observed Performance | Clinical & Methodological Significance |
|---|---|---|---|
| **Semantic Edge Existence** | ClinVec Clinician Relevance Panel (1–5 ratings) | **AUC 0.81** (95% CI: 0.79–0.83) | Discriminates clinically validated associations from non-specific co-occurrences. |
| **Temporal Precedence** | PACES Clinical Benchmark | **99% Directional Concordance** | Accurately establishes temporal precedence between clinical interventions and underlying disorders. |
| **Blinded Physician Review** | 291 Blinded INPC Pair Reviews | **88% Broad Group Agreement**<br>(58% Exact Taxonomy Code) | Demonstrates high inter-rater reliability across primary clinical relationship categories. |
| **Cohort Overlap** | OHDSI Phenotype Library Circe Cohorts | **Jaccard: 0.97 – 0.995** | Exhibits high phenotypic concordance and cohort membership overlap for chronic cardiometabolic and respiratory phenotypes. |
| **Vocabulary Coverage** | SNOMED-CT / UMLS Native Relationships | **0.4% Documented Pairs** | Confirms the paucity of operational clinical relationships in standard terminologies, establishing the necessity of an empirical association layer. |

---

## Data Governance and Patient Privacy

TAXIS operates strictly under a federated, code-to-data model designed to respect institutional firewalls and patient privacy:
1. **Federated Local Execution**: Analytical pipelines execute entirely within the institutional environment.
2. **Zero Transmission of Person-Level Data**: Patient identifiers, individual-level health records, and granular concept-pair co-occurrence matrices remain strictly local.
3. **Mandatory Small-Cell Suppression**: Cell counts $<5$ are masked to -1, with complementary suppression applied to derived statistics to prevent algebraic identity disclosure.
4. **Auditable Aggregate Export Archive**: The export routine packages strictly allowlisted summary tables and execution logs into an auditable archive (`Results_Mining_<databaseId>.zip`) for local investigator inspection prior to transmission.

For institutional governance details, review the [TAXIS Network Study Protocol v1.0](docs/protocol/TAXIS_NETWORK_STUDY_PROTOCOL_V1.md) and the companion [TAXIS Network Data Use Term Sheet](docs/governance/TAXIS_NETWORK_DATA_USE_TERM_SHEET.md).

---

## Getting Started: Running TAXIS on Your OMOP CDM

Executing the TAXIS network study package on an OMOP Common Data Model instance follows standard OHDSI execution protocols:

### 1. Prerequisites
- **R (version 4.0 or higher)**
- **Java Runtime Environment (64-bit JRE 8, 17, or 21)** with `JAVA_HOME` set
- **DatabaseConnector JDBC driver** for your target database platform
- **Database permissions**: Read access to your OMOP CDM and vocabulary tables, read access to the 6 pre-loaded TAXIS reference tables (`concept_ab_vocab`), and write access to a dedicated results schema.

### 2. Configure Your Connection
Open `extras/CodeToRun.R` and configure your database connection details and schema names:
```r
library(Taxis)
library(DatabaseConnector)

connectionDetails <- createConnectionDetails(
  dbms         = "postgresql",
  server       = "localhost/my_cdm",
  port         = 5432,
  user         = "my_user",
  password     = "my_password",
  pathToDriver = "C:/drivers"
)

cdmDatabaseSchema      <- "cdm"
projectReferenceSchema <- "concept_ab_vocab" # Contains the 6 reference lookup tables
resultsDatabaseSchema  <- "taxis_results"    # Output tables will be created here
databaseId             <- "MySite"
outputFolder           <- file.path(getwd(), "taxis_output")
```

### 3. Execute and Export
Run the pipeline:
```r
Taxis::execute(
  connectionDetails      = connectionDetails,
  cdmDatabaseSchema      = cdmDatabaseSchema,
  resultsDatabaseSchema  = resultsDatabaseSchema,
  projectReferenceSchema = projectReferenceSchema,
  outputFolder           = outputFolder,
  databaseId             = databaseId,
  batchCount             = 40,
  partialRunBatchLimit   = 40
)
```
Upon pipeline completion, the aggregate summary archive `Results_Mining_<databaseId>.zip` is generated in the output directory for local audit and study transmission.

---

## Repository Layout

```text
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
│   ├── phenotyping/             # Cohort & concept set builder ecosystem (Atlas 3.0, Pythia, Capr, LLM agents)
│   └── validation/              # ClinVec empirical benchmark and concordance results
├── extras/                      # Multi-site study packages and execution drivers
│   ├── CodeToRun.R              # Push-button network execution driver for root Taxis package
│   ├── TaxisPhenotypeEvaluation/# Standalone HADES study package for phenotype evaluation
│   └── TaxisPhenotypeCreator/   # Standalone HADES R package for automated Circe phenotype creation
├── examples/                    # Sanitized output schemas and reference data
└── README.md                    # Repository overview and entry point
```

---

## Study Leadership and Attribution

TAXIS is led by an interdisciplinary team from Johns Hopkins University, Indiana University, the Regenstrief Institute, and CoReason:
- **Stephen H. Bandeian, MD, JD** – Principal Investigator, Johns Hopkins University School of Medicine (Original SQL & Analytic Code Author)
- **J. Marc Overhage, MD, PhD** – Co-Principal Investigator, The Overhage Group / Indiana University School of Medicine
- **Gowtham Rao, MD, PhD** – Investigator, CoReason, Inc. USA; OHDSI Phenotype Development & Evaluation Workgroup
- **Shaun Grannis, MD, MS** – Investigator, Regenstrief Institute / Indiana University School of Medicine

### Citation
If you use TAXIS in your research, please cite:
> Bandeian SH, Rao G, Grannis S, Overhage JM. *TAXIS: Building an OMOP-Native Clinical Relationship Layer to Support Reusable OHDSI Analytics*. 2026 OHDSI Global Symposium Collaborator Showcase (Entry #127), New Brunswick, NJ, October 2026.

### Foundational References:
1. **Bandeian S, Tompkins CP, Davison A.** *A Future Health Care Analytic System: Part 1—What the Destination Looks Like & Part 2—Building Blocks and Implementation Roadmap*. In: Kiel JM, Kim GR, Ball MJ, eds. *Healthcare Information Management Systems: Cases, Strategies, and Solutions*. 5th ed. Springer; 2022:401-440.
2. **Donabedian A.** *Evaluating the quality of medical care*. *Milbank Q*. 1966;44(3):166-206.
3. **Prentice RL.** *Surrogate endpoints in clinical trials: definition and operational criteria*. *Stat Med*. 1989;8(4):431-440.
4. **VanderWeele TJ.** *Explanation in Causal Inference: Methods for Mediation and Interaction*. Oxford University Press; 2015.
5. **Rao GA.** *OHDSI Phenotype Library Version 3.0: An Agentic Architecture for Autonomous Governance*. 2026 OHDSI Global Symposium Collaborator Showcase, New Brunswick, NJ, October 2026.
6. **Ostropolets A, et al.** *PHOEBE 2.0: selecting the right concept sets for the right patients using lexical, semantic, and data-driven recommendations*. *OHDSI Symposium*; 2022.
7. **Swerdel JN, Hripcsak G, et al.** *PheValuator: Development and evaluation of a phenotype evaluation tool*. *J Biomed Inform*. 2019;99:103294.
8. **Schuemie MJ.** *PhenotypingAgent: Autonomous Cohort Development via LangGraph State Machine*. OHDSI Community GitHub Repository, 2026.
9. **Schuemie MJ.** *ConceptSetCondenser: Optimal Concept Set Expression Generation*. OHDSI Community GitHub Repository, 2025.
10. **Shoaibi A, Ostropolets A, Weaver J, Rao G, et al.** *Variation in phenotype definitions in observational clinical research: a review of three conditions*. *AMIA Annu Symp Proc*. 2024.
11. **Shoaibi A, Ostropolets A, Murphy JD, Rao GA, et al.** *Clinical Descriptions as Semantic Anchors: A Best Practice in OHDSI Phenotype Development*. *OHDSI Phenotype Development and Evaluation Workgroup Consensus Statement*; 2025.
12. **Rao GA, et al.** *Neuro-Symbolic Conceptual Workflows for Phenotyping in Observational Research: The Proposer-Validator Architecture*. *OHDSI Phenotype Development and Evaluation Workgroup*; 2026.

---

## Contact & Community Engagement

- **OHDSI Forums**: [TAXIS Study Discussion](https://forums.ohdsi.org/u/TAXIS)
- **Workgroups**: OHDSI Phenotype Development & Evaluation Workgroup
- **Issue Tracker**: Propose enhancements or report issues via [GitHub Issues](https://github.com/ohdsi-studies/Taxis/issues).
