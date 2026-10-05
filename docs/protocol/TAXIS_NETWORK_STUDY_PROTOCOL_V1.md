# TAXIS Network Study Protocol (v1.0)

# Empirical Discovery and Multi-Domain Clinical Relationship Mining Across the OMOP Common Data Model

> **Document Type**: Formal Network Study Protocol (Version 1.0)  
> **Study Acronym**: **TAXIS** (*Transparent Analytic Knowledge Graph for Interoperable Science*)  
> **Release Date**: October 2026  
> **OHDSI Presentation**: 2026 OHDSI Global Symposium Collaborator Showcase (Entry #127, October 20–22, 2026, New Brunswick, NJ)  
> **Study Leadership**:  
> - **Stephen H. Bandeian, MD, JD** (Principal Investigator, Johns Hopkins University School of Medicine; Original SQL & Analytic Code Author)  
> - **J. Marc Overhage, MD, PhD** (Co-Principal Investigator, The Overhage Group / Indiana University School of Medicine)  
> - **Gowtham Rao, MD, PhD** (Investigator, [CoReason, Inc.](https://www.coreason.ai) USA; OHDSI)  
> - **Shaun Grannis, MD, MS** (Investigator, Regenstrief Institute / Indiana University School of Medicine)  
> **Original Scientific & Analytic Authorship**:  
> All SQL algorithms, database schemas, 40-batch partitioning strategies, continuity-corrected directionality formulations ($DR$), and original analytic code of the Concept AB Mining Engine (Pipeline v57) were conceived, designed, and authored by **Stephen H. Bandeian, MD, JD** (Principal Investigator, Johns Hopkins University School of Medicine).  
> **Repository**: [ohdsi-studies/Taxis](https://github.com/ohdsi-studies/Taxis)  

---

## 1. Abstract & Executive Summary

Observational health research across the Observational Health Data Sciences and Informatics (OHDSI) collaborative depends upon standardized clinical vocabularies (SNOMED-CT, RxNorm, LOINC) integrated within the OMOP Common Data Model (CDM). While standard terminologies excel at coding and within-domain taxonomy (such as hierarchical *is-a* relationships), they provide very few computable, evidence-weighted links across distinct clinical domains (such as which laboratory test confirms a diagnosis, which drug is indicated for a disorder, or which complications sequentially emerge). In current practice, epidemiologists and clinical informaticians must repeatedly handcraft these multi-domain relationships for every phenotype, covariate set, and study design—a manual, labor-intensive bottleneck that impedes reproducible research.

The **TAXIS (Transparent Analytic Knowledge Graph for Interoperable Science)** network study establishes an open, empirical framework to discover, validate, and publish reusable clinical relationships across all standard OMOP clinical concept domains (conditions, drugs, procedures, measurements/labs, devices, and observations). Operating under OHDSI's distributed research paradigm ("code moves to the data"), participating sites execute standardized analytical packages locally behind their institutional firewalls. 

The protocol establishes:
1. **Domain Event Construction ("Eventization")**: Converting heterogeneous table records into standardized longitudinal clinical episodes.
2. **Chronic-Onset Hazard Windows & Statistical Metrics**: Measuring person-level co-occurrence, expected counts, observed-to-expected lift, odds ratios with Haldane-Anscombe corrections, and directional temporal precedence ($DR = N_{A \to B} / N_{B \to A}$).
3. **Confounding Mitigation via Utilization Stratification**: Controlling for patient-level healthcare contact frequency to prevent hyper-utilization bias.
4. **Two-Stage Screen-and-Code Ensemble**: Combining statistical association screening with multi-model clinical pair classification across 112 standardized taxonomy codes.
5. **Privacy-Preserving Aggregate Dissemination**: Enforcing strict small-cell suppression ($<5$), deterministic output auditing, and open-source dissemination without patient-level data transfer.

---

## 2. Rationale, Background & The 0.4% Vocabulary Coverage Gap

### 2.1 The Clinical Knowledge Bottleneck in Observational Research
Generating reliable real-world evidence requires answering detailed clinical questions: *What medications treat this disorder? What laboratory tests confirm its diagnosis? What clinical findings represent exclusionary mimics? What downstream complications are expected?* 

Currently, observational research platforms leave these clinical associations largely unrepresented in computable form. While the OMOP CDM standardizes syntax and vocabulary concepts, the substantive clinical relationships connecting those concepts are re-engineered manually for each new study. This study-by-study authoring creates major methodological challenges:
- **The Reproducibility Bottleneck & Cohort Variation**: Systematic reviews of published literature across clinical indications (e.g., Alzheimer's disease, major depressive disorder, rheumatoid arthritis) have revealed striking heterogeneity in phenotype algorithms, with independent research teams producing up to a **tenfold difference in cohort sizes** for the identical target condition (Shoaibi et al., AMIA 2024).
- **Subjectivity & Missing Clinical Anchors**: To establish reproducibility across study teams, the OHDSI community established that an *a priori* written **Clinical Description** across standardized domains (presentation, assessment, confirmatory labs, differential diagnoses/exclusions, indicated treatments) must serve as the **semantic anchor** before translating clinical intent into computable queries (Shoaibi, Ostropolets, Murphy, Rao, et al.).
- **Variable Phenotype Quality**: The OHDSI Phenotype Library contains over 1,100 cohort definitions, yet approximately two-thirds are single-code lists without temporal or multi-domain logic, and only ~2% incorporate laboratory criteria.
- **Inadvertent Bias in Study Design**: Hand-picked confounder lists can accidentally adjust for intermediate side effects or complications caused by the treatment, introducing bias instead of controlling for it.

### 2.2 The Empirical 0.4% Terminology Coverage Benchmark
Standard clinical terminologies were engineered primarily for administrative billing, medical recording, and hierarchical ontology. In an empirical audit of an audited sample of 26,901 frequently co-occurring concept pairs ($N_{AB} \ge 100$) mined from electronic health records in the Indiana Network for Patient Care (INPC):
- Only **119 pairs (0.44%)** had any documented relationship in native SNOMED-CT or the Unified Medical Language System (UMLS).
- Of those 119 documented pairs, **72 (60.5%)** were simple hierarchical *is-a* relationships.
- Cross-domain clinical connections (e.g., condition-to-lab, condition-to-drug, or procedure-to-complication) were virtually unrepresented.

When standardized clinical terminology links do exist, they exhibit high positive predictive value (0.99 PPV against clinical consensus). Within this audited sample of frequently co-occurring pairs, 99.6% lacked explicit multi-domain relational links in native vocabularies, illustrating that standard terminologies focus on administrative coding and ontological hierarchy rather than multi-domain clinical co-occurrence. TAXIS is designed to bridge this operational gap through reproducible observational association mining, with early benchmark analyses indicating promising concordance against clinical standards.

### 2.3 The Structural Divide Between Procedure Orders and Lab Results (LOINC vs. SNOMED)
A second critical vocabulary deficit identified by study leadership is the architectural divide between diagnostic orders and laboratory results:
* **The Conceptual Split**: SNOMED-CT and CPT represent the *clinical act* of ordering or executing a test (a procedure), whereas LOINC represents the *discrete resulting value or observation* (a measurement).
* **Missing Ontology Linkages**: In standard electronic health records, provider orders are rarely mapped to SNOMED procedure codes, and official terminology crosswalks linking specific procedure orders to their corresponding LOINC measurement values do not exist in practice.
* **Empirical Resolution in TAXIS**: Because static vocabularies lack these connections, TAXIS deduces them empirically directly from patient data. By evaluating pairwise co-occurrences across condition, procedure, and measurement domains within configured temporal intervals (e.g., $\pm 60$ days), the pipeline organically discovers which laboratory analytes and abnormal findings systematically accompany specific disorders and clinical interventions.

---

## 3. Protocol Genesis & Architectural Evolution

The TAXIS study framework evolved through three distinct developmental stages:

```
┌────────────────────────────────────────────────────────┐
│  Stage 1: Foundational Network Concept (v0.5)          │
│  • Conceived by Dr. Stephen Bandeian & Dr. Marc        │
│    Overhage (September 2025)                           │
│  • Distributed federated concept design                │
│  • Symmetric ±30-day windows on Condition pairs        │
│  • Crude odds ratios & baseline co-occurrence counts   │
└───────────────────────────┬────────────────────────────┘
                            │ 12 Months of Methodological Refinement
                            ▼
┌────────────────────────────────────────────────────────┐
│  Stage 2: Production Pipeline Architecture (v57)       │
│  • Scaled across 2.16M longitudinal INPC patients      │
│  • Extended across 6 OMOP concept domains              │
│  • Chronic-onset hazard models (365-day wash-in)       │
│  • Healthcare utilization decile stratification        │
│  • Two-Stage Screen-and-Code Ensemble (112 taxonomy    │
│    codes across 32 families; 1.9M graded edges)        │
│  • Automated Circe phenotype construction & evaluation │
└───────────────────────────┬────────────────────────────┘
                            │ Network Standardization
                            ▼
┌────────────────────────────────────────────────────────┐
│  Stage 3: Network Study Protocol (v1.0, October 2026)  │
│  • Standardized network execution specifications       │
│  • Initial 5-phenotype evaluation workstream (Wave 4)  │
│  • Two-tiered data governance & cell suppression (<5)  │
│  • Pre-specified negative control hypothesis workflow  │
└────────────────────────────────────────────────────────┘
```

### 3.1 Initial Protocol Design (Stage 1 / v0.5)
The foundational protocol (September 2025) established the core principles of federated association mining:
- Executing standardized SQL and R routines locally on partner OMOP CDMs.
- Constructing clinical episodes from condition occurrence records.
- Computing pairwise support ($N_{AB}$), crude odds ratios, and initial temporal directionality ratios.
- Transferring only aggregate, de-identified statistics to a central coordinating environment for quality control and classification.

### 3.2 Production Evolution (Stage 2 / Pipeline v57)
Applying the initial design to 2.16M longitudinal patient records (11.3 million person-years) in the Indiana Network for Patient Care revealed key methodological challenges that prompted the development of Pipeline v57:
1. **Symmetric Windowing Bias in Chronic Disease**: Symmetric fixed-day windows (e.g., $\pm 30$ days) conflate acute presentations with long-standing chronic conditions. Pipeline v57 introduced **chronic-onset hazard models**, anchoring analysis on the initial diagnosis date following a minimum 365-day observation wash-in.
2. **Hyper-Utilization Confounding**: Patients with frequent healthcare encounters ("high utilizers") exhibit elevated co-occurrence across clinically unrelated concepts simply because they are observed more often. Pipeline v57 introduced **healthcare utilization decile stratification**, normalizing lift against baseline encounter frequency.
3. **Multi-Domain Expansion**: The feature space was expanded beyond condition–condition pairs to systematically evaluate condition–drug, condition–measurement, condition–procedure, and procedure–procedure relationships.
4. **Structured Taxonomy Classification**: Moving beyond binary association, Pipeline v57 introduced a two-stage ensemble clinical classifier mapping edges into 112 standardized clinical taxonomy codes across 32 clinical families.

### 3.3 The "Bill of Materials" (BOM) Nested Process-of-Care Architecture

> [!NOTE]
> **Phase 1 Production vs. Phase 2 Architectural Roadmap (`DEC-GR-061`)**:  
> The nested Bill of Materials (BOM) process-of-care architecture and Condition Sub-Episodes represent foundational theoretical design frameworks and Phase 2 roadmap targets. In Phase 1 network execution (Pipeline v57; `inst/sql/sql_server/*.sql`), association mining operates over empirical event co-occurrence within parameterized temporal horizons (e.g., $[-30\text{d}, +30\text{d}]$, $[-365\text{d}, +365\text{d}]$) anchored on initial presentation with 365-day wash-in. Complete specifications for prospective BOM episode construction and multi-state episode tables are detailed in the companion roadmap: [`docs/roadmap/TAXIS_FUTURE_ARCHITECTURAL_ROADMAP.md`](../roadmap/TAXIS_FUTURE_ARCHITECTURAL_ROADMAP.md).

Clinical care is not an unorganized list of billing codes; it is a **nested hierarchy of clinical processes and subprocesses**, directly analogous to a manufacturing **Bill of Materials (BOM)** (e.g., how an aircraft or automobile is assembled from assemblies, subassemblies, and components). In TAXIS, care is structured into:
1. **Level 1 (L1) Problem Episodes**: Triggered by an index event (e.g., onset of acute appendicitis or initial diagnosis of diabetes), representing the overarching patient journey from initial evaluation to resolution or chronic disease management.
2. **Condition Sub-Episodes**: Distinct temporal phases within chronic episodes representing disease staging progression, loss of glycemic or hemodynamic control, or acute exacerbations (e.g., acute decompensated heart failure within chronic CHF, or acute COPD flare-up) that trigger intensified diagnostic and therapeutic interventions.
3. **Level 2 (L2) Procedural Anchors**: The principal unit of care within an encounter, deterministically identified by ranking services according to clinical invasiveness (using CMS RBCS/BTOS classifications crosswalked to SNOMED: major surgical procedures > inpatient admissions > emergency services > therapies > imaging > lab assays > E&M visits).
4. **Supporting Service Hierarchy**: Surrounding care cataloged in defined temporal windows around the anchor:
   - *Pre-procedure suitability and risk evaluation* ($[-30, 0]$ days before anchor).
   - *Intra-procedure support* (anesthesia, hemodynamic monitoring, vein harvesting).
   - *Post-procedure recovery and complication surveillance* ($[0, +90]$ days after anchor).

This nested process framework enables health systems and observational researchers to systematically evaluate deviations from optimal care and quantify missed opportunities to improve health outcomes at scale.

### 3.4 Concept Granularity: Reconciling Anchor Concepts and Atomic Codes
A central architectural debate during protocol formation was whether to mine associations at the level of aggregated "Anchor Concepts" (e.g., rolling 120 diabetes variants into Diabetes Mellitus) or granular atomic codes (e.g., specific trimalleolar fracture vs. closed lateral malleolar fracture). Grouping into anchor concepts is mathematically necessary to avoid combinatorial explosion and eliminate coding noise; however, atomic codes are essential for community transparency, auditable provenance, and capturing clinical distinctions (e.g., a mild fracture correlating with a plain X-ray vs. a trimalleolar fracture correlating with a CT scan and surgical reduction). TAXIS resolved this by supporting **dual processing**: candidate pairs are mined and reported at both the anchor level and atomic concept levels, with combinatorial database overload prevented by enforcing strict minimum co-occurrence and significance thresholds ($N_{AB} \ge 100$, $\text{Lift}_{\text{strat}} \ge 1.50$).

---

## 4. Objectives & Specific Aims

### Primary Objective
To establish and validate an open, computable, and evidence-weighted clinical knowledge layer across OMOP concept domains, enabling automated phenotype construction, candidate negative control generation, and principled confounding control in observational research.

### Specific Aims
- **Aim 1: Standardized Domain Eventization & Windowing**: Implement standardized event-construction methods across OMOP tables (Condition, Drug, Procedure, Measurement, Device, Observation) and execute domain-specific temporal windows.
- **Aim 2: Federated Site-Level Aggregate Computation**: Compute masked, site-level aggregate co-occurrence statistics, expected frequencies, observed-to-expected lift, odds ratios with continuity corrections, and temporal directionality ratios across participating network CDMs.
- **Aim 3: Two-Stage Classification & Open Dissemination**: Classify candidate relationships through a two-stage screen-and-code ensemble incorporating clinical taxonomy rules and multi-model consensus, publishing validated network-level artifacts under open-source licenses.

---

## 5. Study Design & Distributed Analytics Framework

TAXIS is designed as a **multicenter, observational, federated network study** executed across OMOP CDM v5.3+ environments.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     PARTICIPATING DATA PARTNER CDM                      │
│                                                                         │
│  ┌─────────────────────────┐        ┌────────────────────────────────┐  │
│  │  OMOP CDM v5.3 / v5.4   │        │     HADES Execution Package    │  │
│  │  • Condition_Occurrence │ ─────► │     TaxisPhenotypeEvaluation   │  │
│  │  • Drug_Exposure / Era  │        │     • Cohort Diagnostics       │  │
│  │  • Measurement          │        │     • PheValuator Models       │  │
│  │  • Procedure_Occurrence │        │     • Jaccard Overlap Matrix   │  │
│  └─────────────────────────┘        └────────────────┬───────────────┘  │
│                                                      │                  │
│                                     Local Execution Behind Firewall     │
│                                                      ▼                  │
│                                     ┌────────────────────────────────┐  │
│                                     │  Small-Cell Suppression (<5)   │  │
│                                     │  Deterministic Output Archive  │  │
│                                     │  Results_<databaseId>.zip      │  │
│                                     └────────────────┬───────────────┘  │
└──────────────────────────────────────────────────────┼──────────────────┘
                                                       │
                           Audited & Approved Aggregate Only (Tier 2)
                                                       ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      CENTRAL COORDINATING ENVIRONMENT                   │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │  Network Evidence Synthesis & Open Dissemination                  │  │
│  │  • Multi-Site Cohort Agreement & Jaccard Overlap Evaluation       │  │
│  │  • Phenotype Library 3.0 Ingestion & PHOEBE Integration           │  │
│  │  • Open-Source Dissemination (Apache 2.0 / CC-BY-4.0)             │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

### 5.1 Distributed Analytics Principle & Workstream Scope
- **Zero Patient-Level Data Transfer**: Patient-level data, direct identifiers, and personal health information never leave the participating institution.
- **Deterministic Execution**: Analysis routines are distributed as standardized HADES R study packages ([`TaxisPhenotypeEvaluation`](../../extras/TaxisPhenotypeEvaluation/README.md)), evaluating candidate cohorts against comparator definitions under federated execution.
- **Site Audit Authority**: All exported files are written into a single inspection archive (`Results_<databaseId>.zip`). Participating sites retain absolute authority to inspect, audit, and approve the archive before transmission.
- **Two Simultaneous Network Participation Pathways (`DEC-GR-057`)**:
  - **Track A (Knowledge Graph Contributors)**: Data network partners execute local association mining on their OMOP CDMs (with choice between Full-Database 40-batch mining or Targeted condition-of-interest mining) across PostgreSQL, SQL Server, and Snowflake, operating under a tiered governance model (open small-cell suppressed summaries and central consortium DUA pair co-occurrence matrices).
  - **Track B (Application Validators)**: Data sites and clinical experts evaluate downstream applications:
    - *Sub-track B1 (Phenotype Validation)*: Evaluating the 5 showcase benchmark phenotypes (T2DM, CKD, COPD, AMI, MDD) using `CohortDiagnostics` and `PheValuator`.
    - *Sub-track B2 (Negative Control Calibration)*: Evaluating candidate negative control sets derived from TAXIS via `EmpiricalCalibration`.
    - *Sub-track B3 (Clinical Adjudication)*: Clinician-investigators without direct database access conducting blinded pair review and Clinical Description authoring.
  - Complete instructions and prerequisites are detailed in the companion [TAXIS Call for Collaborators](../governance/TAXIS_CALL_FOR_COLLABORATION.md).

### 5.2 Two-Tiered Data Governance Architecture
As detailed in the companion [TAXIS Network Data Use Term Sheet](../governance/TAXIS_NETWORK_DATA_USE_TERM_SHEET.md):
- **Tier 1 (Internal Concept Co-Occurrence Matrices)**: Full pairwise co-occurrence matrices, patient-level counts, and internal edge weights remain strictly internal to the partner's secure infrastructure.
- **Tier 2 (Aggregate Phenotype Performance & Overlap Summaries)**: Masked, site-level summary metrics (Jaccard similarity matrices, cohort counts with small-cell suppression, and PheValuator operating characteristics: Sensitivity, Specificity, PPV, NPV, F1 Score) are approved for network synthesis.

### 5.3 The Six-Point Empirical Validation Framework
To establish definitive scientific credibility and provide an objective answer to the community's core question—*"Did the algorithm get it right?"*—TAXIS codifies a formal six-priority validation framework:

| Priority | Empirical Analysis | Methodological Rationale | Deliverable for OHDSI Network |
|:---:|---|---|---|
| **1** | **Candidate Set Efficiency & Threshold Sensitivity** | Proves that the statistical extraction step ($N_{AB} \ge 100, \text{Lift}_{\text{strat}} \ge 1.50$) reduces billions of possible co-occurrences into a tractable review set without arbitrary heuristic dropping of true clinical relationships. | Sensitivity curve table showing candidate count, retained proportion, and recovery of benchmark edges under 3–4 threshold scenarios. |
| **2** | **Formal Comparison Against Curated Computable Sources** | Evaluates whether empirical knowledge graph edges successfully recover peer-reviewed computable relationships extracted from PheKB, ClinVec, and the OHDSI Phenotype Library across all domain pairs. | Precision/recall and recovery matrices by clinical source and domain pair (`Dx-Dx`, `Dx-Drg`, `Dx-Proc`, `Dx-Meas`). |
| **3** | **Benchmark Expected-Pair Recovery & Missingness Audit** | Direct sensitivity audit evaluating whether expected clinical connections (e.g., standard of care treatments or pathognomonic labs) are present, statistically recovered, and classified, with systematic root-cause diagnosis of any missed pairs. | Edge recovery audit table: benchmark edge present in KG? statistically recovered? clinically valid? failure taxonomy if missed. |
| **4** | **LLM Validity Yield & Domain Distribution** | Audits whether clinical adjudication produces clinically interpretable output across condition, drug, procedure, and measurement pairings. | Distribution tables and visualizations of valid, invalid, uncertain, and relationship-type breakdowns across the 32 clinical families. |
| **5** | **Statistical Evidence vs. Clinical Validity Concordance** | Tests whether clinically validated edges are supported by stronger empirical observational evidence than invalid edges, and identifies "clinically plausible but empirically weak" relationships. | Empirical contrast table comparing observed count, expected count, stratified lift, Z-score, and Directionality Ratio by clinical validity status. |
| **6** | **Focused Discordant-Edge Review & Error Taxonomy** | High-information case analysis diagnosing systematic edge discrepancies (statistically strong but clinically invalid, clinically valid but statistically weak, or missing from traditional references). | Structured error taxonomy categorizing discrepancies: mapping/vocabulary artifact, threshold cutoff, clinical coding artifact, or true underobserved practice. |

---

## 6. Methods & Execution Specifications

### 6.1 Concept Domains & Pair Types in Scope
The study evaluates pairwise combinations across primary OMOP standard concept domains:

| Domain Pair | Notation | Primary Clinical Semantic | Phase Wave |
|---|---|---|---|
| **Condition ↔ Condition** | `Dx-Dx` | Comorbidities, sequential manifestations, complications | Phase 1 |
| **Drug → Condition** | `Drg-Dx` | Therapeutic indications, adverse drug reactions (ADRs) | Phase 2 |
| **Condition → Drug** | `Dx-Drg` | First-line / second-line treatments, contraindications | Phase 2 |
| **Measurement ↔ Condition** | `Meas-Dx` | Diagnostic confirmatory tests, disease monitoring, risk markers | Phase 2 |
| **Procedure → Condition** | `Proc-Dx` | Diagnostic procedures, surgical treatments, procedural complications | Phase 2 |
| **Procedure ↔ Procedure** | `Proc-Proc` | Care pathways, surgical episodes, procedural bundles | Phase 2 / 3 |
| **Drug ↔ Drug** | `Drg-Drg` | Concomitant therapy, multi-drug regimens, interactions | Phase 3 |
| **Device ↔ Procedure/Condition**| `Dev-Proc/Dx` | Implanted devices, procedural equipment, device complications | Phase 3 |

### 6.2 Domain Event Construction ("Eventization")
Heterogeneous OMOP tables are standardized into comparable longitudinal event episodes:
1. **Condition Episodes**: Successive records of the same condition concept separated by less than 30 days are collapsed into continuous condition episodes.
2. **Drug Eras**: Standard OHDSI drug era logic is applied (allowing 30-day persistence windows between consecutive prescription or dispensation records) to construct continuous drug exposure eras at both ingredient and clinical drug levels.
3. **Procedure Events**: Individual procedure dates are recorded as single-day events; repeated instances within 7 days are grouped into procedural episodes.
4. **Measurement Events**: Each laboratory measurement represents a discrete event, recording the standard concept ID, measurement date, abnormal flag (derived from reference ranges), and value categorization.
5. **Observation Events**: Clinical observations are captured as single-day events and mapped to standardized clinical classifications.

### 6.3 Temporal Windows, Counting Rules & Directionality Formulations

#### Incident Anchor Definition & Observation Wash-In
To evaluate true chronological emergence while avoiding acute diagnostic noise, the protocol employs an asymmetrical chronic-onset hazard design:
- **Baseline Observation Wash-In**: A minimum continuous observation period of 365 days prior to the index event is required for all candidate patients.
- **Incident Anchor Index Event ($t_A$)**: The index date for concept $A$ is defined as the *first* recorded occurrence of concept $A$ following the 365-day wash-in period.
- **Incident Prospective Horizon ($t_B$)**: Concept $B$ is evaluated within a prospective follow-up window of $[+1, +730\text{ days}]$ post-index. To capture true incident emergence ($A \to B$), concept $B$ must have zero recorded occurrences prior to $t_A$.
- **Symmetric Reverse Horizon ($B \to A$)**: Evaluated symmetrically: the index date $t_B$ is the first recorded occurrence of concept $B$ following a 365-day wash-in, evaluating incident concept $A$ (with no prior occurrence before $t_B$) within $[+1, +730\text{ days}]$.
- **Same-Day Co-Occurrence (Ties, Day 0)**: Events where concept $A$ and concept $B$ occur on the exact same date ($t_A = t_B$) are recorded as synchronous co-occurrences ($N_{A=B}$). Same-day ties are strictly excluded from directional precedence counts ($N_{A \to B}$ requires $t_B > t_A$; $N_{B \to A}$ requires $t_A > t_B$).
- **Censoring**: Patient observation is censored at the earliest of target concept occurrence, end of continuous enrollment/data availability, or 730 days post-index.

#### Directionality Ratio ($DR$) with Continuity Correction

> **A Concrete Worked Example**: For an illustrative condition–measurement pair in a configured follow-up window, suppose 30 paired occurrences follow the condition ($N_{A \to B} = 30$) and 10 precede it ($N_{B \to A} = 10$). With continuity corrections, the Directionality Ratio is $DR = (30 + 0.5) / (10 + 0.5) = 2.90$. Events occurring on the same calendar day ($N_{A=B}$) are recorded as distinct synchronous counts and excluded from directional calculations. This ratio describes empirical sequence in health records—indicating the lab was predominantly recorded after the diagnosis—providing an empirical candidate for clinical review rather than biological proof of disease etiology.

Temporal precedence between two associated concepts $A$ and $B$ is quantified by the continuity-corrected Directionality Ratio:

$$DR(A, B) = \frac{N_{A \to B} + 0.5}{N_{B \to A} + 0.5}$$

Where:
- $N_{A \to B}$ is the number of eligible patients with incident concept $A$ preceding incident concept $B$ ($t_A < t_B \le t_A + 730\text{ days}$).
- $N_{B \to A}$ is the number of eligible patients with incident concept $B$ preceding incident concept $A$ ($t_B < t_A \le t_B + 730\text{ days}$).
- A $+0.5$ Haldane-Anscombe continuity correction prevents division by zero when $N_{B \to A} = 0$.

**Interpretation Thresholds (requiring $N_{A \to B} \ge 10$)**:
- $DR \ge 1.50$: Empirical temporal precedence of $A$ prior to $B$ (e.g., diabetes preceding diabetic retinopathy).
- $0.67 < DR < 1.50$: Balanced directional ordering (forward and reverse occurrences of comparable magnitude, distinct from same-day synchrony $N_{A=B}$).
- $DR \le 0.67$: Empirical temporal precedence of $B$ prior to $A$.

### 6.4 Confounding Mitigation via Dual Lift Reporting

Patients who interact frequently with the healthcare system accumulate more diagnosis, procedure, and medication codes than low utilizers. To distinguish genuine clinical associations from shared utilization frequency, TAXIS reports both **unadjusted person lift** and **utilization-stratified lift** (DEC-GR-010):

1. **Unadjusted Person Lift**:
   $$\text{Lift}_{\text{unadjusted}} = \frac{N_{AB} / N_{\text{pop}}}{(N_A / N_{\text{pop}}) \cdot (N_B / N_{\text{pop}})}$$
   Where $N_{\text{pop}}$ is the total eligible cohort meeting the 365-day baseline observation requirement, and $N_A, N_B, N_{AB}$ are distinct person counts.

2. **Utilization-Stratified Lift**:
   - Each patient's total encounter count during their baseline observation period is computed.
   - The population is stratified into **utilization deciles** ($D_1$ to $D_{10}$), where $N_d$ is the total population in decile $d$.
   - Expected co-occurrence counts are computed within each decile from aligned marginals and summed:
     $$E(N_{AB}) = \sum_{d=1}^{10} \frac{N_{A, d} \cdot N_{B, d}}{N_d}$$
   - Stratified observed-to-expected lift is then:
     $$\text{Lift}_{\text{stratified}} = \frac{N_{AB}}{E(N_{AB})}$$

Under statistical independence, $\text{Lift} \approx 1.0$ (or $\log(\text{Lift}) \approx 0$). Comparing unadjusted lift to stratified lift provides direct empirical measurement of the confounding reduction achieved by utilization deciles.

### 6.5 Two-Stage Screen-and-Code Knowledge Graph Ensemble

To convert massive observational associations into a computable, typed clinical knowledge graph, TAXIS couples statistical prefiltering with a **Two-Stage Screen-and-Code Ensemble**:

```
┌────────────────────────────────────────────────────────────────────────┐
│  Phase A: Statistical Association Prefiltering (SQL / R)               │
│  • Distinct person support threshold: N_AB ≥ 100 (v57 production)      │
│  • Unadjusted person lift > 1.20 and Stratified lift > 1.50            │
│  • Continuity-corrected Odds Ratio (p < 0.001)                         │
│  • Directionality Ratio (DR) precedence categorization                 │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Filtered Candidate Pairs
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│  Phase B, Stage 1: Two-Stage LLM Screen (Functional Class Screening)   │
│  • Screen candidate pairs into 5 Top-Level Clinical Classes (CPT-6):    │
│    - Class I: Causal & Etiologic (24 codes / 7 families)               │
│    - Class II: Diagnostic & Indicative (22 codes / 6 families)         │
│    - Class III: Therapeutic & Interventional (26 codes / 8 families)   │
│    - Class IV: Prognostic & Disease Evolution (20 codes / 6 families)  │
│    - Class V: Associational & Phenotypic (20 codes / 5 families)       │
│  • Multi-Model Consensus Ensemble (triplicate sampling, kappa ≥ 0.85)  │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Classified Clinical Pairs
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│  Phase B, Stage 2: Precision Relation Coding (112 Standardized Codes)  │
│  • Fine-grained relation code assignment from selected class catalog   │
│  • Strict Inverse Relation symmetry for bidirectional graph navigation  │
│  • Directionality Precedence: DR ≥ 1.50 (forward), DR ≤ 0.67 (reverse), │
│    [0.67, 1.50] (balanced precedence; distinct from same-day ties N_A=B)│
│  • Blinded Physician Adjudication (Overhage & Grannis sample ledger)   │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Graded, Typed Clinical Edges
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│  TAXIS Clinical Knowledge Graph (1.9M Graded Edges across 17K Concepts)│
└────────────────────────────────────────────────────────────────────────┘
```

#### Pipeline Configuration Reconciliation

| Pipeline Component | Exploratory Concept AB (v0.5, 2025) | Production INPC Pipeline (v57, 2026) | Network Evaluation Specification (v1.0, 2026) |
|---|---|---|---|
| **Distinct Person Support** | $N_{AB} \ge 50$ | $N_{AB} \ge 100$ | $N_{AB} \ge 100$ (configurable $\ge 50$ for smaller CDMs) |
| **Association Metrics** | Crude Odds Ratio ($OR$) | Unadjusted Lift $> 1.20$; Stratified Lift $> 1.50$ | Dual Lift Reporting (Unadjusted & Stratified) |
| **Statistical Significance** | None (crude ranking) | Continuity-corrected $OR$ ($p < 0.001$) | Two-sided Fisher's exact / asymptotic test ($p < 0.001$) |
| **Windowing Design** | Symmetric $\pm 30$ days | Chronic-onset hazard (365d wash-in, 730d follow-up) | Standardized asymmetric hazard windows |
| **Stage 1 Screening** | Manual heuristic (early 4-model exploration) | Multi-Model Consensus Ensemble (triplicate sampling, majority $\ge 2\text{ of } 3$, $\kappa \ge 0.85$, 5 functional classes) | Pre-computed knowledge graph lookup |
| **Stage 2 Classification** | Binary association | 112 taxonomy codes (32 families / 5 classes) with inverse symmetry | Standardized edge semantics & qualifiers |

> **Ensemble Configuration & Version Crosswalk**: Early exploratory prototyping (v0.5, early 2025) tested an unweighted 4-model binary gate. For production association mining across 2.16M INPC records (Pipeline v57 / CPT-6, 2026), the architecture was standardized to the **Two-Stage Screen-and-Code Framework**: Stage 1 screens candidate concept pairs into 5 functional clinical classes using a triplicate consensus ensemble ($T = 0.0, 0.2, 0.4$ with majority $\ge 2\text{ of } 3$ agreement, achieving empirical inter-annotator $\kappa \ge 0.85$); Stage 2 assigns one of 112 precision taxonomy codes with strict inverse relation symmetry and directional precedence verification. Downstream network packages (v1.0) utilize the pre-compiled knowledge graph lookup to eliminate external API runtime variance.
> **Technical Pipeline Specification**: For complete SQL architecture, batch partitioning parameters, and table schemas, see the technical manual: [TAXIS Concept AB Association Mining Engine (Pipeline v57)](../mining/CONCEPT_AB_MINING_ENGINE_V57.md).  
> **Taxonomic Knowledge Graph Specification**: For the complete 112 relation code catalog, directional precedence boundaries, and LLM screen-and-code prompts, see [TAXIS Clinical Pair Taxonomy v6.0](../knowledge_graph/Clinical_Pair_Taxonomy_6.md) and [Two-Stage LLM Semantic Classification Framework](../../examples/taxonomy/prompts_and_examples.md).

### 6.6 Downstream Methodological Applications

#### 1. Automated Phenotype Recreation & Concept Set Optimization
- **Neuro-Symbolic Proposer-Validator Architecture**: Operationalizes the dual cognitive architecture (Kahneman System 1 vs. System 2) formalized by the OHDSI Phenotype Development and Evaluation Workgroup (Rao et al., 2026). The neural component (associative Concept AB co-occurrence mining across 2.16M patients paired with the two-stage screen-and-code LLM ensemble) acts as the **Proposer**, discovering and typing candidate multi-domain clinical associations and mitigating ungrounded hallucinations through empirical data grounding. The symbolic component (`build_1032.py`) acts as the **Structural Compiler and Validator**, compiling candidate relationships into deterministic, syntactically auditable Circe JSON logic slots. Substantive clinical validity and phenotype diagnostic performance are evaluated separately through expert clinical adjudication and empirical measurement across partner CDMs using `CohortDiagnostics` and `PheValuator`.
- **Harmonization with Structured Clinical Description Prompts**: Directly connects the OHDSI Phenotype Development and Evaluation Workgroup standard prompt schema (`clinicalDescriptionPromptBriefWithExclusions.txt`) to automated Circe synthesis specifications, establishing a deterministic 1-to-1 semantic slot mapping into computable criteria blocks:
  - *Condition Overview & Presentation* $\rightarrow$ Primary Anchor Disorder (`PrimaryCriteria.CriteriaList`).
  - *Laboratory Tests & Diagnostic Values* $\rightarrow$ Confirmatory Labs (`InclusionRules` with `Measurement` domain criteria, guideline thresholds, and qualifying temporal windows $[-7, +30]$ days).
  - *Medications Usually Given* $\rightarrow$ Indicated Drug Exposures (`InclusionRules` with `DrugExposure` domain criteria: acute $\le 24$ hours, chronic $\le 30$ days).
  - *Differential Diagnoses & Excluded Conditions* $\rightarrow$ Rule-Out Mimics (`InclusionRules` with Occurrence = 0 or `CensoringCriteria`), strictly subject to the 10% anchor patient cost cap.
  - *Comorbid Conditions* $\rightarrow$ Baseline Patient Characterization & Covariate Balance (explicitly segregated to avoid false exclusions).
  - *Prognosis & Follow-up* $\rightarrow$ Post-Index Observation Windows (`PostDays`) and persistence logic.
  - *References* $\rightarrow$ Circe Definition Metadata & Provenance Tags.
- **v2 Phenotype Generation Baseline (DEC-GR-007)**: Automated phenotype generation adheres to the agreed v2 release baseline enforcing `PrimaryCriteriaLimit: First` (earliest diagnosis), capturing initial incident presentation. Multi-event and recurrent episode handling is slated for collaborator review in v3.
- **Configurable Rule-Out Mimic Filter (DEC-GR-008)**: Differential mimic exclusions are managed via a configurable parameter with an agreed default cap of **10%** (calculated as $\frac{|A \cap \text{Mimic}|}{|A|}$, the proportion of anchor patients eliminated). Candidate exclusions discarding $\ge 10\%$ of anchor patients are flagged or dropped to protect diagnostic sensitivity.
- **Parsimonious Concept Set Condensation**: Integrates with algorithmic set-covering optimization tools (e.g., `ConceptSetCondenser`) to produce minimal, human-auditable Circe expressions combining `includeDescendants = TRUE` and explicit exclusions without altering cohort membership.

#### 2. Candidate Negative Control Generation
- **Mechanism-Based Causal Null Screening**: Identifies candidate negative control outcomes by querying the knowledge graph for concept pairs with an absence of documented clinical, etiologic, or therapeutic mechanisms across all 112 taxonomy codes.
- **Decoupling Causal Nulls from Observational Conditioning**: Rather than conditioning negative control eligibility on observed statistical nulls in evaluation data (which discards the very confounding bias empirical calibration seeks to measure), TAXIS provides causal-null candidates for independent clinician and literature review. Baseline observational metrics ($\text{Lift}$, $DR$) are reported as characterization diagnostics. Pre-specified negative control batteries are then evaluated across partner CDMs to construct empirical null distributions for systematic error calibration.

#### 3. Confounder Identification & Balance Evaluation
- **Informing Study Design**: Uses explicit relationship semantics to help investigators distinguish true baseline confounders from downstream complications or treatment side effects, preventing over-adjustment bias.
- **Confounder Balance**: Provides a clinical basis to evaluate whether essential confounders achieve balance across treatment cohorts.

> [!NOTE]
> **Aspirational Vision & Downstream Horizon (`DEC-GR-061`)**:  
> While Sub-aims 1 (Circe cohort synthesis) and 2–3 (negative controls and confounding control) are directly operationalized in Phase 1 study tooling (`extras/`), Sub-aims 4 (Automated Causal DAG Construction) and 5 (Computable Patient Narratives & HALE) represent prospective architectural horizons enabled by the TAXIS relationship layer, formally tracked under the [TAXIS Future Architectural Roadmap](../roadmap/TAXIS_FUTURE_ARCHITECTURAL_ROADMAP.md).

#### 4. Foundation for Judea Pearl's Causal Inference & Automated DAG Construction
- **Automating Structural Causal Models**: In observational epidemiology (e.g., comparative effectiveness and drug safety surveillance), identifying valid causal effects requires constructing Directed Acyclic Graphs (DAGs) under Judea Pearl's structural causal framework. In current practice, epidemiologists must draw DAGs by hand based on subjective clinical intuition, manually guessing which covariates represent true confounders, intermediate mediators, colliders, or instruments.
- **The TAXIS Structural Graph Substrate**: By establishing an empirical, evidence-weighted knowledge graph of what causes what ($A \to B$ complications and disease evolution in Class IV), what indicates what (diagnostic tests and therapeutic indications in Classes II and III), and what causes adverse events, TAXIS provides the **computable ontological substrate to automate principled, structural causal DAG generation**. This allows automated identification of minimal sufficient adjustment sets and shields observational studies from collider-stratification bias and intermediate-variable overadjustment.

#### 5. The Computable Patient Narrative & Health-Adjusted Life Expectancy (HALE)
- **Beyond Static Knowledge Graphs**: The ultimate clinical objective of the TAXIS relationship layer is to assemble longitudinal fact-table records into a coherent **computable patient narrative**. By combining condition progression, diagnostic testing delays, and the Bill of Materials nested care hierarchy, the narrative models the full patient journey from initial presentation to disease control or complication emergence.
- **Quantifying Opportunities to Improve Outcomes**: By comparing real-world observed care against evidence-grounded care pathways, the framework establishes a day-by-day estimate of a patient's **Health-Adjusted Life Expectancy (HALE)**. Variances from best practice (e.g., missed diabetic surveillance, delayed intervention in chronic kidney disease) are mapped to expected life-expectancy and well-being deficits, creating a unified clinical yardstick to systematically evaluate and prioritize opportunities to improve healthcare outcomes at population scale.

### 6.7 Independent Development vs. Final Evaluation Boundary Protocol
To guard against circular overfitting—where a phenotype algorithm is iteratively modified simply to reproduce an evaluation model rather than genuine clinical truth:
1. **Exploratory Development Partition**: Exploratory model training (`PheValuator`) and graph feedback are restricted to designated development partitions or internal development CDMs.
2. **Algorithm Freezing**: Circe JSON definitions, inclusion rules, and concept sets are locked and versioned prior to formal performance evaluation.
3. **Independent Validation**: Final diagnostic performance characteristics (Sensitivity, Specificity, PPV, NPV, F1 Score) are measured strictly on held-out test partitions or across independent external partner CDMs.

---

## 7. Data Governance, Suppression & Open Science Licensing

1. **Small-Cell Suppression Policy**: Participating sites apply small-cell suppression to any cell count where $1 \le N < 5$ (`minCellCount = 5`), or stricter thresholds where required by local institutional policy.
2. **Complementary Cell Protection**: Output generation algorithms audit marginal totals to prevent algebraic reconstruction of suppressed values.
3. **Open-Source Licensing**: Study packages, Circe cohort definitions, and technical specifications are distributed under the **Apache 2.0** license. Documentation and protocol specifications are released under **Creative Commons Attribution 4.0 International (CC-BY-4.0)**.
4. **Academic Attribution**: Contributing data partners retain institutional autonomy and are invited to co-author resulting network publications in accordance with standard **ICMJE guidelines**.

---

## 8. References & Foundational Literature

1. **Bandeian SH, Tompkins CP, Davison A.** A Future Health Care Analytic System: Part 1—What the Destination Looks Like & Part 2—Building Blocks and Implementation Roadmap. In: *Healthcare Information Management Systems: Cases, Strategies, and Solutions*. 5th ed. Cham: Springer; 2022.
2. **Rao GA, et al.** OHDSI Phenotype Library Version 3.0: Autonomous Governance and Agentic Clinical Cohort Engineering. *OHDSI Global Symposium 2026 Proceedings*; 2026.
3. **Ostropolets A, et al.** PHOEBE 2.0: selecting the right concept sets for the right patients using lexical, semantic, and data-driven recommendations. *OHDSI Symposium*; 2022. (Available: https://www.ohdsi.org/wp-content/uploads/2022/10/6-Ostropolets_Phoebe2.0-abstract.pdf).
4. **Swerdel JN, et al.** PheValuator: Development and evaluation of a phenotype algorithm evaluator. *J Biomed Inform*. 2019;97:103258.
5. **Schuemie MJ, et al.** Improving reproducibility by using high-throughput observational studies with empirical calibration. *Philos Trans A Math Phys Eng Sci*. 2018;376(2128):20170356.
6. **Schuemie MJ.** *PhenotypingAgent: Autonomous Cohort Engineering via LangGraph State Machines*. GitHub repository: `schuemie/PhenotypingAgent`; 2026.
7. **Schuemie MJ.** *ConceptSetCondenser: Algorithmic Set-Covering Optimization for OMOP Concept Sets*. GitHub repository: `schuemie/ConceptSetCondenser`; 2026.
8. **Shoaibi A, Ostropolets A, Weaver J, Rao G, et al.** Variation in phenotype definitions in observational clinical research: a review of three conditions. *AMIA Annu Symp Proc*. 2024.
9. **Shoaibi A, Ostropolets A, Murphy JD, Rao GA, et al.** Clinical Descriptions as Semantic Anchors: A Best Practice in OHDSI Phenotype Development. *OHDSI Phenotype Development and Evaluation Workgroup Consensus Statement*; 2025.
10. **Rao GA, et al.** Neuro-Symbolic Conceptual Workflows for Phenotyping in Observational Research: The Proposer-Validator Architecture. *OHDSI Phenotype Development and Evaluation Workgroup*; 2026.
