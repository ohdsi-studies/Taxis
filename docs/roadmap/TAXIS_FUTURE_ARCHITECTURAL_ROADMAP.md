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

---

## 3. Roadmap Item 2: Condition Sub-Episodes (Staging Progression & Acute Exacerbations)

### 3.1 The Clinical Problem
Chronic diseases (e.g., Chronic Obstructive Pulmonary Disease, Chronic Kidney Disease, Heart Failure) are lifelong conditions that exhibit periods of stability punctuated by **acute exacerbations** or **structural staging deterioration**. Treating chronic conditions as flat, single episodes obscures whether a treatment was initiated for maintenance control or acute emergency rescue.

### 3.2 Sub-Episode Architecture
TAXIS Phase 2 introduces nested **Condition Sub-Episodes**:
1. **Baseline Chronic Trajectory**: Spanning from initial clinical diagnosis through continuous observation.
2. **Acute Exacerbation Sub-Episodes**: High-density temporal clusters of acute interventions nested within the chronic episode (e.g., IV loop diuretics and hospital admission representing an acute decompensated heart failure sub-episode).
3. **Staging Progression Sub-Episodes**: Detected through formal code transitions (e.g., CKD Stage 3 $\to$ CKD Stage 4) or sustained biomarker shifts (e.g., persistent decline in estimated GFR).

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
