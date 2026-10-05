# TAXIS Future Architectural Roadmap & Clinical Design Philosophy
## Long-Term Research Horizon, Phase 2 Process Modeling & Advanced Epidemiological Extensions

> **Document Type**: Foundational Architectural Roadmap & Conceptual Vision  
> **Status**: Prospective Research Horizon (Phase 2 / Phase 3)  
> **Authoritative Governance**: `DEC-GR-061` (The Three-Tier Operational & Documentation Standard)  
> **Originating Source**: Formulated by Dr. Stephen H. Bandeian in foundational health analytics working papers and synthesized from core study leadership working sessions with Dr. J. Marc Overhage, Dr. Shaun Grannis, and Dr. Gowtham Rao.

---

## 1. Executive Summary & The Three-Tier Architecture

To preserve absolute scientific rigor and transparent communication across the OHDSI community, the TAXIS network initiative establishes an explicit **Three-Tier Architecture (`DEC-GR-061`)** separating runnable production code from operational post-processing and long-term aspirational visions:

```text
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        THE THREE-TIER TAXIS ARCHITECTURE (DEC-GR-061)                  │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ TIER 1: RELEASED SQL ENGINE (PRODUCTION CORE)                                          │
│ • Codebase: inst/sql/sql_server/*.sql, docs/mining/sql/*.sql, R/RunMining.R            │
│ • Implementation: 40-batch random partitioning, 24 domain-pair classes, 3-tier key    │
│   packing, decile utilization stratification, symmetric [-W, +W] co-occurrence,       │
│   raw directional proportions (dir_ab), and small-cell suppression (<5 -> -1).        │
│ • Status: RELEASED, FROZEN, AND EXECUTABLE ACROSS OHDSI CDMs.                          │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ TIER 2: PRODUCTION POST-PROCESSING & VALIDATION ANALYTICS (OPERATIONAL)                │
│ • Codebase: R/, extras/TaxisPhenotypeEvaluation/, extras/applications/                 │
│ • Implementation: Continuity-corrected Directionality Ratio (DR), DerSimonian-Laird    │
│   random-effects meta-analysis pooling, The Six-Point Empirical Validation Framework   │
│   (benchmarked against PheKB, ClinVec, and OPL), and blinded clinician review.        │
│ • Status: OPERATIONAL POST-ANALYTICS EXECUTED ON AGGREGATE MATRICES.                   │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ TIER 3: FUTURE ARCHITECTURAL ROADMAP & THEORETICAL VISION (PHASE 2 HORIZON)            │
│ • Specifications: This document (docs/roadmap/TAXIS_FUTURE_ARCHITECTURAL_ROADMAP.md)  │
│ • Frameworks: Bill of Materials (BOM) care processes, Condition Sub-Episodes, 5-tier   │
│   lab binning, declarative control tables, Judea Pearl causal DAG automation, and      │
│   Computable Patient Narratives with Health-Adjusted Life Expectancy (HALE).           │
│ • Status: PROSPECTIVE RESEARCH ROADMAP (PLANNED FOR PHASE 2 & PHASE 3 ENHANCEMENTS).   │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

This document details the **Tier 3 Prospective Roadmap**, providing the conceptual foundation and clinical design philosophy that will guide future iterations of the TAXIS network study.

### 1.1 The Historical Evolution of Evidence-Based Medicine (EBM 1.0 to EBM 2.0)
The TAXIS relationship layer addresses a fundamental structural limitation in the historical progression of medical evidence:
- **1850s–1900s (Observational Foundations)**: John Snow’s epidemiological cholera investigations established empirical disease mapping and population-level risk analysis.
- **1920s–1950s (Statistical Methodologies)**: Ronald Fisher, Austin Bradford Hill, and Jerome Cornfield formalized mathematical statistics, observational cohort designs, and the Randomized Controlled Trial (RCT).
- **1990s–2010s (Evidence-Based Medicine 1.0)**: The Cochrane Collaboration and David Sackett established systematic reviews, meta-analyses, and clinical practice guidelines. While foundational, EBM 1.0 possesses intrinsic structural boundaries: evidence remains fragmented across isolated trials, guidelines target the statistical "average patient", clinical trials routinely exclude multimorbid patients, and clinicians are forced to synthesize disparate findings on an *ad hoc* basis.
- **2020s–2050s (Evidence-Based Medicine 2.0)**: Enabled by widespread electronic health record capture and the OMOP Common Data Model, EBM 2.0 unlocks continuous real-world evidence from representative populations. However, out-of-the-box OMOP stores clinical events as fragmented point-in-time fact records (occurrences, exposures, measurements) without the connective clinical reasoning clinicians intuitively apply. TAXIS provides this computable relational substrate, assembling flat fact tables into coherent longitudinal clinical narratives.

### 1.2 Grounding in Structure-Process-Outcome (SPO) and Systems Engineering (SEIPS)
To systematically identify opportunities to improve care at population scale, the TAXIS conceptual architecture is explicitly grounded in Avedis Donabedian's **Structure-Process-Outcome (SPO)** model (1966) and the **Systems Engineering Initiative for Patient Safety (SEIPS)** framework:
1. **Structure (Contextual Root Causes)**: Patient-level factors (access barriers, social determinants of health, language, economic constraints) and clinician/delivery-system infrastructure (diagnostic tools, team staffing, practice incentives).
2. **Process (Mediating Decisions & Healthcare Actions)**: Diagnostic timeliness, guideline treatment selection, medication adherence, care coordination, and procedural execution.
3. **Outcomes & Resource Deficits**: Preventable disease progression, acute flares, hospital readmissions, prolonged symptom burdens, and excess expenditures.

Under this model, variances between guideline-recommended care and observed patient trajectories are quantified as **mediating causes** that explain downstream health deficits.

---

## 2. Roadmap Item 1: The "Bill of Materials" (BOM) Process-of-Care Architecture

### 2.1 The Clinical Rationale
Clinical care is not an unstructured flat list of billing codes; it is a **nested hierarchy of clinical processes and subprocesses**, directly analogous to a manufacturing **Bill of Materials (BOM)** (e.g., how an aircraft or automobile is assembled from assemblies, subassemblies, and components). 

Current observational research frameworks treat healthcare encounters as isolated, unordered point-events. The BOM architecture organizes healthcare encounters into a multi-tiered structural hierarchy:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                   LEVEL 1 (L1): PROBLEM CARE EPISODE                   │
│   • Triggered by index recognition of an illness, injury, or risk      │
│   • Spans initial presentation, evaluation, treatment, and follow-up   │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Orchestrates
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                   LEVEL 2 (L2): PROCEDURAL ANCHOR                      │
│   • Principal unit of care per encounter (inpatient or ambulatory)     │
│   • Ranked deterministically via clinical invasiveness (CMS RBCS/BTOS) │
│     (Major Surgery > Inpatient > Emergency > Therapy > Imaging > Lab)  │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Bundles Supporting Care
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                  SUPPORTING SERVICE NESTED HIERARCHY                   │
│   • Pre-Service Suitability & Risk: [-30, 0] days before anchor        │
│   • Intra-Service Support: Anesthesia, perfusion, vein harvest, ECG    │
│   • Post-Service Surveillance: [0, +90] days recovery & complications  │
└────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Deterministic Ranking via Invasiveness Hierarchy
Within an encounter, multiple procedures are frequently billed simultaneously. To identify the dominant clinical anchor without manual heuristics, Level 2 Procedural Anchors are ranked deterministically by clinical invasiveness using CMS Restructured Betos Classification System (RBCS / BTOS) categories crosswalked to SNOMED:
1. **Major Surgical Procedures** (e.g., CABG, total joint arthroplasty, colectomy)
2. **Inpatient Medical Admissions** (e.g., acute decompensated heart failure, pneumonia)
3. **Emergency Interventions** (e.g., resuscitation, emergency cardioversion)
4. **Therapeutic Series / Treatment Courses** (e.g., chemotherapy, radiation, physical therapy)
5. **Advanced Diagnostic Imaging** (e.g., CT angiography, MRI)
6. **Routine Diagnostic Assays & Labs** (e.g., blood cultures, metabolic panels)
7. **Evaluation & Management (E&M) Visits** (e.g., outpatient follow-up)

### 2.3 Extended Lookback and Lookforward Windows around Anchors
For major procedures, the analytical unit is defined as $A \to B \mid C_{\text{anchor}}$, evaluating auxiliary services in defined clinical horizons:
- **Pre-Service Window ($[-30, 0\text{ days}]$)**: Pre-operative risk stratification, cardiology clearance, anesthesia assessment, cross-matching.
- **Intra-Service Encounter (Day 0)**: Operating room anesthesia, hemodynamic monitoring, vein harvesting.
- **Post-Service Surveillance Window ($[0, +90\text{ days}]$)**: Post-operative wound care, deep vein thrombosis prophylaxis, physical therapy, and complication surveillance.

### 2.4 The 4-Level Concrete Bill of Materials (BOM) Decomposition
In manufacturing, a Bill of Materials recursively decomposes an aircraft or automobile into assemblies, subassemblies, and discrete parts. In clinical delivery, care is structured across four standardized hierarchical tiers:

```text
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                   THE 4-LEVEL CLINICAL PROCESS-OF-CARE HIERARCHY                       │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ LEVEL 1: MAJOR CLINICAL TASKS (GENERIC PROCESS STEPS)                                  │
│ • Initial Presentation ──► Diagnostic Evaluation ──► Treatment Planning ──►            │
│   Treatment Execution ──► Recovery & Surveillance ──► 2° Prevention ──► Rehabilitation │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ LEVEL 2: PRINCIPAL UNITS OF CARE (CLINICAL INTERVENTIONS)                              │
│ • Defined by the dominant procedural anchor (e.g., CABG Surgery, Hip Fracture Repair) │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ LEVEL 3: SUBTASKS & SUBUNITS OF CARE (ORCHESTRATED COMPONENTS)                         │
│ • Pre-op clearance, Anesthesia induction, Swan-Ganz catheterization, Saphenous vein    │
│   harvesting, Cardiopulmonary bypass, Graft anastomosis, Post-op wound management      │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ LEVEL 4: DISCRETE SERVICES & STEPS (CLAIM-LEVEL FACTS)                                 │
│ • Specific clinical actions (e.g., for Swan-Ganz: central vein insertion, catheter     │
│   positioning into PA, post-insertion confirmatory portable chest X-ray)               │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

#### Clinical Exemplar: Hip Fracture Care Norms
- **Health Problem**: Traumatic Femoral Neck Fracture (`Level 1 Task: Treatment`).
- **Unit of Care (Level 2)**: Hip fracture repair (hemiarthroplasty vs. total joint replacement).
- **Subtask Norm (Level 3)**: Prevention of post-operative deep vein thrombosis (DVT).
- **Subunit of Care (Level 3)**: Daily post-operative anticoagulation for 14 days starting on Day 1.
- **Service Step (Level 4)**: Enoxaparin sodium 40 mg subcutaneous daily.

### 2.5 "Cycles of Care" as a Longitudinal Complexity & Failure Metric
Care delivery for complex conditions is rarely a linear progression. When an initial treatment fails, clinical tasks must cycle repeatedly:
- Each major process step (diagnostic workup, therapeutic stabilization, rehabilitative recovery) may exhibit multiple iterative cycles.
- The overall complexity and quality of care for an episode can be evaluated by measuring:
  1. The **number of cycles** required to achieve clinical stabilization.
  2. The **cumulative cost and outcome** of each successive cycle.
  3. Patients experiencing high cycle counts represent diagnostic delays, therapeutic non-responsiveness, or recurrent disease flares.

### 2.6 Shared Patient-Clinician Responsibilities & Mediating Variances
Clinical outcomes depend on a collaborative partnership between patient and clinician:
- **Clinician Responsibilities**: Timely diagnostic evaluation, guideline-directed medical therapy selection, coordination across specialist teams, proactive surveillance.
- **Patient Responsibilities**: Prompt presentation upon symptom emergence, appointment adherence, prescribed medication persistence, communicating side effects.

Variances between EHR-recorded clinician recommendations (e.g., ordered diagnostic tests, prescribed medications, follow-up intervals) and subsequent patient actions (e.g., unfilled prescriptions, missed follow-ups) serve as quantifiable **mediating causes** that explain downstream health disparities and preventable adverse outcomes.

---

## 3. Roadmap Item 2: Condition Sub-Episodes (Staging Progression & Acute Exacerbations)

### 3.1 The Clinical Problem
Chronic diseases (e.g., Chronic Obstructive Pulmonary Disease, Chronic Kidney Disease, Heart Failure) are lifelong conditions that exhibit periods of stability punctuated by **acute exacerbations** or **structural staging deterioration**. Treating chronic conditions as flat, single episodes obscures whether a treatment was initiated for maintenance control or acute emergency rescue.

### 3.2 Sub-Episode Architecture
TAXIS Phase 2 introduces nested **Condition Sub-Episodes**:
1. **Baseline Chronic Trajectory**: Spanning from initial clinical diagnosis through continuous observation.
2. **Acute Exacerbation Sub-Episodes**: High-density temporal clusters of acute interventions nested within the chronic episode (e.g., IV loop diuretics and hospital admission representing an acute decompensated heart failure sub-episode).
3. **Staging Progression Sub-Episodes**: Detected through formal code transitions (e.g., CKD Stage 3 $\to$ CKD Stage 4) or sustained biomarker shifts (e.g., persistent decline in estimated GFR).

### 3.3 Coronary Artery Disease (CAD) Two-Axis Sub-Episode Matrix
As formulated in Dr. Bandeian's clinical logic specifications, chronic conditions can be partitioned across two independent clinical dimensions: **Disease Control (Acuity)** and **Disease Staging**:

| Sub-Episode Dimension | Clinical Sub-Episode | Operational Trigger | Window Duration | Control Tier | Stage Tier |
|---|---|---|---|:---:|:---:|
| **Control Axis (Acuity)** | **Acute Myocardial Infarction (AMI)** | Inpatient hospital admission for AMI | 90 days | **Level 4** | — |
| | **Unstable Angina** | Inpatient hospital admission for unstable angina | $\ge 90$ days | **Level 3** | — |
| | **Stable Angina** | E&M, ED, or Inpatient encounter with angina | $\ge 90$ days | **Level 2** | — |
| | **Stable CAD** | Absence of acute ischemic events in patient with CAD | Indefinite | **Level 1** | — |
| **Staging Axis (Progression)** | **Stable CAD s/p AMI** | Period following 90 days post-AMI event | Indefinite | — | **Stage 4** |
| | **Stable CAD s/p Revascularization** | Period following 90 days post-CABG or PCI | Indefinite | — | **Stage 2** |
| | **CAD with Chronic Angina** | Persistent exertional angina in documented CAD | Indefinite | — | **Stage 2** |
| | **Stable CAD without Angina** | Asymptomatic chronic coronary disease | Indefinite | — | **Stage 1** |

### 3.4 Cascading Multi-Order Complications & Working Diagnosis Resolution
Flat concept-pair associations cannot capture multi-hop cascading pathophysiological trajectories. Phase 2 introduces an iterative **6-Step Sequential Causal Linkage Algorithm**:
1. **`epi_1` (Raw Diagnosis Capture)**: Unlinked incoming diagnostic codes recorded across encounters.
2. **`epi_2` (Symptom & Finding Attribution)**: Links presenting symptoms and physical findings to the inciting condition (e.g., `cough` and `leukocytosis` linked to `pneumonia`).
3. **`epi_3` (Working Diagnosis Resolution)**: Merges preliminary working diagnoses into the confirmed definitive diagnosis (e.g., merging `acute bronchitis` into confirmed `bacterial pneumonia`).
4. **`epi_4` (1st-Order Complication Linkage)**: Links immediate acute systemic complications to the primary pathology (e.g., `pneumonia` $\to$ `severe sepsis`).
5. **`epi_5` (2nd-Order Complication Linkage)**: Links secondary organ system failures to the systemic cascade (e.g., `sepsis` $\to$ `acute renal failure`).
6. **`epi_6` (3rd-Order Complication Linkage)**: Links tertiary downstream electrolyte and metabolic derangements to secondary organ failure (e.g., `acute renal failure` $\to$ `hyperkalemia`).

This multi-order recursive linkage traces complex inpatient clinical trajectories back to their primary etiologic anchor.

---

## 4. Roadmap Item 3: Five-Tier Qualitative & Quantitative Lab Result Binning

### 4.1 Transition from 3-Tier to 5-Tier Binning
The released Phase 1 SQL engine (`concept_ab_batch.sql`) implements a robust 3-tier range comparison (`Low`, `High`, `Normal`) alongside categorical value-concept pass-throughs. The Phase 2 roadmap extends continuous laboratory measurements into a standardized **Five-Tier Result Binning System**:

| Tier Code | Semantic Classification | Operational Criterion | Clinical Example |
|:---:|---|---|---|
| **`N`** | Normal / Within Limits | $\text{range\_low} \le \text{value} \le \text{range\_high}$ | Fasting Glucose = 88 mg/dL |
| **`L`** | Moderate Low | $\text{value} < \text{range\_low}$ (non-panic) | Fasting Glucose = 65 mg/dL |
| **`LL`** | Critical Panic Low | $\text{value} \ll \text{range\_low}$ (life-threatening) | Serum Potassium < 2.5 mEq/L |
| **`H`** | Moderate High | $\text{value} > \text{range\_high}$ (non-panic) | Fasting Glucose = 118 mg/dL |
| **`HH`** | Critical Panic High | $\text{value} \gg \text{range\_high}$ (life-threatening) | Troponin I > 5.0 ng/mL, Glucose > 400 mg/dL |

### 4.2 Impact on Knowledge Discovery
By distinguishing moderate elevations from panic-level derangements, the mining engine directly connects discrete laboratory findings to acute diagnosis concepts ($A \to B$)—such as linking Troponin (HH) to Acute Myocardial Infarction while separating routine screening HbA1c from acute diabetic ketoacidosis.

---

## 5. Roadmap Item 4: Table-Driven Declarative Control Architecture

### 5.1 The Need for Declarative Decoupling
The released Phase 1 pipeline executes a monolithic 7,600-line T-SQL script (`concept_ab_batch.sql`). While highly optimized for performance, adding new domain pairs or altering temporal horizons requires modifying complex SQL routines.

### 5.2 The Control Table Specification
The Phase 2 architecture replaces hardcoded SQL branching with a **declarative Control Table** (`cab_control_spec`):
- Each row defines an independent concept-pair configuration:
  * Domain pair identifier (`pair_class_id`: `Dx-Dx`, `Dx-Drg`, `Dx-Proc`, `Dx-Meas`)
  * Chronicity configuration (`ongoing` vs. `time-limited` for concepts A and B)
  * Window width parameters (`lookback_days`, `lookforward_days`, `buffer_days`)
  * Allowable semantic relationships injected into downstream LLM adjudication
  * Versioned prompt template identifier
- The execution engine iterates over rows in the control table, dynamically parameterizing extraction queries and LLM prompts. Subsequent study waves require only updating or appending rows to the control table, ensuring fully automated, reproducible knowledge rediscovery.

---

## 6. Roadmap Item 5: Automated Structural Causal DAG Generation (Judea Pearl Framework)

### 6.1 The Epidemiological Bottleneck
In observational comparative effectiveness research and safety surveillance, identifying unbiased causal effects requires constructing Directed Acyclic Graphs (DAGs) under Judea Pearl's structural causal framework. Currently, investigators draw DAGs by hand based on subjective clinical intuition, manually guessing which covariates constitute true confounders, intermediate mediators, colliders, or instruments.

### 6.2 The TAXIS Automated Substrate
Because TAXIS establishes an empirical, evidence-weighted knowledge graph of what causes what (etiology and complications), what indicates what (diagnostic tests and therapeutic indications), and what causes adverse events, TAXIS provides the **computable ontological substrate to automate structural causal DAG generation**:
- Automatically identifies minimal sufficient adjustment sets for targeted treatment-outcome pairs.
- Flags and eliminates potential collider variables to prevent collider-stratification bias.
- Identifies intermediate variables to prevent over-adjustment bias.

### 6.3 Competitive Causality & Empirical Probability Ratios
In multimorbid clinical reality, patients frequently present with clinical findings that could be attributed to multiple competing underlying conditions. For example, a patient with both a long-standing history of alcohol abuse and a recent cerebral infarction develops an acute speech/language impairment. Which condition is the causative anchor?

Rather than relying on arbitrary clinician heuristic rules, the TAXIS knowledge graph provides the empirical substrate to calculate **Time-Decayed Conditional Probabilities**:
- By querying empirical lag distributions (`cab_s37_lag_all`), the model computes:
  $$P(\text{Finding } B \mid \text{Condition } A_1, \Delta t_1) \quad \text{vs.} \quad P(\text{Finding } B \mid \text{Condition } A_2, \Delta t_2)$$
- In Dr. Bandeian's clinical demonstration ledger:
  * For a patient with Alcohol Abuse documented 90 days prior: $P(\text{Speech Deficit} \mid \text{Alcohol Abuse}, \Delta t = 90\text{d}) = 0.0007$.
  * For the same patient with Cerebral Embolism / Stroke documented 30 days prior: $P(\text{Speech Deficit} \mid \text{Stroke}, \Delta t = 30\text{d}) = 0.0533$.
  * The resulting **Probability Ratio is 76 : 1 in favor of Stroke**, providing a quantitative, transparent mechanism to attribute complications in multimorbid patients.

---

## 7. Roadmap Item 6: The Computable Patient Narrative & Health-Adjusted Life Expectancy (HALE)

### 7.1 Beyond Static Pairwise Graphs
The ultimate clinical objective of the TAXIS clinical relationship layer is to assemble longitudinal fact-table records into a coherent **computable patient narrative**:
1. **Health Problem Trajectory**: Chronic baseline diseases, acute exacerbations, diagnostic delays, and complication emergence over calendar time.
2. **Process of Care**: The nested BOM care delivery hierarchy across outpatient, inpatient, surgical, and post-acute settings.
3. **Outcomes & Quality Deficits**: Comparing observed care against optimal clinical pathways to quantify deviations from best practice.

### 7.2 The HALE Common Yardstick
To compare outcomes across entirely different diseases (e.g., cancer care vs. diabetes control), TAXIS envisions mapping patient trajectories to **Health-Adjusted Life Expectancy (HALE)** or Quality-Adjusted Life Years (QALYs):
- Variances from best practice (e.g., omitted diabetic eye exams, delayed antibiotic initiation in sepsis, failure to prescribe beta-blockers post-MI) are translated into estimated life-expectancy and functional deficits.
- This creates a **"Common Yardstick"** allowing health systems and public health researchers to identify and prioritize the greatest opportunities to improve health outcomes at population scale.

### 7.3 Contextual Factors Starter-Set for Population Health Analytics
To fully operationalize Donabedian Structure-Process-Outcome (SPO) analytics, Phase 3 incorporates a standardized starter-set of patient- and provider-level contextual factors:
- **Patient Contextual Factors**:
  * Geo-coded neighborhood socioeconomic disadvantage indices, including the **Area Deprivation Index (ADI)** and the CDC **Social Vulnerability Index (SVI)** linked via 9-digit or 5-digit ZIP codes.
  * Standardized social determinants of health (SDOH) Z-codes mapped into OMOP observation records.
- **Provider & Health System Contextual Factors**:
  * National Provider Identifier (NPI) organizational attributes via **NPPES**.
  * Institutional capabilities and bed capacities via the **CMS Provider of Services (POS)** file.
  * Regional healthcare resource density and health professional shortage areas (HPSAs) via the **HRSA Area Resource File (ARF)**.

---

## 8. Roadmap Item 7: The Living Learning Health System & Continuous Federated Synthesis

### 8.1 Continuous Knowledge Rediscovery
Rather than treating association mining as a one-time static exercise, Phase 3 envisions an automated **Living Learning Health System**:
- Participating health systems execute standardized, containerized mining jobs periodically (e.g., annually or upon CDM refreshes).
- Masked aggregate matrices are federated to the central coordination layer.
- Random-effects meta-analysis dynamically updates edge weights, tracks secular trends in medical practice (e.g., adoption of SGLT2 inhibitors or GLP-1 receptor agonists), and triggers targeted clinical review for newly emerging clinical associations.

---

## 9. Implementation Phasing & Workstream Governance

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        TAXIS DEVELOPMENT HORIZONS                      │
├────────────────────────────────────────────────────────────────────────┤
│ PHASE 1: CURRENT PRODUCTION (2025–2026)                                │
│ • Symmetric pairwise association mining (Pipeline v57 T-SQL released). │
│ • 14 domain-pair classes across 2.16M patient INPC benchmark.          │
│ • Initial 5-phenotype evaluation workstream across network CDMs.       │
│ • Publication of 1.9M concept pairs under open-source licenses.        │
├────────────────────────────────────────────────────────────────────────┤
│ PHASE 2: PROCESS MODELING & DECLARATIVE ENGINE (2026–2027)             │
│ • Declarative control-table architecture for automated mining.         │
│ • Bill of Materials (BOM) Level 1/Level 2 episode trigger extraction.  │
│ • Condition Sub-Episode modeling (acute exacerbations & staging).      │
│ • Five-tier qualitative/quantitative lab result binning (LL/HH).       │
├────────────────────────────────────────────────────────────────────────┤
│ PHASE 3: CAUSAL NARRATIVES & LEARNING HEALTH SYSTEM (2027+)            │
│ • Automated Judea Pearl structural causal DAG generation.              │
│ • Computable patient narratives with HALE outcomes scoring.            │
│ • Continuous multi-site federated evidence accumulation.               │
└────────────────────────────────────────────────────────────────────────┘
```

By strictly maintaining this Three-Tier standard, the TAXIS study provides the observational research community with immediate, verified, and executable association software today, while establishing a transparent, peer-auditable roadmap for next-generation clinical informatics.
