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

## 1. Theoretical Foundations from the OHDSI Phenotype Development & Evaluation Workgroup

In observational health research, computable phenotyping transforms raw electronic health records and administrative claims into scientifically valid, reproducible study cohorts. Through regular scientific discourse within the OHDSI Phenotype Development and Evaluation Workgroup ([Forum Topic 20940](https://forums.ohdsi.org/t/ohdsi-phenotype-workgroup-updates/20940)) and collaborative working sessions including *Phenotype Phebruary in Aphril 2026* ([Forum Topic 25158](https://forums.ohdsi.org/t/ohdsi-phenotype-phebruary-in-aphril-2026/25158)), the community has addressed a central methodological problem: the lack of standardized, empirically grounded phenotyping frameworks.

The *Book of OHDSI (2025 Edition)* formalizes phenotyping as a continuous, iterative 4-stage feedback loop (*Idea $\to$ Implementation $\to$ Iteration $\to$ Trust*):

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

1. **The Idea (Clinical Description)**: Establish a comprehensive clinical description specifying the pathophysiological mechanism, presenting clinical signs and symptoms, diagnostic criteria and confirmatory biomarkers, standard-of-care pharmacotherapies and procedural interventions, and differential diagnoses requiring explicit exclusion.
2. **Implementation (Circe Logic)**: Translate clinical specifications into executable OMOP CDM cohort criteria utilizing standardized concept set expressions and deterministic temporal logic.
3. **Iteration (Diagnostic Levers)**: Employ diagnostic packages (`CohortDiagnostics` and `CohortDiagnostics Lite`) concurrently during cohort specification. Evaluate patient accrual, temporal incidence stability, care setting distributions (inpatient vs. ambulatory), and orphan concept prevalence.
4. **Trust (Empirical Evaluation)**: Evaluate phenotype performance across federated health systems using objective Poisson spline stability diagnostics and probabilistic phenotyping (`PheValuator`) to estimate sensitivity, specificity, and positive predictive value prior to versioned publication in the OHDSI Phenotype Library.

TAXIS provides the foundational empirical data to support this 4-stage cycle. To be clear, we are not shipping a production cohort algorithm builder or a negative control selector in this repository. Our primary focus is building out, releasing, and maintaining TAXIS as an OHDSI network study. By running this study across diverse data partner sources, we compute comprehensive datasets of concept A–B pair summaries—capturing observed co-occurrences, temporal precedence, and utilization-stratified lift—and publish them as an open public resource. 

In this repository, we share a crude proof of concept illustrating how future applications can build on this foundation. Specifically, we demonstrate how TAXIS concept pair summaries can help researchers structure standard Circe cohort expressions that match OHDSI Clinical Descriptions.

---

## 2. Epidemiological Artefacts and Phenotypic Misclassification in Real-World Data

### 2.1 Neuro-Symbolic Synergy: Generative Clinical Proposers and Deterministic OMOP Validators

Workgroup deliberations established that neither heuristic generative models nor manual rule specification in isolation resolves the phenotype engineering bottleneck:
- **Generative Clinical Proposers**: Large language models excel at lexical synthesis, semantic expansion of clinical synonyms, and extracting guideline-recommended diagnostic modalities. However, ungrounded generative models lack calibration to real-world healthcare delivery and routinely hallucinate invalid vocabulary identifiers or propose clinical associations with negligible observational support.
- **Deterministic OMOP Validators**: The OMOP Common Data Model, Circe cohort compiler, and the TAXIS empirical association matrix provide deterministic grounding. They substantiate whether proposed concepts demonstrate adequate empirical prevalence and temporal precedence in longitudinal patient data, compiling reproducible, audit-compliant Circe cohort expressions.

```text
┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                              PROPOSER-VALIDATOR COLLABORATIVE ARCHITECTURE                             │
└───────────────────────────────────────────────────┬────────────────────────────────────────────────────┘
                                                    │
                 ┌──────────────────────────────────┴──────────────────────────────────┐
                 ▼                                                                     ▼
    ┌───────────────────────────────┐                                     ┌───────────────────────────────┐
    │ CLINICAL AI PROPOSER          │                                     │ OMOP / TAXIS VALIDATOR        │
    │ (LLM / Medical Informatician) │                                     │ (Empirical Engine & Circe)    │
    │                               │                                     │                               │
    │ • Parses Clinical Description │                                     │ • Concept AB Association Graph│
    │ • Brainstorms Synonyms & Labs │────────────────────────────────────►│ • Empirical Lift & Direction  │
    │ • Flags Mimics & Biomarkers   │      Candidate Concept Vectors      │ • OMOP CDM Vocabulary Anchor  │
    │ • Organizes into 6 Slots      │                                     │ • Circe JSON Compiler         │
    └───────────────────────────────┘                                     └───────────────┬───────────────┘
                 ▲                                                                        │
                 │                     Empirical Feedback & Diagnostics                   │
                 └────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Limitations of Unconstrained Diagnostic Codes in Observational Healthcare Data

Clinical chart review and validation studies establish that cohort definitions relying exclusively on unconstrained diagnostic billing codes incur substantial systematic error. In acute emergency settings, diagnostic evaluations frequently generate provisional rule-out diagnostic billing codes. For example, a patient presenting with acute chest pain may receive an acute myocardial infarction billing code solely because cardiac enzymes and electrocardiography were ordered; if serial biomarkers are normal and the patient is discharged with gastroesophageal reflux disease, the provisional diagnosis persists in administrative records as an unconfirmed false positive. Similarly, active problem lists in electronic health records frequently replicate historical diagnoses longitudinally across years due to documentation inertia and clinical note copy-forwarding, confounding incident event identification with historical prevalence.

Conversely, requiring highly specific diagnostic codes introduces profound false-negative misclassification. During critical care resuscitations, providers frequently enter non-specific symptom codes (e.g., chest pain) or general chronic condition codes (e.g., coronary atherosclerosis) rather than definitive acute infarction codes, with definitive clinical confirmation documented only in narrative clinical notes. Perioperative myocardial infarctions during coronary artery bypass graft surgery may be recorded exclusively as non-specific surgical complications, and catastrophic out-of-hospital events where patients expire prior to formal admission frequently lack diagnostic billing records entirely.

To demonstrate how empirical data can assist downstream tools in addressing both misclassification modes, our proof-of-concept pipeline organizes clinical logic into six functional element slots.

---

## 3. The 6-Bucket Clinical Element Slot Architecture

Rather than treating a phenotype as a single flat list of diagnosis codes, our proof-of-concept architecture organizes clinical concepts into six functional buckets based on how medical care is delivered. Each bucket maps directly to TAXIS empirical concept pairs, directional precedence ratios ($DR$), and standard Circe criteria blocks:

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
                    │ BUCKET 6:              │                │ PROOF-OF-CONCEPT:      │
                    │ ALTERNATIVE DIAGNOSES  │                │ MULTI-TIERED CIRCE     │
                    │ & EXCLUSIONARY MIMICS  │                │ DEMONSTRATIONS         │
                    │                        │                │                        │
                    │ • Competing causes     │                │ • Tier 1: Strict       │
                    │ • Rule-out diagnoses   │                │ • Tier 2: Surveillance │
                    │ • Censoring mimics     │                │ • xSpec / xSens Cohorts│
                    └────────────────────────┘                └────────────────────────┘
```

1. **Bucket 1 (Primary Anchor)**: The core condition of interest that defines index presentation, requiring at least 365 days of continuous prior observation to confirm incident onset.
2. **Bucket 2 (Symptoms and Presentation)**: Cardinal signs and presenting complaints that typically appear immediately antecedent to or on the index date ($[-7, +1]$ days).
3. **Bucket 3 (Diagnostic Labs and Procedures)**: Confirmatory biomarker measurements and diagnostic imaging ordered during clinical evaluation ($[-1, +3]$ days).
4. **Bucket 4 (Therapeutic Interventions)**: First-line pharmacotherapies and definitive procedural interventions administered once a clinical diagnosis is established ($[0, +2]$ days). Because clinicians infrequently administer invasive procedures or initiate acute disease-specific pharmacotherapies during provisional rule-out evaluations, this bucket provides the most robust empirical discrimination for true clinical cases.
5. **Bucket 5 (Complications and Progression)**: Downstream sequelae and acute organ failure developing in the weeks following the index event ($[+1, +30]$ days).
6. **Bucket 6 (Alternative Diagnoses and Look-Alikes)**: Competing conditions that present with overlapping symptomatology and must be evaluated as differential exclusions or censoring criteria ($[0, +7]$ days).

---

## 4. Demonstrating Multi-Tiered Cohort Strategies

### 4.1 Phenotypic Heterogeneity and Sensitivity in Observational Research

During workgroup presentations, James Weaver demonstrated that minor, unstandardized variations in cohort operational criteria induce substantial discrepancies across observational study findings. In an evaluation of Major Depressive Disorder (MDD) across multiple healthcare databases, altering phenotypic criteria—such as restricting to inpatient versus outpatient care settings, requiring single versus recurrent diagnostic code instances, or mandating concurrent antidepressant therapy—yielded a 40-fold variation in calculated incidence rates.

When observational researchers conduct comparative safety or causal inference studies without defining explicit target cohort specifications, observed associations frequently reflect phenotypic selection bias rather than genuine pharmacological effects. To illustrate how empirical association mining informs phenotype engineering, our proof-of-concept framework operationalizes three coordinated cohort tiers:

### 4.2 Tier 1: High-Specificity Cohorts for Comparative Safety and Causal Inference
In comparative safety investigations and active-comparator cohort designs, maximizing phenotypic specificity ($\ge 98\%$) and positive predictive value ($\ge 92\%$) by eliminating false-positive misclassification and transient rule-out diagnostic encounters constitutes a paramount methodological requirement. In our proof-of-concept pipeline, a Tier 1 cohort anchors on acute inpatient or emergency presentations, requires objective confirmatory diagnostic testing (Bucket 3), and mandates definitive therapeutic procedures or disease-specific pharmacotherapies (Bucket 4) within two days of index event presentation. Because clinicians restrict definitive interventions to patients with established diagnostic certainty, this treatment-enriched phenotype logic effectively purges single-day rule-out evaluations. When implementing post-index criteria in causal inference protocols, investigators must apply formal landmark or target trial emulation methods to avoid conditioning on post-baseline events and introducing immortal time bias.

### 4.3 Tier 2: High-Sensitivity Cohorts for Disease Surveillance and Natural History
When estimating disease incidence, prevalence, or natural history trajectories, mandating procedural or pharmacological interventions would systematically exclude frail, elderly, or conservatively managed patients. A Tier 2 surveillance cohort relaxes therapeutic requirements, capturing clinical presentations across all care settings corroborated by diagnostic testing (Bucket 3) within a fourteen-day window ($\pm 7$ days) to confirm diagnostic evaluation while maintaining high sensitivity ($\ge 95\%$).

### 4.4 Tier 3: Evaluator Sets for Diagnostic Modeling (`PheValuator`)
To evaluate phenotype performance across network databases without relying on expensive manual chart review, OHDSI developed `PheValuator`, which trains regularized predictive models using noisy training labels:
- **The Extremely Specific Set (`xSpec`)**: Built on Tier 1 criteria plus positive lab biomarkers and long-term secondary prevention persistence ($\ge 90$ days), providing a high-confidence noisy positive set.
- **The Sensitive Non-Case Boundary (`xSens`)**: Defines a broad exclusion zone encompassing any patient presenting with suggestive symptoms, related codes, or workup orders within $\pm 30$ days. Patients inside `xSens` who are not in `xSpec` are excluded from the negative training pool, preventing plausible, mild cases from contaminating the control group.

In empirical benchmarks presented in the workgroup, probabilistic models trained on these automated evaluator sets achieved 77% concordance with published clinical trial confidence intervals, compared to only 23% concordance for traditional rule-based algorithms. This demonstrates the potential value of using TAXIS concept pair summaries to inform diagnostic evaluator designs.

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
