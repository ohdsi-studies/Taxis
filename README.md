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
> - **Stephen H. Bandeian, MD, JD** – Principal Investigator, Johns Hopkins University School of Medicine (Author of all SQL & Analytic Code)  
> - **J. Marc Overhage, MD, PhD** – Co-Principal Investigator, The Overhage Group / Indiana University School of Medicine  
> - **Gowtham Rao, MD, PhD** – Investigator, CoReason, Inc. USA; OHDSI Phenotype Development & Evaluation Workgroup  
> - **Shaun Grannis, MD, MS** – Investigator, Regenstrief Institute / Indiana University School of Medicine  

---

## Scientific Rationale: The Ontology-Practice Gap

Standard biomedical vocabularies—such as SNOMED-CT, RxNorm, and LOINC—classify what clinical entities *are* based on formal nosology, chemical class, and laboratory analytes (e.g., establishing that metformin is a biguanide or that type 2 diabetes is an endocrine disorder).

However, observational health research requires knowing how clinical care is operationalized in real-world practice—such as which confirmatory lab confirms a diagnosis, which medication represents guideline-recommended therapy, or which syndrome represents a diagnostic mimic. Because standard vocabularies were designed for nosology rather than longitudinal care patterns, researchers building phenotype definitions or selecting covariates face substantial ambiguity, contributing to up to a **tenfold variation in cohort sizes** across published observational studies for the identical clinical condition (Shoaibi et al., AMIA 2024).

When this disconnect was empirically evaluated across an audited sample of 26,901 frequently co-occurring EHR concept pairs ($N_{AB} \ge 100$) mined from 2.16 million patient records in the Indiana Network for Patient Care (INPC), standard biomedical ontologies documented explicit relationships for only **0.44%** of pairs (119 pairs, of which 72 were simple hierarchical *is-a* links). The remaining 99.56% of these frequently co-occurring pairs had no relational links in standard terminologies, demonstrating that researchers cannot rely on vocabularies alone to identify real-world clinical connections.

To bridge this operational gap, the **TAXIS** (*Transparent Analytic Knowledge Graph for Interoperable Science*) network study was established. Rather than treating raw co-occurrences as clinical truth, TAXIS combines empirical association mining with temporal precedence analysis and a structured two-stage clinical taxonomy, with early analyses indicating an **AUC of 0.81** against clinician relevance ratings on curated benchmark pairs (ClinVec) and **Jaccard similarities of 0.97 to 0.995** in preliminary single-site evaluations recreating three target OHDSI Phenotype Library definitions. Our core focus is engineering, releasing, and maintaining an international OHDSI network study across heterogeneous health systems to generate open, public concept-pair summary datasets for the observational research community.

---

## Methodological Scope: Core Package vs. Downstream Proofs of Concept

To establish clear operational boundaries (`DEC-GR-027`): **TAXIS is an empirical association mining engine and OHDSI network study package; it is not an end-user cohort algorithm builder or negative control selector application.**

The primary deliverable of this repository is the execution-ready network study package and its underlying association engine. Downstream applications in this codebase (such as Circe cohort generation in `extras/`) are proofs of concept demonstrating potential utility:
1. **Richer Phenotype Definitions**: Surfaces commonly co-occurring lab tests, typical medications, and similar conditions to help refine computable cohort definitions.
2. **Candidate Negative Controls**: Identifies clinical concepts that rarely co-occur across databases to propose candidate negative controls for clinical review.
3. **Smarter Confounder Selection**: Knowing which event occurred first helps researchers review candidate baseline variables (present before treatment) and avoid adjusting for intermediate steps caused by the treatment; causal relevance requires study-specific clinical evaluation.
4. **Context for Unexpected Signals**: Provides baseline co-occurrence benchmarks so investigators can determine whether an unexpected drug-outcome link reflects clinical reality or high healthcare utilization.

---

## How TAXIS Works: The 3-Step Pipeline

```text
┌───────────────────────────────┐      ┌───────────────────────────────┐      ┌───────────────────────────────┐
│       STEP 1: MINING          │      │    STEP 2: DIRECTIONALITY     │      │       STEP 3: UTILITY         │
│  "Which clinical events       │ ───► │  "Which clinical event        │ ───► │  "Use empirical summaries     │
│   co-occur in patient care?"  │      │   typically occurs first?"    │      │   to inform phenotype review" │
└───────────────────────────────┘      └───────────────────────────────┘      └───────────────────────────────┘
  • Evaluates 6 domain pairs             • Measures calendar sequence           • Surfaces candidate labs
  • 10 utilization strata adjust           via Directionality Ratio (DR)        • Surfaces candidate drugs
    for healthcare contact bias          • Observational timing clue, not       • Surfaces candidate mimics
                                           proof of biological causation          for clinician review
```

### Step 1: Pair Association Mining (Pipeline v57)
Conceived, designed, and authored by Dr. Stephen H. Bandeian, the mining engine partitions patient populations into 40 balanced hash partitions to analyze large-scale cohorts without database exhaustion. It evaluates pairwise co-occurrences across six clinical domain intersections: `Condition–Drug`, `Condition–Measurement`, `Condition–Procedure`, `Condition–Condition`, `Drug–Procedure`, and `Drug–Drug`.
- **Controlling for Healthcare Contact Density**: Very sick or hospitalized patients visit doctors frequently and accumulate disproportionately more codes across all domains. To prevent contact density from biasing association metrics, TAXIS stratifies patients into ten deciles of baseline healthcare utilization and computes Cochran-Mantel-Haenszel (CMH) stratified lift alongside crude lift.
- **Detailed Specification**: For full mathematical derivations (Poisson exact confidence bounds, Wilson-Hilferty cube-root transformations, and SQL crosswalks), consult the [Concept AB Mining Engine Technical Specification](docs/mining/CONCEPT_AB_MINING_ENGINE_V57.md).

### Step 2: Temporal Precedence (Directionality Ratio)

> **A Concrete Worked Example**: Suppose we evaluate a Condition (A) and a Diagnostic Lab (B) over a configured 30-day follow-up window. In our longitudinal records, we observe 30 paired-event occurrences where Lab B follows Condition A, and 10 paired-event occurrences where Lab B precedes Condition A. Using our continuity-corrected formula, the Directionality Ratio is $DR = (30 + 0.5) / (10 + 0.5) = 30.5 / 10.5 = 2.90$. Events occurring on the exact same day ($N_{A=B}$) are counted separately. This ratio describes empirical calendar sequence in health records—indicating that the test was usually recorded after the diagnosis—providing an empirical candidate for clinical review rather than biological proof of disease confirmation.

To evaluate the longitudinal sequence between two concepts $(A, B)$, TAXIS checks calendar ordering:
- $O_{\text{after}}$: Number of paired event occurrences where Concept A predates Concept B within the configured follow-up window (configurable parameter `win_w`, e.g., 182-day package default, 35-day synthetic harness, or 30-day study window). (Note: released SQL distinguishes paired event counts $O_{\text{after}}$ from distinct person counts $P_{\text{after}}$).
- $O_{\text{before}}$: Number of paired event occurrences where Concept B predates Concept A.
- **Directionality Ratio ($DR$)**:
  $$DR = \frac{O_{\text{after}} + 0.5}{O_{\text{before}} + 0.5}$$
  - $DR \ge 1.50$: Concept A empirically precedes Concept B in longitudinal records.
  - $DR \le 0.67$: Concept B empirically precedes Concept A.
  - $0.67 < DR < 1.50$: Forward and reverse event occurrences are of comparable magnitude (balanced temporal ordering, distinct from same-day synchrony $N_{A=B}$).
- *Epidemiological Boundary*: Calendar sequence shows which event was recorded first in routine care. While useful for phenotyping, it reflects clinical documentation patterns rather than biological proof of causation (for example, diagnostic delays or treatments prescribed before formal diagnosis coding). Causal relevance requires study-specific clinical evaluation.

### Step 3: Clinical Phenotyping Utility
TAXIS measures how often paired events are recorded and their order within a specified time window. These summaries can help researchers identify candidate concepts to review when developing phenotype definitions:
1. **Candidate Biomarkers**: Mined lab tests with high co-occurrence and same-day timing (e.g., HbA1c for Diabetes) to review for diagnostic criteria.
2. **Candidate Medications**: Treatments that empirically follow the diagnosis (e.g., Metformin following Diabetes) to review for treatment-enriched definitions.
3. **Candidate Diagnostic Mimics**: Competing clinical conditions sharing symptomatic features that researchers can review for rule-out exclusion logic.

---

## Repository Scope: Current Status Matrix

To maintain clear scientific and operational boundaries (`DEC-GR-027`), TAXIS is fundamentally an association mining engine and network study package, not an end-user cohort builder application.

| Capability / Component | Operational Status | Primary Location | Scope & Governance Notes |
|---|:---:|---|---|
| **Pipeline v57 Association Mining** | **Released (SQL Engine)** | [`inst/sql/sql_server/`](inst/sql/sql_server/), [`R/RunMining.R`](R/RunMining.R) | Dr. Stephen H. Bandeian's core 40-batch SQL engine. Verified on local synthetic PostgreSQL fixture. |
| **Small-Cell Suppression ($<5 \to -1$)** | **Released (Export Contract)** | [`R/PackageMiningResults.R`](R/PackageMiningResults.R) | Enforces mandatory $<5 \to -1$ masking on 6 summary tables with companion-field suppression; verified in export harness. |
| **Network Package Driver** | **Released (R Package)** | [`R/Main.R`](R/Main.R), [`extras/CodeToRun.R`](extras/CodeToRun.R) | Push-button study runner (`runConceptMining()`, `packageMiningResults()`); tested in local synthetic harness. |
| **Concept Pair Classifier Demo** | **Demonstration Prototype** | [`extras/applications/concept_pair_classifier/`](extras/applications/concept_pair_classifier/) | Illustrative script showing how downstream tools query `cab_s55_pair_all`. |
| **Circe Phenotype Creator (`build_1032.py`)** | **Demonstration Prototype** | [`extras/TaxisPhenotypeCreator/`](extras/TaxisPhenotypeCreator/) | Proof of concept compiling concept pairs into Circe JSON cohort expressions. |
| **Phenotype Evaluation Package** | **Demonstration Prototype** | [`extras/TaxisPhenotypeEvaluation/`](extras/TaxisPhenotypeEvaluation/) | Standalone companion package evaluating cohort overlap and Semi-Automated Phenotype Performance Evaluation with PheValuator. |
| **ATLAS v3.0 / Pythia Integration** | **[Proposed Future Blueprint]** | [`docs/phenotyping/`](docs/phenotyping/) | Conceptual architecture for TrexSQL DuckDB caches and AI agent tools. |
| **Multi-Site Federated Meta-Analysis** | **[Proposed Future Blueprint]** | [`docs/mining/`](docs/mining/) | Proposed random-effects synthesis specification (synthetic arithmetic benchmark in `extras/`). |

---

## Empirical Validation and Benchmarks

We evaluated the performance of TAXIS across several independent benchmarks:

| Evaluation Dimension | Benchmark Reference Set | Observed Performance | Clinical & Methodological Significance |
|---|---|---|---|
| **Semantic Edge Existence** | ClinVec Clinician Relevance Panel (1–5 ratings) | **AUC 0.81** (95% CI: 0.79–0.83) | Discriminates clinically validated associations from non-specific co-occurrences. |
| **Temporal Precedence** | PACES Clinical Benchmark | **99% Directional Concordance** | Accurately establishes temporal precedence between clinical interventions and underlying disorders. |
| **Blinded Physician Review** | 291 Blinded INPC Pair Reviews | **88% Broad Group Agreement**<br>(58% Exact Taxonomy Code) | Demonstrates high inter-rater reliability across primary clinical relationship categories. |
| **Cohort Overlap** | OHDSI Phenotype Library Circe Cohorts | **Jaccard: 0.97 – 0.995** | Exhibits high phenotypic concordance and cohort membership overlap for chronic cardiometabolic and respiratory phenotypes. |
| **Vocabulary Coverage** | SNOMED-CT / UMLS Native Relationships | **0.4% Documented Pairs** | Empirically quantifies the gap between formal nosology and longitudinal EHR co-occurrence, motivating an empirical association layer evaluated across early benchmark analyses. |

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

## Study Leadership and Scientific Attribution

> ### Authorship & Intellectual Attribution Notice
> **All SQL code in TAXIS was written by Stephen H. Bandeian, MD, JD.**  
> Full credit, primary scientific authorship, and intellectual attribution for all SQL scripts (`concept_ab_init.sql`, `concept_ab_batch.sql`, `concept_ab_finalize.sql`), 40-batch random partitioning architectures, measurement key packing schemes, healthcare utilization decile stratification, continuity-corrected directionality formulations ($DR$), and underlying analytical algorithms belong entirely to **Stephen H. Bandeian, MD, JD** (Principal Investigator, Johns Hopkins University School of Medicine).

TAXIS is led by an interdisciplinary team from Johns Hopkins University, Indiana University, the Regenstrief Institute, and CoReason:
- **Stephen H. Bandeian, MD, JD** – Principal Investigator & Author of all SQL & Analytic Code, Johns Hopkins University School of Medicine
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
