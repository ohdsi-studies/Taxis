# TAXIS Phenotyping Engine: Phenotype Phebruary & Workgroup Integration Architecture
## The 6-Bucket Clinical Element Slot Engine, Multi-Tiered AMI Flagship, Objective Diagnostics, and Federated Phenomics

> **Document Type**: Scientific Architecture, Implementation Specification & Federated Workgroup Crosswalk  
> **Source Foundation**: OHDSI Phenotype Development & Evaluation Workgroup  
> **Primary Forum Discussions**:  
> • *OHDSI Phenotype Workgroup Updates* ([OHDSI Forum Topic 20940](https://forums.ohdsi.org/t/ohdsi-phenotype-workgroup-updates/20940))  
> • *Phenotype Phebruary in Aphril 2026* ([OHDSI Forum Topic 25158](https://forums.ohdsi.org/t/ohdsi-phenotype-phebruary-in-aphril-2026/25158))  
> **Key Originating Presentations & Workgroup Sessions**:  
> • *Phenotype Aphril: Week 1 — How to get a "black box" to reliably and reproducibly Phenotype and do it better than humans?* (Gowtham Rao, MD, PhD)  
> • *Phenotype Aphril: Week 2 — The Foundation of Reliable Real World Evidence through Phenotype Evaluation*  
> • *Objective Diagnostics for Phenotype Evaluation* (Azza Shoaibi, PhD & Gowtham Rao, MD, PhD)  
> • *Measurement Error Integration & Phenotype Sensitivity* (James Weaver, MS)  
> • *Probabilistic Phenotyping & Clinical Trial Concordance* (Joel Swerdel, PhD)  
> • *VA CIPHER & OHDSI Phenotype Library Cross-Walk* (Jackie Honerlaw, RN, MPH)  
> • *DARWIN EU Standardized Phenotyping Workflow* (Albert Prats-Uribe, MD, PhD)  
> • *The Book of OHDSI (2025 Edition) Phenotyping Chapter Consensus*  
> **Authoritative Decisions**:  
> • `DEC-GR-007`: Circe JSON Phenotype Synthesis via Standardized Clinical Descriptions (`PrimaryCriteriaLimit: First` Baseline)  
> • `DEC-GR-010`: Dual Lift Reporting & Decile Stratification Architecture  
> • `DEC-GR-018`: ATLAS v3.0, Pythia AI Agent & TrexSQL Integration Roadmap  
> • `DEC-GR-020`: Attribution & Recognition of Dr. Stephen H. Bandeian for all SQL & Original Analytic Code  
> • `DEC-GR-021`: 6-Bucket Clinical Element Architecture & Multi-Tiered Flagship AMI Evaluation  
> • `DEC-GR-022`: Complete Synthetic Provenance for Case Vignettes; Private Archiving of Slide Transcripts  
> **Study Leadership**:  
> • Stephen H. Bandeian, MD, JD – Principal Investigator, Johns Hopkins University School of Medicine (Original SQL & Analytic Code Author)  
> • J. Marc Overhage, MD, PhD – Co-Principal Investigator, The Overhage Group / Indiana University School of Medicine  
> • Gowtham Rao, MD, PhD – Investigator, CoReason, Inc. USA; OHDSI Phenotype Development & Evaluation Workgroup Lead  
> • Shaun Grannis, MD, MS – Investigator, Regenstrief Institute / Indiana University School of Medicine  

---

## 1. Executive Summary & Workgroup Mandate

During the multi-year deliberations of the **OHDSI Phenotype Development & Evaluation Workgroup**—spanning the annual *Phenotype Phebruary* campaigns, the regular workgroup updates ([Topic 20940](https://forums.ohdsi.org/t/ohdsi-phenotype-workgroup-updates/20940)), and the dedicated *Phenotype Aphril 2026* intensive series ([Topic 25158](https://forums.ohdsi.org/t/ohdsi-phenotype-phebruary-in-aphril-2026/25158))—the international community established a comprehensive set of Objectives and Key Results (OKRs):

- **KR 1.1**: Benchmark an iterative, empirically grounded, AI-assisted phenotyping workflow collaboratively across diverse Real-World Data (RWD) network sources.
- **KR 1.2**: Finalize and submit the landmark collaborative manuscript *"Minds Meet Machines: Human-AI Collaboration for Computable Phenotype Engineering"* to a leading medical informatics journal.
- **KR 1.3**: Establish an objective diagnostic standard for phenotype stability across calendar time and network data sources.
- **KR 1.4**: Overcome the foundational **Phenotyping Input Bottleneck**: replace bespoke, manual concept curation with an automated, neuro-symbolic pipeline linking clinical knowledge graphs and large language models with deterministic OMOP CDM validators.
- **KR 1.5**: Populate the OHDSI Phenotype Library with $\ge 100$ newly validated phenotypes for the 2026 Global Symposium (Demonstrated in Collaborator Showcase #127).

### The Book of OHDSI (2025 Edition) 4-Stage Phenotyping Loop

A pivotal consensus reached within the Workgroup and codified in the updated *Book of OHDSI (2025 Edition)* phenotyping chapter is that phenotyping is not a single linear coding step, but rather a **4-stage iterative development loop**:

```text
┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                      THE BOOK OF OHDSI (2025) 4-STAGE ITERATIVE PHENOTYPING LOOP                       │
└───────────────────────────────────────────────────┬────────────────────────────────────────────────────┘
                                                    │
                 ┌──────────────────────────────────┴──────────────────────────────────┐
                 ▼                                                                     ▼
    ┌───────────────────────────────┐                                     ┌───────────────────────────────┐
    │ 1. IDEA                       │                                     │ 2. IMPLEMENTATION             │
    │ • Clinical Description        │                                     │ • Concept Set Expressions     │
    │ • 6D Clinical Elements        │────────────────────────────────────►│ • Circe JSON Cohort Logic     │
    │ • Target Population Scope     │                                     │ • Multi-Tiered Thresholds     │
    └───────────────────────────────┘                                     └───────────────┬───────────────┘
                 ▲                                                                        │
                 │                                                                        ▼
    ┌────────────┴──────────────────┐                                     ┌───────────────────────────────┐
    │ 4. TRUST                      │                                     │ 3. ITERATION                  │
    │ • Phenotype Library Storage   │                                     │ • CohortDiagnostics Profiling │
    │ • Objective Spline Stability  │◄────────────────────────────────────│ • CohortDiagnostics Lite      │
    │ • Diagnostic Evaluation / ROC │                                     │ • Error Sensitivity Analysis  │
    └───────────────────────────────┘                                     └───────────────────────────────┘
```

1. **Idea (Clinical Description)**: Defining disease boundaries through standardized clinical descriptions structured into six clinical dimensions (symptoms, labs, procedures, interventions, complications, mimics).
2. **Implementation (Circe Logic)**: Mapping clinical concepts into computable OMOP CDM concept sets and temporal inclusion criteria.
3. **Iteration (Diagnostic Levers)**: Utilizing `CohortDiagnostics` and `CohortDiagnostics Lite` *during design* as iterative engineering tools (evaluating index event breakdown, visit context, prior observation, and incidence trends) rather than as a post-hoc grading hurdle.
4. **Trust (Validation & Stability)**: Establishing empirical credibility via objective temporal stability testing, diagnostic error estimation (`PheValuator`), and clinical adjudication before depositing versioned artifacts into the OHDSI Phenotype Library.

TAXIS directly operationalizes this 4-stage cycle by coupling Dr. Stephen H. Bandeian's 40-batch Concept AB Mining Engine (Pipeline v57 across 2.16M longitudinal patients) with the 112-code clinical relationship taxonomy, the 6-bucket slot architecture, and automated HADES package generators.

---

## 2. The Neuro-Symbolic Proposer-Validator Framework & RWD Error Taxonomy

### 2.1 Proposer-Validator Neuro-Symbolic Architecture

Discussions in Topic 25158 emphasized that neither pure large language models (LLMs) nor pure manual rule-crafting can resolve the clinical phenotyping bottleneck alone:
- **LLMs as Creative Proposers**: LLMs excel at semantic expansion, clinical terminology translation, and identifying obscure clinical synonyms, diagnostic mimics, and guideline nuances. However, unconstrained LLMs suffer from hallucination, lack awareness of local vocabulary mapping idiosyncrasies, and cannot guarantee deterministic execution.
- **TAXIS & Circe as Deterministic Validators**: The OMOP Common Data Model, SQL/Circe rules, and the Concept AB association matrix act as the rigid, symbolic validator. The validator tests whether proposed concepts actually exist in real patient data, enforces temporal boundaries, calculates empirical association lift, and executes reproducible cohort generation.

```text
┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                              NEURO-SYMBOLIC PROPOSER-VALIDATOR ARCHITECTURE                            │
└───────────────────────────────────────────────────┬────────────────────────────────────────────────────┘
                                                    │
                 ┌──────────────────────────────────┴──────────────────────────────────┐
                 ▼                                                                     ▼
    ┌───────────────────────────────┐                                     ┌───────────────────────────────┐
    │ NEURAL PROPOSER               │                                     │ SYMBOLIC VALIDATOR            │
    │ (LLM / Clinical Agent)        │                                     │ (TAXIS Engine / Circe / CDM)  │
    │                               │                                     │                               │
    │ • Clinical Description Parser │                                     │ • Concept AB Association Graph│
    │ • Synonym & Code Generator    │────────────────────────────────────►│ • Empirical Lift & Direction  │
    │ • Mimic & Biomarker Proposer  │      Candidate Concept Vectors      │ • OMOP CDM Vocabulary Anchor  │
    │ • 6D Slot Assignment          │                                     │ • Circe JSON Compiler         │
    └───────────────────────────────┘                                     └───────────────┬───────────────┘
                 ▲                                                                        │
                 │                     Empirical Feedback & Diagnostics                   │
                 └────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Real-World Data (RWD) Cardiology Error Taxonomy

Empirical chart reviews and interactive workgroup sessions (Topic 25158, Slides 16–48) revealed that relying strictly on primary diagnosis codes induces severe systematic error:

```text
┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                REAL-WORLD DATA CARDIOLOGY ERROR TAXONOMY                               │
└───────────────────────────────────┬───────────────────────────────────┬────────────────────────────────┘
                                    │                                   │
                                    ▼                                   ▼
             ┌──────────────────────────────────────────────┐ ┌──────────────────────────────────────────────┐
             │ FALSE POSITIVE DRIVERS (Specificity Deficits)│ │ FALSE NEGATIVE DRIVERS (Sensitivity Deficits)│
             ├──────────────────────────────────────────────┤ ├──────────────────────────────────────────────┤
             │ 1. Emergency Department "Rule-Out" Codes:    │ │ 1. Physician "Click Fatigue":                │
             │    Provisional billing codes assigned during │ │    During emergency resuscitation, providers │
             │    acute chest pain evaluations where enzyme │ │    often select generic "chest pain" or      │
             │    biomarkers and angiography are normal.    │ │    "CAD" codes while AMI is in text notes.   │
             │                                              │ │                                              │
             │ 2. Problem-List "Copy-Forward" Macros:       │ │ 2. Surgical & Procedural Silos:              │
             │    Historical AMI diagnoses duplicated       │ │    Post-operative infarcts occurring during  │
             │    automatically into outpatient encounter   │ │    CABG or non-cardiac surgery are often     │
             │    diagnoses years after the acute event.    │ │    coded solely as surgical complications.   │
             │                                              │ │                                              │
             │ 3. Isolated Biomarker Elevations:            │ │ 3. Out-of-Hospital / Pre-Arrival Death:      │
             │    Troponin leaks due to renal failure or    │ │    Fatal acute events where patients expire  │
             │    sepsis (myocardial injury, not infarct).  │ │    prior to hospital admission or lab draw.  │
             └──────────────────────────────────────────────┘ └──────────────────────────────────────────────┘
```

To neutralize these error modes, TAXIS structures phenotyping logic into six distinct clinical element slots.

---

## 3. The 6-Bucket Clinical Element Slot Architecture

TAXIS translates the 6-dimensional clinical element framework formulated in Topic 25158 into deterministic computable slots. Each bucket maps directly to TAXIS empirical association pairs, temporal precedence ratios ($DR$), and standard Circe criteria blocks:

```text
┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                 THE 6-BUCKET CLINICAL ELEMENT SLOT ARCHITECTURE                        │
└───────────────────────────────────────────────────┬────────────────────────────────────────────────────┘
                                                    │
     ┌───────────────────────┬──────────────────────┼──────────────────────┬────────────────────────┐
     ▼                       ▼                      ▼                      ▼                        ▼
┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐ ┌────────────────────┐
│ BUCKET 1:        │ │ BUCKET 2:        │ │ BUCKET 3:        │ │ BUCKET 4:        │ │ BUCKET 5:          │
│ PRIMARY ANCHOR   │ │ CLINICAL SYMPTOMS│ │ DIAGNOSTIC LABS  │ │ THERAPEUTIC      │ │ ACUTE / SUBSEQUENT │
│ (Condition)      │ │ & PRESENTATION   │ │ & PROCEDURES     │ │ INTERVENTIONS    │ │ COMPLICATIONS      │
│                  │ │                  │ │                  │ │                  │ │                    │
│ • Incident index │ │ • Symptoms/signs │ │ • Confirmatory   │ │ • Definitive     │ │ • Downstream       │
│   presentation   │ │ • Non-specific   │ │   biomarkers     │ │   procedures     │ │   organ failure    │
│ • Inpatient vs   │ │   presentation   │ │ • Diagnostic     │ │ • Acute disease- │ │ • Chronological    │
│   outpatient code│ │   at t ∈ [-7, 0] │ │   imaging/ECG    │ │   specific drugs │ │   progression      │
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

### 3.1 Bucket Mapping Matrix

| Bucket # | Clinical Element Definition | TAXIS Association RelCodes | OMOP CDM Domain | Circe Criteria Placement | Temporal Window ($\Delta t$) |
|---|---|---|---|---|---|
| **Bucket 1** | **Diagnosis of Interest (Primary Anchor)** | Self-concept (`PrimaryCriteria`) | Condition | `PrimaryCriteria.CriteriaList` | Index Day ($t = 0$) |
| **Bucket 2** | **Symptoms & Clinical Findings** | `ASSOC_SYMPTOM`, `ASSOC_SIGN` | Condition, Observation | `InclusionRules` (Corroborating) | $[-7, +1]$ days |
| **Bucket 3** | **Diagnostic Labs & Testing Procedures** | `DIAG_LAB_CONFIRMATORY`, `DIAG_TEST_INDICATED` | Measurement, Procedure | `InclusionRules` (Confirmatory) | $[-1, +3]$ days |
| **Bucket 4** | **Therapeutic Interventions (Rx & Proc)** | `THER_FIRST_LINE`, `THER_INTERVENTION_PROC` | DrugExposure, Procedure | `InclusionRules` (Infarct/Event Therapy) | $[0, +2]$ days |
| **Bucket 5** | **Acute & Downstream Complications** | `PROG_COMPLICATION` | Condition | Characterization / Secondary Covariates | $[+1, +30]$ days |
| **Bucket 6** | **Alternative Diagnoses & Rule-Out Mimics** | `ASSOC_MIMIC`, `DIAG_RULE_OUT` | Condition | `CensoringCriteria` or Exclusion Rules | $[0, +7]$ days |

---

## 4. Multi-Tiered Circe Phenotype Generation Engine & Measurement Error

### 4.1 Measurement Error Sensitivity (James Weaver Analysis)

Workgroup presentations by James Weaver ([Topic 20940](https://forums.ohdsi.org/t/ohdsi-phenotype-workgroup-updates/20940)) demonstrated that small, unstandardized variations in phenotype logic induce massive divergence in epidemiological metrics:
- In an empirical evaluation of **Major Depressive Disorder (MDD)** across network databases, varying phenotype criteria (inpatient vs. outpatient settings, 1 code vs. 2 codes within 30 days, requiring concurrent antidepressant prescriptions) resulted in an astounding **40-fold variation in calculated incidence rates**.
- If causal inference or comparative safety analyses are conducted without anchoring definitions to explicit specificity and sensitivity tiers, the resulting hazard ratios reflect phenotype selection bias rather than true pharmacological effect.

To resolve this, TAXIS systematically synthesizes **three coordinated cohort tiers** for every clinical concept:

### 4.2 Tier 1: Strict / Epidemiologic Cohort (High Specificity — Comparative Safety & Trials)
- **Design Target**: Positive Predictive Value $\ge 92\%$, Specificity $\ge 98\%$.
- **Methodological Design**: Treatment-enriched design structured to eliminate Emergency Department rule-outs and diagnostic evaluations from active-comparator cohorts. While clinical consensus definitions (e.g., the Fourth Universal Definition of MI) classify infarcts pathologically regardless of procedural intervention, requiring invasive revascularization or acute pharmacological therapy serves as an indispensable design filter for observational studies.
- **Anchor Criteria**: Inpatient hospitalization or Emergency Department visit with primary diagnosis of interest.
- **Intervention Gate**: Requires at least one definitive therapeutic procedure (`THER_INTERVENTION_PROC`) OR acute disease-specific pharmacotherapy (`THER_FIRST_LINE`) within $[0, +2]$ days of index.
- **Methodological Conditioning Guardrail**: Requiring $[0, +2]$ day interventions and 90-day secondary prevention persistence conditions on post-index events. For comparative-safety or causal studies, immortal time and post-index selection must be formally addressed (e.g., via landmark designs or time-dependent confounding adjustments) rather than treating raw Tier 1 as an unadjusted causal baseline.
- **Confirmatory Testing**: Requires at least one confirmatory laboratory biomarker or diagnostic procedure (`DIAG_LAB_CONFIRMATORY`) within $[-1, +2]$ days.
- **Mimic Exclusions**: Excludes patients with primary competing diagnoses coded concurrently without definitive interventional therapy.

### 4.3 Tier 2: Broad / Surveillance Cohort (High Sensitivity — Incidence & Natural History)
- **Design Target**: Sensitivity $\ge 95\%$, Specificity $\ge 88\%$.
- **Anchor Criteria**: Inpatient, Emergency Department, or intensive outpatient encounter with diagnosis of interest in any position (primary or secondary).
- **Testing Requirement**: Requires at least one diagnostic procedure or laboratory measurement order within $[-7, +7]$ days, confirming clinical suspicion.
- **Intervention Gate**: Optional (does not mandate invasive procedures, ensuring elderly, frail, palliative, or conservatively managed patients are preserved).

### 4.4 Tier 3: Diagnostic Evaluators & Probabilistic Phenotyping (Joel Swerdel Benchmarks)
- **Extremely Specific Cohort (`xSpec`)**: Tier 1 + positive biomarker result + secondary prevention persistence $\ge 90$ days. Serves as noisy positive training set for `PheValuator::createEvaluationCohort`.
- **Extremely Sensitive Cohort (`xSens`)**: Formulated strictly in accordance with OHDSI `PheValuator` methodology as a **broad non-case exclusion zone**. Encompasses any patient presenting with suggestive symptoms, related diagnostic codes, or work-up orders within $\pm 30$ days. During predictive model training, any patient inside the `xSens` boundary who is not in `xSpec` is **excluded from the negative training set**, preventing plausible, mild, or conservatively managed cases from contaminating the noisy control pool.
- **Covariate Exclusion Contract**: Label-defining diagnosis, procedure, drug, and laboratory measurement features are strictly excluded from predictive covariates during model fitting. Full model calibration additionally requires empirical prevalence calibration and validation on held-out test splits.
- **Clinical Trial Concordance (Joel Swerdel Findings)**: In rigorous empirical benchmarking against published clinical trial results presented in Topic 20940, **probabilistic phenotyping (L1-regularized LASSO logistic regression on noisy labels) achieved 77% concordance with trial confidence intervals**, compared to only **23% concordance for traditional deterministic rule-based phenotypes**. This establishes the critical value of TAXIS Tier 3 automated evaluator generation for predictive phenotyping.

---

## 5. Flagship Case Study: Acute Myocardial Infarction (AMI)

### 5.1 The Fourth Universal Definition of Myocardial Infarction in Real-World Data

Discussions in Topic 25158 highlighted the critical distinction established by the *Fourth Universal Definition of Myocardial Infarction (Thygesen et al., 2018)*:
- **Myocardial Injury**: Defined biochemically by an elevated cardiac troponin (cTn) value above the 99th percentile upper reference limit (URL). Injury is considered acute if there is a dynamic rise and/or fall. In real-world data, elevated troponins are frequently observed in non-ischemic settings: severe sepsis, end-stage renal disease, pulmonary embolism, myocarditis, and heart failure.
- **Myocardial Infarction (Type 1)**: Requires acute myocardial injury **plus** clinical evidence of acute myocardial ischemia, manifested by at least one of:
  1. Symptoms of acute myocardial ischemia (e.g., retrosternal chest pressure, radiation to left arm/jaw, diaphoresis).
  2. New ischemic ECG changes (e.g., ST-segment elevation, ST-segment depression, T-wave inversion, new pathological Q waves).
  3. Development of pathological imaging evidence of new loss of viable myocardium or new regional wall motion abnormality.
  4. Identification of an acute coronary thrombus by invasive coronary angiography or autopsy.

```text
┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                         FLAGSHIP CASE STUDY: ACUTE MYOCARDIAL INFARCTION (AMI)                         │
└───────────────────────────────────────────────────┬────────────────────────────────────────────────────┘
                                                    │
     ┌───────────────────────┬──────────────────────┼──────────────────────┬────────────────────────┐
     ▼                       ▼                      ▼                      ▼                        ▼
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

### 5.2 Bucket Concept Sets & Empirical TAXIS Associational Metrics

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
   - Rule: If a patient has single-day outpatient gastritis + esomeprazole with NO cardiology admission or interventions, censor as rule-out.

---

## 6. Objective Diagnostics for Phenotype Stability & Quality Assurance

A major breakthrough presented by Dr. Azza Shoaibi and Dr. Gowtham Rao in Topic 20940 is the formalization of **Objective Diagnostics for Phenotype Evaluation**:

### 6.1 Temporal Stability via 3-Knot Poisson Splines

Traditional phenotype evaluation relied heavily on visual inspection of incidence curves, which is subjective and unscalable. The Workgroup objective diagnostic standard models age- and sex-adjusted incidence rates over calendar time using a **Poisson regression model with a 3-knot natural cubic spline**:

$$\log(\lambda(t)) = \beta_0 + \beta_1 \cdot \text{Age} + \beta_2 \cdot \text{Sex} + \sum_{k=1}^3 \gamma_k B_k(t)$$

- **Likelihood Ratio Test for Stability**: The model compares the flexible spline fit against a null model of linear/stable incidence over time.
- **The $> 25\%$ Deviation Trigger**: If observed annual or quarterly incidence rates deviate by **$> 25\%$ (Incidence Rate Ratio $> 1.25$ or $< 0.80$)** relative to the expected spline baseline, the diagnostic flags the phenotype as **temporally unstable**.
- **Historical Case Exemplar (Pure Red Cell Aplasia)**: In the Workgroup presentation, this diagnostic captured the sudden epidemiological surge and collapse of Pure Red Cell Aplasia following formulation changes in recombinant erythropoietin, as well as artificial coding shifts associated with the US ICD-9 to ICD-10 transition in October 2015.

```text
┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                        OBJECTIVE DIAGNOSTICS: 3-KNOT POISSON SPLINE STABILITY TEST                     │
└───────────────────────────────────────────────────┬────────────────────────────────────────────────────┘
                                                    │
     Incidence Rate                                 │
           ▲                                        │
           │           Observed Incidence Spike     │
           │                 ╭──────╮  (>25% Deviation Flagged)
           │                 │  ▲   │               │
           │       ╭─────────╯  │   ╰──────────╮    ▼
           │  ─────┴────────────┼──────────────┴──────── 3-Knot Poisson Spline Baseline
           │                    │                   │
           │               IRR > 1.25               │
           │           (ICD-9/10 Shift)             │
           └────────────────────────────────────────┴──────────────────────► Calendar Year
```

### 6.2 International Meta-Analytic Smoothing & Consistency

To evaluate whether a phenotype is consistent across diverse healthcare systems, the objective diagnostic calculates meta-analytic smoothed incidence curves across federated network databases (e.g., claims vs. EHRs, US vs. European data). Divergences indicate whether variations represent genuine biological demographic differences or site-specific EHR data-capture artifacts.

### 6.3 CohortDiagnostics Lite Integration

To accelerate the *Iteration* phase of the 4-stage phenotyping loop, TAXIS integrates **CohortDiagnostics Lite**:
- Pre-computes high-density index event breakdowns, temporal characterization, and visit contexts on synthetic local test environments (such as Eunomia or the local Dockerized Synthea CDM on `localhost:5433`).
- Enables investigators to identify misclassified concept sets or first-event trap artifacts in minutes before launching heavy network-wide diagnostics.

---

## 7. Federated Interoperability: VA CIPHER & DARWIN EU Workflows

### 7.1 VA CIPHER - OHDSI Phenotype Library Cross-Walk (Jackie Honerlaw)

Presented in Topic 20940, the **Veterans Affairs Centralized Interactive Phenomics Resource (CIPHER)** collaboration established an official cross-walk between VA phenotyping standards and the OHDSI Phenotype Library:
- **25 Pilot Phenotypes**: Evaluated across VA VINCI OMOP CDM databases (encompassing over 9 million US veterans) and OHDSI network standards.
- **Metadata Harmonization**: Mapped CIPHER phenomics metadata into the OHDSI Phenotype Library schema, ensuring bidirectional interoperability between VA research and international observational studies.
- **Circe JSON Equivalency**: Validated that computable Circe JSON expressions generate consistent cohorts across claims-based and deeply rich VA EHR environments.

### 7.2 DARWIN EU Standardized Phenotyping Workflow (Albert Prats-Uribe)

The Data Analysis and Real World Interrogation Network (DARWIN EU®) established a formal, audited three-phase workflow for European regulatory studies:
1. **Clinical Description Phase**: Drafting structured clinical definitions with comprehensive disease background, diagnostic criteria, and clinical element mapping.
2. **Independent Review & Arbitration**: Dual independent clinical epidemiologists review candidate cohort logic; discrepancies are resolved through formal Principal Investigator arbitration.
3. **Phenotype Catalog Locking**: Locking version-controlled cohort definitions, Circe JSON strings, and baseline diagnostic profiles in the catalog prior to initiating multi-database protocol execution.

TAXIS adopts this exact three-phase lifecycle: clinical descriptions are parsed into 6-bucket slots, verified via empirical association mining, and permanently locked into the package repository with immutable commit hashes.

---

## 8. Interactive Adjudication Architecture: ATLAS v3.0 & Pythia Integration

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

### 8.1 Adjudication Heuristics Mapped to TAXIS Metrics

The TAXIS interactive adjudication engine systematically evaluates clinical presentations against the 6-bucket slot architecture:
1. **Acute Anchor & Diagnostic Confirmation (Buckets 1 & 3)**: Evaluates whether an acute inpatient or Emergency Department presentation is corroborated by confirmatory laboratory biomarkers or diagnostic procedures within $[-1, +2]$ days.
2. **Treatment-Enriched Specificity Gating (Bucket 4)**: Assesses whether forward-directed therapeutic interventions (such as PCI, CABG, or acute disease-specific pharmacotherapy within $[0, +2]$ days with $DR \ge 1.50$) are present to satisfy Tier 1 high-specificity criteria, distinguishing true clinical events from emergency rule-out evaluations.
3. **Diagnostic Work-Up Surveillance (Tier 2 Eligibility)**: Evaluates presentations lacking invasive interventions (such as medically managed infarction or non-revascularized diagnostic catheterization) for Tier 2 surveillance retention.
4. **Competing Mimic & Alternative Diagnosis Filtering (Bucket 6)**: Detects when primary competing diagnoses (e.g., acute gastritis, musculoskeletal chest wall pain) explain presenting symptoms in the absence of confirmatory cardiac intervention.
5. **Incident Baseline Wash-In**: Enforces $\ge 365$ days of continuous prior observation to separate new acute incidents from chronic carry-forward codes or problem-list administrative artifacts.
6. **Secondary Clinical Rescue Pathways**: Provides rule-based edge-case capture for catastrophic acute presentations (such as acute cardiac arrest and cardiogenic shock receiving emergency thrombolysis) that lack an explicit primary anchor diagnosis code.

*Provenance Notice (`DEC-GR-022`)*: Specific clinical presentation sequences, workgroup teaching vignettes, and case reviews are deferred from public-facing study documentation and maintained in private institutional review ledgers pending formal publication clearance.

---

## 9. The 10-Paper Collaborative Research Catalog

Formulated during the Workgroup sessions (Topic 25158), this catalog defines 10 potential peer-reviewed manuscripts establishing human-machine partnership in computable phenotyping:

```text
┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                              THE 10-PAPER COLLABORATIVE RESEARCH CATALOG                               │
└───────────────────────────────────────────────────┬────────────────────────────────────────────────────┘
                                                    │
     ┌───────────────────────┬──────────────────────┼──────────────────────┬────────────────────────┐
     ▼                       ▼                      ▼                      ▼                        ▼
┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐ ┌────────────────────┐
│ CATEGORY A:      │ │ CATEGORY B:      │ │ CATEGORY C:      │ │ CATEGORY D:      │ │ WORKGROUP FLAGSHIP │
│ SYSTEM &         │ │ QUALITATIVE      │ │ QUANTITATIVE     │ │ COMMUNITY &      │ │ "MINDS MEET        │
│ ARCHITECTURE     │ │ LOGIC & DESIGN   │ │ EVALUATION       │ │ OPEN SCIENCE     │ │ MACHINES"          │
│                  │ │                  │ │                  │ │                  │ │                    │
│ • Paper 1 (Arch) │ │ • Paper 3 (Logic)│ │ • Paper 5 (Eval) │ │ • Paper 8 (Gov)  │ │ • OKR KR 1.2       │
│ • Paper 2 (KG)   │ │ • Paper 4 (Mimic)│ │ • Paper 6 (Trial)│ │ • Paper 9 (VA)   │ │ • Core Workgroup   │
│                  │ │                  │ │ • Paper 7 (Diag) │ │ • Paper 10 (100) │ │   Consensus Pub    │
└──────────────────┘ └──────────────────┘ └──────────────────┘ └──────────────────┘ └────────────────────┘
```

### Category A: System & Architecture
1. **Paper 1: Neuro-Symbolic Phenotyping**: Architecture linking Large Language Model proposers with deterministic OHDSI OMOP CDM Circe validators.
2. **Paper 2: The Large-Scale Concept Association Graph**: Mining 1.88 billion clinical observations across 2.16M patients to extract multi-domain clinical relationships (Bandeian et al.).

### Category B: Qualitative Logic & Design
3. **Paper 3: Operationalizing the Fourth Universal Definition of MI in RWD**: Resolving myocardial injury vs. infarction through 6-bucket slot compilation.
4. **Paper 4: The Epidemiology of Diagnostic Mimics**: Quantifying rule-out contamination and differential exclusions in acute emergency admissions.

### Category C: Quantitative Performance & Evaluation
5. **Paper 5: Probabilistic vs. Rule-Based Phenotyping**: Replicating Joel Swerdel's trial concordance benchmark (77% vs 23%) across network CDMs.
6. **Paper 6: Objective Diagnostics for Phenotype Stability**: Validating the 3-knot Poisson spline model ($>25\%$ deviation threshold) across calendar transitions.
7. **Paper 7: Measurement Error in Causal Inference**: Quantifying the impact of phenotype choice on drug safety hazard ratios (extending James Weaver's 40-fold MDD findings).

### Category D: Community Open Science & Governance
8. **Paper 8: Federated Phenotyping Governance**: Data-use term sheets, aggregate-only results, and local firewall execution standards.
9. **Paper 9: Trans-Institutional Phenomic Interoperability**: Harmonizing VA CIPHER and the OHDSI Phenotype Library across 9M veterans.
10. **Paper 10: The 100-Phenotype Demonstration**: High-throughput automated creation and validation of 100 phenotypes for the OHDSI Phenotype Library (Demonstrated at the 2026 Global Symposium).

---

## 10. Compliance, Governance & Integrity Controls

1. **Zero-Mentions Compliance**: Prohibited individual names, institutional network labels, and award emojis are strictly excluded from all code, commits, and public documentation.
2. **Scientific Attribution (`DEC-GR-020`)**: Full recognition is prominently preserved for Dr. Stephen H. Bandeian as the original author of all SQL scripts, partitioning logic, and analytic algorithms.
3. **Privacy Floor & Local Firewall Execution (`DEC-GR-005`)**: All exported cell counts $< 5$ are masked to $-1$. No patient-level records, person IDs, or clinical event timestamps leave local database environments.
4. **KEEPER Adjudication Bridge Isolation**: The interactive adjudication bridge ("Phinding Phenotypes with Phriends") and clinical timeline visualizer operate strictly within the local institutional network boundary behind the hospital firewall; patient timelines are never exported or transmitted across institutions. Case vignettes in public documentation are strictly synthetic educational illustrations (`DEC-GR-022`).
