# TAXIS Phenotyping Engine: Phenotype Phebruary 2026 Integration Architecture
## The 6-Bucket Clinical Element Slot Engine, Multi-Tiered AMI Flagship, and Interactive Adjudication Module

> **Document Type**: Scientific Architecture & Implementation Specification  
> **Source Foundation**: OHDSI Phenotype Development & Evaluation Workgroup — *Phenotype Phebruary / Aphril 2026*  
> **Originating Presentations**:  
> • *Phenotype Aphril: Week 1 — How to get a "black box" to reliably and reproducibly Phenotype and do it better than humans?* (Gowtham Rao, MD, PhD, April 7, 2026)  
> • *Phenotype Aphril: Week 2 — The Foundation of Reliable Real World Evidence through Phenotype Evaluation* (April 14, 2026)  
> **Authoritative Decisions**:  
> • `DEC-GR-007`: Circe JSON Phenotype Synthesis via Standardized Clinical Descriptions  
> • `DEC-GR-010`: Dual Lift Reporting & Decile Stratification Architecture  
> • `DEC-GR-018`: ATLAS v3.0, Pythia AI Agent & TrexSQL Integration Roadmap  
> • `DEC-GR-020`: Attribution & Recognition of Dr. Stephen H. Bandeian for all SQL & Original Analytic Code  
> • `DEC-GR-021`: 6-Bucket Clinical Element Architecture & Multi-Tiered Flagship AMI Evaluation  
> **Study Leadership**:  
> • Stephen H. Bandeian, MD, JD – Principal Investigator, Johns Hopkins University School of Medicine (Original SQL & Analytic Code Author)  
> • J. Marc Overhage, MD, PhD – Co-Principal Investigator, The Overhage Group / Indiana University School of Medicine  
> • Gowtham Rao, MD, PhD – Investigator, CoReason, Inc. USA; OHDSI Phenotype Development & Evaluation Workgroup Lead  
> • Shaun Grannis, MD, MS – Investigator, Regenstrief Institute / Indiana University School of Medicine  

---

## 1. Executive Summary & Workgroup Mandate

During **Phenotype Phebruary / Aphril 2026**, the OHDSI Phenotype Development and Evaluation Workgroup established key annual Objectives and Key Results (OKRs) for community phenotyping:
- **KR 1.1**: Benchmark an iterative, empirically grounded, AI-assisted workflow collaboratively across diverse Real-World Data (RWD) network sources (Q1 2026).
- **KR 1.2**: Finalize and submit the *"Minds Meet Machines"* manuscript to a high-impact informatics journal (Q1 2026).
- **KR 1.3**: Develop a gold standard for phenotype algorithms for specific data sources to evaluate independent pipelines (Q3 2026).
- **KR 1.4**: Develop, test, and validate a robust AI-assisted pipeline for clinical phenotypes by September 2026.
- **KR 1.5**: Populate the OHDSI Phenotype Library with $\ge 100$ new phenotypes using AI and demonstrate the methodology at the 2026 OHDSI Global Symposium (Collaborator Showcase #127).

A central challenge highlighted in the Workgroup sessions is the **Phenotyping Input Bottleneck**:
> *"How do we create the input concept sets for each clinical element associated with disease status? Multiple alternative directions to explore: (1) Expert manual curation, (2) Create a knowledge graph containing all concept-concept relationships to enable standard extraction (Bandeian & Overhage, 2025 OHDSI Symposium), or (3) Create an LLM-agent pipeline to dynamically construct concept sets based on the phenotype of interest."*

Furthermore, empirical analysis presented in the Workgroup revealed profound discordance when relying on diagnosis codes alone:
1. **High Rule-Out Contamination**: Among persons undergoing diagnostic work-ups for acute conditions, the majority of evaluated patients do not actually have the disease (the classic "rule-out" presentation in Emergency Departments).
2. **Multi-Domain Clustering in True Cases**: Patients with bona-fide diagnoses almost universally present with supportive observations across multiple clinical domains (confirmatory laboratory biomarkers, invasive interventions, and disease-specific secondary pharmacotherapy). It is exceedingly rare to observe an acute event in isolation without downstream corroboration.
3. **Problem-List Carry-Forward**: Outpatient administrative codes often reflect historical records or problem-list carry-overs rather than incident acute events.

**TAXIS directly unifies these streams** by fusing Dr. Stephen H. Bandeian's 40-batch Concept AB Mining Engine (Pipeline v57 across 2.16M longitudinal patients) with a 112-code clinical relationship taxonomy and Circe JSON synthesis. This specification formalizes the **6-Bucket Clinical Element Architecture**, the **Multi-Tiered Phenotype Generation Engine**, the **Flagship Acute Myocardial Infarction (AMI) Study**, and the **Interactive Adjudication Module** for ATLAS v3.0, Pythia, and the Phenotype Library.

---

## 2. The 6-Bucket Clinical Element Slot Architecture

To eliminate arbitrary, bespoke phenotype design, TAXIS operationalizes the 6 core clinical elements defined in Dr. Gowtham Rao's Phenotype Phebruary framework (Slide 18) as deterministic computable slots. Each bucket maps directly to TAXIS empirical association pairs, temporal precedence ratios ($DR$), and standard Circe criteria blocks:

```text
┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                 THE 6-BUCKET CLINICAL ELEMENT SLOT ARCHITECTURE                        │
└───────────────────────────────────────────────────┬────────────────────────────────────────────────────┘
                                                    │
    ┌───────────────────────┬───────────────────────┼───────────────────────┬────────────────────────┐
    ▼                       ▼                       ▼                       ▼                        ▼
┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐ ┌────────────────────┐
│ BUCKET 1:        │ │ BUCKET 2:        │ │ BUCKET 3:        │ │ BUCKET 4:        │ │ BUCKET 5:          │
│ PRIMARY ANCHOR   │ │ CLINICAL SYMPTOMS│ │ DIAGNOSTIC LABS  │ │ THERAPEUTIC      │ │ ACUTE / SUBSEQUENT │
│ (Condition)      │ │ & PRESENTATION   │ │ & PROCEDURES     │ │ INTERVENTIONS    │ │ COMPLICATIONS      │
│                  │ │                  │ │                  │ │                  │ │                    │
│ • Incident index │ │ • Symptoms/signs │ │ • Confirmatory   │ │ • Definitive     │ │ • Downstream       │
│   presentation   │ │ • Non-specific   │ │   biomarkers     │ │   procedures     │ │   organ failure    │
│ • Primary vs     │ │   presentation   │ │ • Diagnostic     │ │ • Acute disease- │ │ • Chronological    │
│   secondary code │ │   at t ∈ [-7, 0] │ │   imaging/ECG    │ │   specific drugs │ │   progression      │
└─────────┬────────┘ └─────────┬────────┘ └─────────┬────────┘ └─────────┬────────┘ └─────────┬──────────┘
          │                    │                    │                    │                    │
          └────────────────────┼────────────────────┴────────────────────┼────────────────────┘
                               │                                         │
                               ▼                                         ▼
                    ┌────────────────────────┐                ┌────────────────────────┐
                    │ BUCKET 6:              │                │ SYNTHESIS ENGINE:      │
                    │ ALTERNATIVE DIAGNOSES  │                │ MULTI-TIERED CIRCE     │
                    │ & EXCLUSIONARY MIMICS  │                │ COHORT DEFINITIONS     │
                    │                        │                │                        │
                    │ • Competing causes     │                │ • Tier 1: Strict       │
                    │ • Rule-out diagnoses   │                │ • Tier 2: Surveillance │
                    │ • Censoring mimics     │                │ • xSpec / xSens Cohorts│
                    └────────────────────────┘                └────────────────────────┘
```

### 2.1 Bucket Mapping Matrix

| Bucket # | Clinical Element Definition | TAXIS Association RelCodes | OMOP CDM Domain | Circe Criteria Placement | Temporal Window ($\Delta t$) |
|---|---|---|---|---|---|
| **Bucket 1** | **Diagnosis of Interest (Primary Anchor)** | Self-concept (`PrimaryCriteria`) | Condition | `PrimaryCriteria.CriteriaList` | Index Day ($t = 0$) |
| **Bucket 2** | **Symptoms & Clinical Findings** | `ASSOC_SYMPTOM`, `ASSOC_SIGN` | Condition, Observation | `InclusionRules` (Corroborating) | $[-7, +1]$ days |
| **Bucket 3** | **Diagnostic Labs & Testing Procedures** | `DIAG_LAB_CONFIRMATORY`, `DIAG_TEST_INDICATED` | Measurement, Procedure | `InclusionRules` (Confirmatory) | $[-1, +3]$ days |
| **Bucket 4** | **Therapeutic Interventions (Rx & Proc)** | `THER_FIRST_LINE`, `THER_INTERVENTION_PROC` | DrugExposure, Procedure | `InclusionRules` (Infarct/Event Therapy) | $[0, +2]$ days |
| **Bucket 5** | **Acute & Downstream Complications** | `PROG_COMPLICATION` | Condition | Characterization / Secondary Covariates | $[+1, +30]$ days |
| **Bucket 6** | **Alternative Diagnoses & Rule-Out Mimics** | `ASSOC_MIMIC`, `DIAG_RULE_OUT` | Condition | `CensoringCriteria` or Exclusion Rules | $[0, +7]$ days |

---

## 3. Multi-Tiered Circe Phenotype Generation Engine

A major finding from the Phenotype Phebruary case reviews is that a single cohort definition cannot serve all epidemiological use cases:
- Clinical trials and comparative safety studies demand **High Specificity (Target Positive Predictive Value $\ge 90\%$)** to prevent hazard dilution from false positives (such as rule-out encounters without true disease).
- Disease surveillance and natural history tracking require **High Sensitivity (Target Sensitivity $\ge 95\%$)** to avoid undercounting patients who died before interventional procedures or who were managed conservatively.

TAXIS synthesizes **three coordinated cohort tiers** for every clinical concept:

### Tier 1: Strict / Epidemiologic Cohort (High Specificity — Comparative Safety & Trials)
- **Methodological Design**: Formulated as a **treatment-enriched, high-specificity cohort** designed to eliminate non-case rule-out evaluations in comparative effectiveness research. While clinical consensus definitions (e.g. Fourth Universal Definition of Myocardial Infarction) define ischemic injury biochemically and clinically regardless of whether invasive therapy occurs, requiring procedural or acute pharmacological intervention serves as an established epidemiological design filter for high Positive Predictive Value.
- **Anchor Requirement**: Inpatient hospitalization or Emergency Department visit with primary diagnosis of interest.
- **Intervention Gate**: Requires at least one definitive therapeutic procedure (`THER_INTERVENTION_PROC`) OR acute, disease-specific inpatient pharmacotherapy initiation (`THER_FIRST_LINE`) within $[0, +2]$ days of index.
  - *Methodological Conditioning Note*: Requiring therapeutic intervention within $[0, +2]$ days of index and $\ge 90$ days secondary prevention persistence conditions on post-index events. For comparative-safety or causal studies, immortal time and post-index selection must be formally addressed (e.g., via landmark designs or time-dependent confounding adjustments) rather than treating raw Tier 1 as an unadjusted causal baseline.
- **Confirmatory Testing**: Requires at least one documented diagnostic test or confirmatory laboratory measurement (`DIAG_LAB_CONFIRMATORY`) within $[-1, +2]$ days.
- **Mimic Exclusions**: Excludes patients with primary competing diagnoses coded concurrently without definitive interventional therapy.
- **Target Design Thresholds**: Specificity $\ge 98\%$, PPV $\ge 92\%$.

### Tier 2: Broad / Surveillance Cohort (High Sensitivity — Incidence & Natural History)
- **Anchor Requirement**: Inpatient, Emergency Department, or intensive outpatient encounter with diagnosis of interest in any position (primary or secondary).
- **Testing Requirement**: Requires at least one diagnostic procedure or laboratory measurement order within $[-7, +7]$ days, confirming clinical suspicion.
- **Intervention Gate**: Optional (does not mandate invasive procedures, ensuring elderly, frail, or comfort-care patients are retained).
- **Target Design Thresholds**: Sensitivity $\ge 95\%$, Specificity $\ge 88\%$.

### Tier 3: Diagnostic Evaluator Cohorts for Automated PheValuator Calibration
- **Extremely Specific Cohort (`xSpec`)**: Tier 1 + positive biomarker result + secondary prevention persistence $\ge 90$ days. Serves as noisy positive training set for `PheValuator::createEvaluationCohort`.
- **Extremely Sensitive Cohort (`xSens`)**: Formulated strictly in accordance with OHDSI `PheValuator` methodology as a **broad non-case exclusion zone**. Encompasses any patient presenting with suggestive symptoms, related diagnostic codes, or work-up orders within $\pm 30$ days. During predictive model training, any patient inside the `xSens` boundary who is not in `xSpec` is **excluded from the negative training set**, preventing plausible, mild, or conservatively managed cases from contaminating the noisy control pool. Label-defining diagnosis, procedure, drug, and laboratory measurement features are strictly excluded from predictive covariates during model fitting. Full model calibration additionally requires empirical prevalence calibration and validation on held-out test splits.

---

## 4. Flagship Case Study: Acute Myocardial Infarction (AMI)

Acute Myocardial Infarction (AMI) serves as the primary flagship demonstration of the 6-bucket slot engine. The educational vignettes below are newly authored synthetic clinical archetypes illustrating how multi-tiered Circe definitions and TAXIS knowledge-graph slots systematically evaluate canonical presentation patterns (e.g., clear-cut inpatient STEMI, historical infarction, emergency department chest pain rule-out, and under-coded acute arrest).

*Synthetic Clinical Archetype Generation Basis*: All clinical scenarios presented in this section are synthetic educational archetypes newly designed for the TAXIS phenotyping integration specification. They do not incorporate real patient identifiers, hospital EHR records, or private clinical traces; rather, each scenario provides an illustrative archetype of specific slot-matching permutations and anticipated tier classifications.

```text
┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                         FLAGSHIP CASE STUDY: ACUTE MYOCARDIAL INFARCTION (AMI)                         │
└───────────────────────────────────────────────────┬────────────────────────────────────────────────────┘
                                                    │
    ┌───────────────────────┬───────────────────────┼───────────────────────┬────────────────────────┐
    ▼                       ▼                       ▼                       ▼                        ▼
┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐ ┌────────────────────┐
│ BUCKET 1: ANCHOR │ │ BUCKET 2: SYMPTOMS│ │ BUCKET 3: DIAGS  │ │ BUCKET 4: RX/PROC│ │ BUCKET 5: COMPLIC. │
│                  │ │                  │ │                  │ │                  │ │                    │
│ • Acute STEMI    │ │ • Chest pain     │ │ • Troponin I / T │ │ • PCI (stent)    │ │ • Cardiogenic shock│
│ • Acute NSTEMI   │ │ • Diaphoresis    │ │ • CK-MB fraction │ │ • CABG surgery   │ │ • Heart failure    │
│ • Inpatient / ED │ │ • Dyspnea        │ │ • 12-lead ECG    │ │ • Tenecteplase   │ │ • Ventric. arrhythm│
│   presentation   │ │ • Nausea/vomiting│ │ • Coronary angio │ │ • P2Y12 (clopid.)│ │ • Anoxic brain inj │
└──────────────────┘ └──────────────────┘ └──────────────────┘ └──────────────────┘ └────────────────────┘
                                                    ▲
                                                    │
                                         ┌─────────────────────┐
                                         │ BUCKET 6: MIMICS    │
                                         │                     │
                                         │ • Acute gastritis   │
                                         │ • Aortic dissection │
                                         │ • Panic disorder    │
                                         │ • Esophageal reflux │
                                         └─────────────────────┘
```

### 4.1 Bucket Concept Sets & TAXIS Associational Metrics

1. **Bucket 1: Primary Diagnosis (Anchor)**
   - Concepts: `Acute myocardial infarction` (4329847), `STEMI` (314666), `NSTEMI` (312327).
   - Inpatient/ED filter: `visit_concept_id` in Inpatient (9201), Emergency (9203), Emergency+Inpatient (262).
2. **Bucket 2: Symptoms & Presentation**
   - Concepts: `Chest pain` (77670), `Dyspnea` (312437), `Diaphoresis` (438727), `Syncope` (442289).
   - Illustrative Exploratory TAXIS Lift: $Lift = 4.82$, $DR = 0.88$ (symmetric / co-presenting in $[-1, 0]$ days).
3. **Bucket 3: Diagnostics & Biomarkers**
   - Measurements: `Troponin I in Serum/Plasma` (3013650), `Troponin T in Serum/Plasma` (3048000), `Creatine kinase MB` (3007220).
   - Procedures: `12-lead Electrocardiogram` (4066543), `Coronary angiography` (4185932).
   - Key-packing: Packed measurement tests with abnormal high result ($test \times 10^9 + 1$).
4. **Bucket 4: Therapeutic Interventions (High-Specificity Differentiation)**
   - Procedures: `Percutaneous coronary intervention (PCI)` (4305509), `Coronary artery bypass graft (CABG)` (4140640).
   - Inpatient Drugs: `Tenecteplase` (1311037 — FDA-indicated for acute STEMI and acute ischemic stroke), `Clopidogrel` (1328165), `Ticagrelor` (40241331), `Unfractionated Heparin` (1367571), `Metoprolol` (1307046).
   - Illustrative Exploratory TAXIS Lift: $Lift = 14.6$, $DR = 2.45$ (strongly forward-directed: diagnosis precedes or accompanies PCI).
5. **Bucket 5: Complications & Prognosis**
   - Concepts: `Cardiogenic shock` (4134440), `Acute heart failure` (318443), `Ventricular tachycardia` (317576), `Cardiac arrest` (321042).
   - Illustrative Exploratory TAXIS Lift: $Lift = 8.90$, $DR = 1.95$ ($[+1, +30]$ days).
6. **Bucket 6: Alternative Diagnoses / Mimics (Censoring Criteria)**
   - Concepts: `Acute gastritis` (4275335), `Gastroesophageal reflux disease` (319835), `Panic disorder` (436070), `Thoracic aortic aneurysm/dissection` (4142905).
   - Rule: If a patient has single-day outpatient gastritis + esomeprazole with NO cardiology admission or interventions, censor as rule-out (matching Case 1816 and Case 626).

---

## 5. Interactive Adjudication Architecture: ATLAS v3.0 & Pythia Integration

In Phenotype Aphril Week 2, the community participated in interactive case adjudication using **KEEPER** ("Phinding Phenotypes with Phriends", Slides 16–48). To transition this from manual polling to an automated, reproducible workflow, TAXIS introduces an **Interactive Adjudication Bridge**:

```text
┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                           INTERACTIVE ADJUDICATION ARCHITECTURE (KEEPER - TAXIS - ATLAS)               │
└───────────────────────────────────────────────────┬────────────────────────────────────────────────────┘
                                                    │
                 ┌──────────────────────────────────┴──────────────────────────────────┐
                 ▼                                                                     ▼
    ┌───────────────────────────────┐                                     ┌───────────────────────────────┐
    │ ATLAS v3.0 / Pythia UI        │                                     │ Patient Timeline (KEEPER)     │
    │ • Adjudication scorecard      │                                     │ • Encounter sequence          │
    │ • Dynamic 6-bucket breakdown  │◄────────────────────────────────────┤ • Multi-domain events         │
    │ • Live case probability       │                                     │ • Inpatient/outpatient span   │
    └───────────────┬───────────────┘                                     └───────────────────────────────┘
                    │
                    ▼
    ┌───────────────────────────────┐
    │ TAXIS Adjudication Engine     │
    │ • Slot-matching evaluation    │
    │ • Directionality verification │
    │ • Stratified Lift calculation │
    └───────────────┬───────────────┘
                    │
                    ▼
    ┌─────────────────────────────────────────────────────────────────────────┐
    │ ADJUDICATION RESULT:                                                    │
    │ • Decision: [CASE / NOT A CASE]                                         │
    │ • Certainty: [HIGH / LOW]                                               │
    │ • Justification: Automated evidence synthesis across the 6 buckets      │
    └─────────────────────────────────────────────────────────────────────────┘
```

### 5.1 Adjudication Heuristics Mapped to TAXIS Metrics

| Synthetic Clinical Archetype | Illustrative Presentation Pattern | Anticipated Tier Classification | TAXIS Knowledge Graph Slot Evaluation |
|---|---|---|---|
| **Archetype AMI-01** (Primary Inpatient STEMI) | Day 0 Inpatient NSTEMI/STEMI + PCI (stent) on Day 0–2 + Clopidogrel | **Case (Tier 1 & Tier 2)** | Satisfies Buckets 1, 3, 4. Meets Tier 1 treatment-enriched criteria (acute diagnosis + forward revascularization), eliminating rule-out ambiguity for high-specificity studies. |
| **Archetype AMI-02** (Severe Multi-Vessel Event) | Emergent admission + cath/PCI + cardiogenic shock + P2Y12 | **Case (Tier 1 & Tier 2)** | Satisfies Buckets 1, 3, 4, 5. Meets Tier 1 criteria; multi-admission recurrence confirms severe acute CAD presentation. |
| **Archetype AMI-03** (ED Rule-Out with Mimic) | Outpatient/ED single day + Troponin/ECG + gastritis + esomeprazole | **Non-Case (Rule-Out)** | Fails Tier 1 intervention gate (zero revascularization/acute pharmacotherapy). Bucket 6 mimic (gastritis) documented alongside negative work-up. Categorized as non-case rule-out in high-specificity tier. |
| **Archetype AMI-04** (Historical Infarct Carry-Forward) | Outpatient codes for "Old MI" + secondary prevention + PCI on day 406 | **Non-Incident (Historical)** | Fails incident wash-in criteria ($\ge 365$ days clean baseline). Correctly flagged as historical event. |
| **Archetype AMI-05** (Problem List Artifact) | Outpatient carry-forward code at routine visit + zero cardiac meds | **Non-Case (Artifact)** | Fails Buckets 3 and 4. Identified as problem-list administrative artifact; does not meet acute encounter or diagnostic criteria in either tier. |
| **Archetype AMI-06** (Under-Coded Thrombolytic Rescue) | Cardiac arrest + cardiogenic shock + Tenecteplase, NO explicit AMI code | **Edge Case (Rescue Rule Target)** | Requires secondary clinical rescue logic (acute cardiac arrest, shock, and emergency thrombolysis without explicit primary AMI code); fails standard Tier 1/Tier 2 diagnosis anchor, illustrating edge-case capture under expanded rescue rules. |
| **Archetype AMI-07** (Diagnostic Cath without Intervention) | Angina primary + secondary AMI + cath (normal) + NO PCI or acute DAPT | **Non-Case in Tier 1 (Eligible in Tier 2)** | Diagnostic cath without revascularization fails Tier 1 strict treatment gate, reflecting lack of acute intervention. Eligible for Tier 2 surveillance evaluation pending diagnostic troponin/ECG confirmation. |

---

## 6. Batch Generation Strategy for 100 Phenotypes (2026 OKR KR 1.5)

To fulfill the Workgroup OKR of populating the OHDSI Phenotype Library with $\ge 100$ new phenotypes for the 2026 Global Symposium:
1. **Automated Clinical Description Ingestion**: The batch pipeline ingests structured Markdown Clinical Descriptions formatted per the Phenotype Workgroup template.
2. **Concept Set Extraction via Knowledge Graph**: For each anchor condition, TAXIS queries pre-computed INPC association matrices (`cab_s55_pair_all`) to automatically populate the 6 clinical element buckets.
3. **Circe JSON Synthesis**: Compiles Tier 1 (Strict), Tier 2 (Surveillance), `xSpec`, and `xSens` definitions into versioned Circe JSON files.
4. **Automated Package Assembly**: Packages cohorts into HADES-compliant study structures with embedded `CohortDiagnostics` and `PheValuator` execution scripts.

---

## 7. Compliance, Governance & Integrity Controls

1. **Zero-Mentions Compliance**: Prohibited individual names and internal network terms are strictly excluded from all code, commits, and public documentation.
2. **Scientific Attribution (`DEC-GR-020`)**: Full recognition is prominently preserved for Dr. Stephen H. Bandeian as the original author of all SQL scripts, partitioning logic, and analytic algorithms.
3. **Privacy Floor & Local Firewall Execution**: All exported cell counts $< 5$ are masked to $-1$ (`DEC-GR-005`). No patient-level records, person IDs, or clinical event timestamps leave local database environments.
4. **KEEPER Adjudication Bridge Isolation**: The interactive adjudication bridge ("Phinding Phenotypes with Phriends") and clinical timeline visualizer operate strictly within the local institutional network boundary behind the hospital firewall; patient timelines are never exported or transmitted across institutions. Case vignettes in public documentation are strictly synthetic educational illustrations.
