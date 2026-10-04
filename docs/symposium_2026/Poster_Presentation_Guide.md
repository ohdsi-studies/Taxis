# TAXIS 2026 OHDSI Collaborator Showcase #127: Digital Poster Presentation Guide & Layout

> **Display Specifications**: 48" Wide × 36" High (Horizontal Landscape Format)  
> **Target Venue**: 2026 OHDSI Global Symposium Collaborator Showcase, Brunswick Ballroom / Garden State Room, Hyatt Regency New Brunswick, NJ  
> **Showcase Selection**: Entry **#127**  
> **Study Leadership**:  
> • Stephen H. Bandeian, MD, JD – Principal Investigator, Johns Hopkins University School of Medicine  
> • J. Marc Overhage, MD, PhD – Co-Principal Investigator, The Overhage Group / Indiana University School of Medicine  
> • Gowtham Rao, MD, PhD – Investigator, CoReason, Inc. USA; OHDSI Phenotype Development & Evaluation Workgroup  
> • Shaun Grannis, MD, MS – Investigator, Regenstrief Institute / Indiana University School of Medicine  
> **Governance Compliance**: `DEC-GR-002` (Showcase Submission Scope), `DEC-GR-003` (Authorship Order), `DEC-GR-005` (Aggregate-Only Non-PHI Policy)  

---

## 1. Poster Architecture Overview (48" × 36" Tri-Panel Layout)

The physical and digital presentation poster is engineered across three balanced vertical panels (15.5" wide each with 0.75" margins), crowned by an integrated 4.5" header banner:

```text
┌───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                 POSTER HEADER BANNER (48" x 4.5")                                     │
│  [OHDSI LOGO]  TAXIS: Building an OMOP-Native Clinical Relationship Layer to Support Reusable Analytics  [COHAS LOGO] │
│  Stephen H. Bandeian¹, Gowtham Rao²,³, Shaun Grannis⁴,⁵, J. Marc Overhage⁶,⁵ | Collaborator Showcase Entry #127       │
│  ¹Johns Hopkins Univ; ²CoReason; ³OHDSI; ⁴Regenstrief Institute; ⁵Indiana Univ School of Medicine; ⁶The Overhage Group│
├────────────────────────────────┬──────────────────────────────────────┬───────────────────────────────────────────────┤
│    PANEL 1: THE CHALLENGE &    │   PANEL 2: KNOWLEDGE GRAPH TAXONOMY  │      PANEL 3: EMPIRICAL BENCHMARKS,           │
│   ASSOCIATION MINING ENGINE    │    & AUTOMATED PHENOTYPE COMPILER    │     FEDERATED EVALUATION & ECOSYSTEM          │
│                                │                                      │                                               │
│  • The 0.4% Vocabulary Gap     │  • Clinical Pair Taxonomy v6.0       │  • Empirical Evidence Accounting              │
│  • Phenotyping Divergence      │    - 112 Codes / 32 Families         │    - Semantic Plausibility (88.4%)            │
│  • INPC 2.16M OMOP Pipeline    │    - 5 Functional Clinical Classes   │    - Synthetic Cohort Overlap (>97-99%)       │
│  • Epidemiological Guardrails  │  • Two-Stage LLM Screen & Code       │    - Multi-CDM Federated Plan (JnJ)           │
│    - ≥365-Day Wash-in          │  • Directionality Ratio Spectrum     │  • HADES Study Package:                       │
│    - Incident Manifestation    │  • Automated Circe Engine (build.py) │    - TaxisPhenotypeEvaluation                 │
│  • Healthcare Decile           │    - Semantic Anchor Ingestion       │    - 2x2 Complementary Suppression            │
│    Stratification (DEC-GR-010) │    - Subgraph Traversal Logic        │  • Ecosystem Integration:                     │
│    - Neutralizing Util Bias    │    - PrimaryCriteriaLimit: First     │    - OHDSI Phenotype Library 3.0              │
│    - Lift Attenuation Signal   │    - Configurable 10% Mimic Cap      │    - PHOEBE 2.0 Concept Recommendation        │
│                                │                                      │    - LangGraph PhenotypingAgent & MCP         │
│  [FIG 1: Mining Architecture]  │  [FIG 2: Directionality & Workflow]  │  [FIG 3: Overlap Chart & QR Repository Target]│
└────────────────────────────────┴──────────────────────────────────────┴───────────────────────────────────────────────┘
```

---

## 2. Detailed Panel Content Specifications

### Panel 1: The Challenge & Large-Scale Association Mining Pipeline

#### 1.1 The Operational Vocabulary Crisis in OMOP
- Standard terminologies (SNOMED-CT, RxNorm, LOINC) provide hierarchical taxonomies (*is-a* trees) within isolated domains.
- In an empirical audit of frequently co-occurring EHR pairs ($N_{AB} \ge 100$), standard vocabularies documented relational links for only **0.44%** of pairs (with over half being simple hierarchical *is-a* links). Standard vocabularies do not capture operational cross-domain care patterns:
  - Which laboratory test confirms an acute condition?
  - Which medication represents first-line guideline therapy versus symptom management?
  - Which co-occurring diagnosis represents an exclusionary phenotypic mimic?
- Consequence: Phenotype engineers manually curate concept sets from scratch, producing conflicting logic, phenotypic divergence, and high manual authoring friction.

#### 1.2 Pipeline v57 Architecture on 2.16M Longitudinal Patients
- **Data Source**: Indiana Network for Patient Care (INPC) mapped to the OMOP CDM v5.4.
- **Cross-Domain Evaluation**: Mined pairwise concept co-occurrences across 6 domain intersections: `Condition–Drug`, `Condition–Measurement`, `Condition–Procedure`, `Condition–Condition`, `Drug–Procedure`, and `Drug–Drug`.
- **Epidemiological Counting Rules**:
  1. *Baseline Continuous Wash-in*: Mandatory $\ge 365$ days of prior observation before anchor event.
  2. *Incident Manifestation Requirement*: Concept B must have 0 prior occurrences during baseline lookback, isolating prospective clinical emergence.
  3. *Same-Day Tie Handling*: Same-day co-occurrences ($N_{A=B}$) tracked separately and strictly excluded from temporal directionality ratios.

#### 1.3 Healthcare Utilization Decile Stratification (`DEC-GR-010`)
- **Confounding Mechanism**: Sick, hyper-monitored patients generate dense diagnostic and therapeutic codes across all domains, inflating crude statistical lift.
- **Stratification Method**: Patients segmented into 10 deciles of annualized healthcare contact frequency ($U_1 \dots U_{10}$) during baseline wash-in.
- **Diagnostic Lift Attenuation**: Joint probabilities computed within utilization strata and combined via Cochran-Mantel-Haenszel (CMH) weighting. Lift attenuation ($Lift_{\text{crude}} \to Lift_{\text{util}}$) serves as a quantifiable indicator of contact confounding. Pairs gated on $Lift_{\text{util}} \ge 1.50$ and CMH $p < 0.001$.

---

### Panel 2: Clinical Pair Taxonomy v6.0 & Automated Phenotype Synthesis

#### 2.1 Clinical Pair Taxonomy v6.0 Catalog
Comprises **112 standardized relation codes** organized into **32 relation families** across **5 broad clinical classes**:
- **Class I: Causal & Etiologic (24 Codes)**: Infectious triggers, toxic insults, metabolic causes ($DR \ge 1.50$, Binomial $p < 0.01$).
- **Class II: Diagnostic & Indicative (22 Codes)**: Pathognomonic lab results, confirmatory imaging findings, physical signs ($0.67 < DR < 1.50$).
- **Class III: Therapeutic & Interventional (26 Codes)**: Guideline first-line drugs, surgical interventions, rescue agents (canonical $DR \le 0.67$ where A=Treatment, B=Indication; reciprocal $DR' \ge 1.50$).
- **Class IV: Prognostic & Disease Evolution (20 Codes)**: Progression stages, fibrotic transformation, chronic sequelae ($DR \ge 1.50$).
- **Class V: Associational & Phenotypic (20 Codes)**: Shared-risk comorbidities, reciprocal syndromic clusters ($0.67 < DR < 1.50$).

#### 2.2 Two-Stage LLM Screen-and-Code Framework
- **Stage 1 (Functional Class Screen)**: Classifies mined pairs into one of the 5 broad functional classes using structured clinical descriptions.
- **Stage 2 (Granular Relation Coding)**: Assigns exact relation code from class catalog with natural-language clinical rationale.
- **Consensus & Adjudication**: Executes multi-model triplicate sampling ($T=0.0, 0.2, 0.4$) to minimize stochastic variance; requires $\kappa \ge 0.85$ inter-annotator agreement; split votes adjudicated by autonomous Supervisory Judge.

#### 2.3 Directionality Ratio Spectrum ($DR$)
The Directionality Ratio $DR = \frac{N_{A \to B} + 0.5}{N_{B \to A} + 0.5}$ serves as an empirical consistency diagnostic:
- **Forward Predominant ($DR \ge 1.50$)**: Concept A precedes Concept B (Etiologies $\to$ Manifestations; Chronic Disease $\to$ Complications).
- **Reverse Predominant ($DR \le 0.67$)**: Concept B precedes Concept A (Indication Condition precedes Treatment Prescription).
- **Balanced ($0.67 < DR < 1.50$)**: Balanced directional incidence in longitudinal records; distinct from same-day presentation ($N_{A=B}$).

#### 2.4 Automated Circe Phenotype Recreation Engine (`build_1032.py`)
Translates knowledge graph subgraphs directly into computable OHDSI Circe JSON:
- **Primary Event Entry**: Standard concepts supplemented with Class II diagnostic indicators. Enforces `PrimaryCriteriaLimit: First` per `DEC-GR-007`.
- **Confirmatory Secondary Criteria**: Class II confirmatory assays and Class III first-line therapies within $[-7, +30]$ days of index.
- **Differential Rule-Out Exclusions**: Strictly mapped from differential diagnosis codes (`DIAG_DIFF_01`, `DIAG_DIFF_02`), enforcing a **configurable 10% anchor patient attrition cap** (`DEC-GR-008`) to prevent catastrophic cohort shrinkage.

---

### Panel 3: Empirical Benchmarks, Federated Evaluation & Ecosystem Integration

#### 3.1 Empirical Evidence Accounting Register
Strict separation of evidence tiers per `REC-003-1`:

| Evidence Category | Analytical Target | Dataset & Denominator | Comparator / Benchmark | Observed Empirical Result | Status |
|---|---|---|---|---|:---:|
| **Semantic Edge Relevance (EVID-01)** | Edge existence classification | 1,000 clinically curated pairs | ClinVec Physician Panel Ratings | **AUC 0.81** (95% CI: 0.79–0.83) | Completed |
| **Temporal Precedence (EVID-02)** | Directional chronology ($DR$) | 100 PACES guideline pairs | Clinical Practice Guidelines | **99.0%** Directional Concordance | Completed |
| **Blinded Physician Review (EVID-03)** | 112-code taxonomy typing | 291 sampled INPC pairs | Dual Internist Review (Overhage & Grannis) | **88.3%** broad group ($\kappa=0.84$); **58.1%** exact code ($\kappa=0.54$) | Completed |
| **Empirical Cohort Overlap: T2DM (EVID-04)** | Recreated Circe definition | INPC 2.16M CDM ($|A \cup B| = 143,528$) | OHDSI Phenotype Library Cohort #1032 | **99.5%** Jaccard Overlap ($142,810 / 143,528$); **99.8%** Sensitivity | Completed |
| **Empirical Cohort Overlap: CKD (EVID-04)** | Recreated Circe definition | INPC 2.16M CDM ($|A \cup B| = 70,383$) | OHDSI Phenotype Library Cohort #1191 | **97.2%** Jaccard Overlap ($68,412 / 70,383$); **98.6%** Sensitivity | Completed |
| **Empirical Cohort Overlap: COPD (EVID-04)** | Recreated Circe definition | INPC 2.16M CDM ($|A \cup B| = 52,042$) | OHDSI Phenotype Library Cohort #1263 | **98.4%** Jaccard Overlap ($51,209 / 52,042$); **98.9%** Sensitivity | Completed |
| **Federated Multi-CDM Study** | Cross-database portability | CCAE, MDCR, MDCD, Optum, CPRD | Manual OHDSI definitions & PheValuator | Sensitivity, Specificity, PPV, NPV, F1 | Prospective (JnJ) |

#### 3.2 Federated HADES Study Package: `TaxisPhenotypeEvaluation`
- **Network Data Governance (`DEC-GR-005`)**: Fully isolated execution behind institutional firewalls; concept-pair co-occurrences remain local.
- **Export Package**: Generates `Results_<databaseId>.zip` containing aggregate cohort overlap summaries and PheValuator diagnostic performance metrics (Sensitivity, Specificity, PPV, NPV, F1 Score).
- **Mathematical Small-Cell Suppression**: Enforces $2 \times 2$ complementary suppression ($0 < N < 5$ masks all interior partition counts and derived ratios to $-1$), preventing algebraic back-calculation.
- **Packaging Security Contract**: Exact-path allowlist and deep archive inspection reject unapproved tables, logs, and patient-level identifiers.

#### 3.3 OHDSI Ecosystem Integration Roadmap
- **OHDSI Phenotype Library 3.0**: Algorithmic phenotype generator for the new autonomous governance lifecycle (intake, redundancy classification via Jaccard metrics, and longitudinal drift monitoring).
- **PHOEBE 2.0 Integration**: Balances clinical relationship semantics with real-world network concept prevalence.
- **Autonomous Agent Integration**: Operates as an MCP clinical knowledge server for `schuemie/PhenotypingAgent`; pairs with `schuemie/ConceptSetCondenser` for set-covering Circe compression.
- **Principled Confounder Selection**: Distinguishes true baseline confounders (Class I) from downstream complications and treatment effects (Class IV) to prevent over-adjustment bias in study design.

---

## 3. Four-Minute Presentation Script for Showcase Presenters

### Minute 1: The Hook & The Problem
> *"Welcome everyone. In observational research across the OHDSI network, our standard vocabularies harmonize codes brilliantly, but they have a critical blind spot: they capture less than half a percent of cross-domain clinical relationships. When you want to build a Type 2 Diabetes or COPD phenotype in ATLAS, SNOMED won't tell your algorithm which lab test confirms the diagnosis or which drug represents first-line therapy. Phenotype development remains a manual, time-consuming craft that leads to divergence between research groups. TAXIS solves this by mining an empirical clinical relationship layer directly from longitudinal patient data."*

### Minute 2: The Large-Scale Mining Engine & Confounder Control
> *"To build TAXIS, we scaled association mining across 2.16 million longitudinal patients in the Indiana Network for Patient Care. We evaluated over 3 million candidate pairs across 6 cross-domain intersections. But raw co-occurrence in EHR data is notoriously confounded by sick patients who get tested and treated for everything. We solved this with two innovations: first, strict epidemiological wash-in and incident manifestation windows; and second, healthcare utilization decile stratification. By computing expected co-occurrences within patient contact volume deciles, we diagnostic-filter utilization artifacts while preserving genuine clinical mechanisms."*

### Minute 3: The 112-Code Taxonomy & Automated Phenotyping Engine
> *"Next, we organized these associations into our Clinical Pair Taxonomy v6.0—112 standardized relation codes across 5 clinical classes. Using a two-stage LLM screen-and-code framework with multi-model consensus, we assign specific relations and directionality ratios to each edge. Our automated compiler, `build_1032.py`, traverses these graph neighborhoods to generate OHDSI Circe JSON phenotypes. On real-world INPC CDM evaluations, our automated definitions achieved 97.2% to 99.5% Jaccard overlap with gold-standard OHDSI Phenotype Library definitions for Type 2 Diabetes, CKD, and COPD, while capping differential rule-out attrition at 10%."*

### Minute 4: Network Portability & The Call to Action
> *"Finally, we engineered TAXIS for the broader OHDSI community. To ensure data privacy, our HADES evaluation package, `TaxisPhenotypeEvaluation`, runs entirely locally behind partner firewalls, exporting strictly aggregate non-PHI summaries with mathematical 2x2 complementary cell suppression. We are preparing multi-CDM evaluations across commercial claims, Medicare, Medicaid, and EHR databases. TAXIS is open-source under Apache 2.0, providing an algorithmic engine for Phenotype Library 3.0 and autonomous phenotyping agents. We invite data partners to review our protocol, run the evaluation package, and collaborate. Thank you!"*

---

## 4. Digital Assets & QR Code Verification Targets

- **Study Repository**: `https://github.com/ohdsi-studies/Taxis`
- **Network Study Protocol v1.0**: [`docs/protocol/TAXIS_NETWORK_STUDY_PROTOCOL_V1.md`](../protocol/TAXIS_NETWORK_STUDY_PROTOCOL_V1.md)
- **Clinical Pair Taxonomy v6.0**: [`docs/knowledge_graph/Clinical_Pair_Taxonomy_6.md`](../knowledge_graph/Clinical_Pair_Taxonomy_6.md)
- **Concept AB Mining Engine v57**: [`docs/mining/CONCEPT_AB_MINING_ENGINE_V57.md`](../mining/CONCEPT_AB_MINING_ENGINE_V57.md)
- **Phenotype Recreation Engine**: [`docs/phenotyping/Phenotype_Recreation_Engine.md`](../phenotyping/Phenotype_Recreation_Engine.md)
- **ClinVec Benchmark Results**: [`docs/validation/ClinVec_Benchmark_Results.md`](../validation/ClinVec_Benchmark_Results.md)
- **HADES Study Package**: [`extras/TaxisPhenotypeEvaluation/`](../../extras/TaxisPhenotypeEvaluation/)
