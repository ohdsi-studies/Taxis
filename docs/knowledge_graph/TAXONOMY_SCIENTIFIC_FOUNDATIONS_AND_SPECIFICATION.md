# Scientific Foundations & Specification of the TAXIS Clinical Pair Taxonomy
## A 112-Code Ontology for Empirical Association Mining and Phenotype Engineering in the OMOP Common Data Model

> **Document Type**: Definitive Scientific Monograph & Formal Knowledge Representation Standard  
> **Target Release**: TAXIS v1.0.0 (Wave 6 Dissemination)  
> **Study Leadership & Provenance**:  
> • **Stephen H. Bandeian, MD, JD** – Principal Investigator (Original Clinical Concept-Pair Architecture, Episode-of-Care Lineage, and SQL Engine Author)  
> • **J. Marc Overhage, MD, PhD** – Co-Principal Investigator (Clinical Validation Architecture, ClinVec Benchmarks, and Blinded Clinician Review Adjudicator)  
> • **Gowtham Rao, MD, PhD** – Investigator, CoReason, Inc. USA; OHDSI Phenotype Development & Evaluation Workgroup (Neuro-Symbolic Proposer-Validator Integration & Governance)  
> • **Shaun Grannis, MD, MS** – Investigator, Regenstrief Institute / Indiana University School of Medicine (Dual-Internist Adjudication & INPC Production Grounding)  
> **Authoritative Decision Reference**: `DEC-GR-001`, `DEC-GR-005`, `DEC-GR-008`, `DEC-GR-010`, `DEC-GR-027`, `DEC-GR-028`, `DEC-GR-031`, `DEC-GR-032`  

---

## 1. Executive Summary & Epistemic Foundations

### 1.1. The Ontological Deficit in Observational Health Data Sciences
Standard biomedical terminologies integrated within the Observational Medical Outcomes Partnership (OMOP) Common Data Model (CDM)—principally SNOMED-CT, RxNorm, and LOINC—provide rigorous, normalized lexical controls and intra-domain subsumption hierarchies (*is-a* relationships). However, empirical vocabulary audits reveal that standard terminologies document **fewer than 0.5%** of the cross-domain operational relationships that dictate real-world medical care.

Standard ontologies excel at defining *what clinical entities are* in isolation:
- SNOMED-CT defines *Acute Myocardial Infarction* as an ischemic myocardial necrosis;
- RxNorm defines *Aspirin 81 MG Oral Tablet* as an acetylsalicylic acid dosage form;
- LOINC defines *Troponin I.cardiac [Mass/volume] in Serum or Plasma* as a quantitative clinical laboratory test.

Crucially, however, standard terminologies provide no computable, evidence-weighted links answering the central questions of longitudinal observational research:
1. *Which laboratory assay confirms the diagnosis versus serves as an uninformative routine metabolic panel?*
2. *Which pharmacological agent represents initial guideline-directed therapy versus salvage therapy for refractory disease?*
3. *Which diagnostic code represents an acute pathophysiology versus an administrative "rule-out" billing artifact?*
4. *In what empirical temporal sequence do clinical events manifest across patient trajectories?*

Historically, observational health researchers across the OHDSI collaborative have compensated for this ontological deficit by manually hand-crafting concept sets, inclusion criteria, and temporal observation windows for every individual cohort, phenotype, and comparative effectiveness study. This manual curation paradigm introduces severe intra-investigator variability, cognitive exhaustion, and uncalibrated selection bias.

The **TAXIS Clinical Pair Taxonomy (CPT-6)** bridges this fundamental divide. By coupling high-throughput longitudinal association mining across multi-million patient electronic health record (EHR) databases with a rigorous, 112-code clinical relationship ontology, TAXIS transforms raw empirical co-occurrence statistics into a computable, typed clinical knowledge graph.

---

## 2. Scientific Provenance and Authorship Lineage

The TAXIS Clinical Pair Taxonomy represents the convergence of two foundational informatics traditions led by Dr. Stephen H. Bandeian and Dr. J. Marc Overhage:

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                   TAXIS CLINICAL PAIR TAXONOMY PROVENANCE                                       │
├──────────────────────────────────────────────────────┬──────────────────────────────────────────────────────────┤
│             DR. STEPHEN H. BANDEIAN, MD, JD          │             DR. J. MARC OVERHAGE, MD, PHD                │
│             (Principal Investigator)                 │             (Co-Principal Investigator)                  │
├──────────────────────────────────────────────────────┼──────────────────────────────────────────────────────────┤
│  • CMS & AHRQ Episodes-of-Care Methodology:          │  • Clinical Validation Architecture:                     │
│    Developed episode grouping and clinical concept    │    Designed multi-tier validation protocols comparing    │
│    pair frameworks defining operational care units.  │    empirical mined edges to PheKB and ClinGraph.        │
│                                                      │                                                          │
│  • Clinical Pair Concept-Type Architecture:          │  • Empirical Benchmarks & Error Taxonomy:                │
│    Formulated 10 functional clinical concept types   │    Formulated the ClinVec benchmark and discordance      │
│    (Disorders, Findings, Diagnostic/Therapeutic       │    error matrix (evaluating coding artifacts vs. gaps).  │
│    Services, Devices, Drugs, Tests, Results).        │                                                          │
│                                                      │  • Blinded Dual-Internist Review (Overhage & Grannis):   │
│  • The Master Relationship Catalogs (M1–M9, 1111):   │    Conducted prospective blinded clinical adjudication   │
│    Authored the original comprehensive, mutually      │    on 291 sampled INPC pairs, establishing 88.3% broad   │
│    exclusive prompt catalogs (June 21, 2026).        │    agreement and calibrating directionality cutoffs.     │
└──────────────────────────────────────────▲───────────┴──────────────────────────▲───────────────────────────────┘
                                           │                                      │
                                           └──────────────────┬───────────────────┘
                                                              │
                                                              ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                               TAXIS CLINICAL PAIR TAXONOMY v6.0 (CPT-6)                                         │
│                                                                                                                 │
│   • 112 Standardized Relation Codes across 32 Clinical Families and 5 Core Functional Classes                   │
│   • Directionality Ratio (DR) Calibrated to Longitudinal Fact Ordering (Forward, Reverse, Symmetric)             │
│   • Neuro-Symbolic Integration with OHDSI Phenotype Working Group (Rao, Bandeian, Overhage, Grannis)             │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### 2.1. The Foundational Precursor: Automating the Expert-in-the-Loop for Case Adjudication (Rao, 2023)
The conceptual genesis of TAXIS traces directly to an influential debate initiated by **Dr. Gowtham Rao** on the OHDSI Forums in October 2023 (*"Case Adjudication with the help of LLM"*, referencing Martijn Schuemie's plenary address on KEEPER). 

At that time, LLM-based case adjudication required human clinical informaticians to manually author rule-based exclusion filters to eliminate irrelevant concept IDs from patient timelines (e.g., stripping out isolated encounters for "ear pain" or "sore throat" when evaluating suspected cases of Rheumatoid Arthritis). Without this labor-intensive curation, LLMs became overwhelmed by clinical noise, causing cognitive distraction, exponential branching, and clinical confabulation.

Dr. Rao proposed automating this "expert-in-the-loop" filtering by pairing empirical population-level characteristics from `CohortDiagnostics` (leveraging Azza Shoaibi's designated medical event characterizations) with structured LLM relevance judgments across five categorical tiers:
1. **Related** (High confidence the term reflects clinical aspects of the disease);
2. **Potentially Related** (Probable clinical association);
3. **Potentially Unrelated** (Lesser likelihood of clinical association);
4. **Unrelated** (No clinical correlation);
5. **Disqualifier** (Clinical criteria ruling out the condition).

In subsequent community analysis, **Hayden Spence** evaluated this pipeline against the exact sentinel list of **112 empirical clinical concepts** extracted from CohortDiagnostics (`112_result.xlsx`).

Crucially, an extensive dialogue between **Dr. Christian Reich** and **Dr. Gowtham Rao** surfaced the foundational challenge that prompt-only LLM methods could not overcome: **Semantic Ambiguity and Causal-Directional Confounding**. When evaluating candidate medications in Acute Liver Injury (ALI), the LLM classified *acetaminophen* as "Related." As Dr. Rao and Dr. Reich observed, acetaminophen exhibits an overwhelming statistical co-occurrence with liver injury, but it is an **antecedent etiologic cause**, not an **indicated therapeutic cure**. Asking an LLM whether a drug is "related" to a disease produces confounding unless the system explicitly distinguishes:
- What is the clinical role? (Etiology vs. Treatment vs. Diagnostic Marker vs. Rule-Out Disqualifier).
- What is the empirical temporal sequence? (Did the exposure precede the diagnosis, or did the diagnosis trigger the prescription?).
- Is the association driven by true pathophysiology or merely healthcare contact density?

This 2023 dialogue established the exact technical requirements that motivated TAXIS: observational health research needed high-throughput statistical association mining with **mathematical directionality** and **stratified lift**, coupled with an ontologically rigorous, typed clinical relationship taxonomy.

### 2.2. Dr. Stephen H. Bandeian: The Clinical Concept-Pair Architecture and Master Catalogs
The mathematical and architectural foundation of the clinical pair taxonomy was conceived and authored by **Dr. Stephen H. Bandeian, MD, JD** (Principal Investigator and author of the SQL mining engine). Dr. Bandeian drew upon methodologies he originally formulated during his tenure at the Agency for Healthcare Research and Quality (AHRQ) and his subsequent design of episode-of-care classification systems for the Centers for Medicare & Medicaid Services (CMS).

Dr. Bandeian established two decisive principles:
1. **Clinical Consideration over Database Schema**: Rather than categorizing concepts by raw OMOP CDM table names (which conflate findings, diagnoses, and billing codes across `condition_occurrence`, `observation`, and `procedure_occurrence`), pairs must be typed by their **clinical functional role** (Disorder `11`, Finding `12`, Diagnostic Service `21`, Therapeutic Service `22`, Device `30`, Drug Ingredient `40`, Observation `50/51`, Test `60/61`).
2. **The Master Relationship Catalogs (M1 through M9, 1111)**: On June 21, 2026, Dr. Bandeian transmitted the foundational taxonomy specification (`CLINICAL_PAIR_TAXONOMY_5.txt`) to Dr. Overhage and Dr. Gowtham Rao. Dr. Bandeian structured all possible cross-domain concept combinations into comprehensive, mutually exclusive relation matrices:
   - **`M1` (Test $\times$ Disorder)**: Confirming, excluding, assessing severity/stage, detecting complications, guiding treatment, or detecting adverse effects of treatment;
   - **`M2` (Test $\times$ Intervention)**: Indications for use, contraindications, effectiveness evaluation, complication monitoring, delivery/malfunction monitoring;
   - **`M3` (Intervention $\times$ Disorder)**: Prevention, resolution/disease control, symptom mitigation, complication prevention, adverse drug reactions, and absolute contraindications;
   - **`M4` & `M7` (Intervention $\times$ Finding / Result)**: Symptomatic palliation, abnormal finding normalization, biomarker response tracking;
   - **`1111` (Disorder $\times$ Disorder)**: Direct underlying etiology, secondary treatment-induced complications, differential diagnostic mimics, and granular disease subtyping.

### 2.3. Dr. J. Marc Overhage: Validation Architecture, Benchmarking & Blinded Adjudication
**Dr. J. Marc Overhage, MD, PhD** contributed the clinical validation framework, empirical benchmarking strategy, and discordance error taxonomy (formalized on April 27, 2026). Dr. Overhage recognized that while large language models and clinician prompts can assign semantic labels, those labels must be strictly validated against real-world clinical practice and gold-standard informatics corpora.

Dr. Overhage's core contributions encompass:
1. **The Six-Part Validation Protocol**: Established prospective evaluation of candidate set reduction efficiency, recovery of curated computable knowledge (ClinGraph, ClinVec, PheKB), LLM validity yields by domain, and empirical statistical concordance.
2. **The Discordance Error Taxonomy**: Systematically separated true pathophysiological relationships from observational artifacts: mapping issues, threshold censoring, administrative billing noise, and source documentation gaps.
3. **The Blinded Dual-Internist Adjudication Study**: In August 2026, Dr. Overhage and **Dr. Shaun Grannis, MD, MS** conducted blinded clinical review of 291 randomly sampled concept pairs mined from the Indiana Network for Patient Care (INPC) 2.16M patient production run. Their adjudication established **88.3% agreement** on broad clinical relationship families ($\kappa = 0.84$) and **58.1% exact agreement** on granular 112-code taxonomy codes ($\kappa = 0.54$), establishing the real-world validity of the taxonomy.

### 2.4. Synthesis into Clinical Pair Taxonomy v6.0 (CPT-6)
Working with **Dr. Gowtham Rao, MD, PhD**, the study team synthesized Dr. Rao's early automated case adjudication vision, Dr. Bandeian's Master catalogs, and Dr. Overhage's validation findings into the standardized **112-code Clinical Pair Taxonomy v6.0**. This definitive specification coordinates exact semantic definitions, inverse relation symmetries, OMOP domain constraints, and mathematical thresholds for the Directionality Ratio ($DR$) and Mantel-Haenszel Stratified Lift ($\text{Lift}_{\text{strat}}$).

---

## 3. The Five Core Clinical Relationship Families

Taxonomy v6.0 organizes its 112 standardized relation codes into **32 semantic families** distributed across **five core functional classes**. Each class reflects a fundamental physiological, pharmacological, or healthcare operational mechanism:

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                           THE FIVE CORE CLINICAL RELATIONSHIP FAMILIES OF TAXIS                                 │
├─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                                 │
│   [ CLASS I: CAUSAL & PATHOPHYSIOLOGICAL MECHANISMS ] (24 Codes / 7 Families)                                   │
│   Antecedent infectious pathogens, environmental insults, pharmacologic toxicities, monogenic defects,          │
│   and acute or chronic multi-organ decompensation cascades precipitating downstream disease.                   │
│                                                                                                                 │
│   [ CLASS II: DIAGNOSTIC LABORATORY & PROCEDURAL EVALUATIONS ] (22 Codes / 6 Families)                          │
│   Pathognomonic confirmatory assays, molecular genetic sequencing, histopathologic tissue biopsies,             │
│   cardinal physical signs, cross-sectional imaging, therapeutic drug monitoring, and surveillance intervals.    │
│                                                                                                                 │
│   [ CLASS III: THERAPEUTIC & INTERVENTIONAL STRATEGIES ] (26 Codes / 8 Families)                                │
│   Guideline-directed first-line pharmacotherapies, additive combination agents, acute rescue interventions,    │
│   chronic disease-modifying therapies, curative surgical resections, mechanical devices, and contraindications. │
│                                                                                                                 │
│   [ CLASS IV: PROGNOSTIC & DISEASE EVOLUTION SEQUENCES ] (20 Codes / 6 Families)                                │
│   Chronic stage-wise disease progression, acute organ flares, late micro/macrovascular complications,           │
│   distant metastatic dissemination, post-infectious inflammatory sequelae, remission, and terminal agonal events│
│                                                                                                                 │
│   [ CLASS V: DIFFERENTIAL DIAGNOSTIC MIMICS & ASSOCIATIONAL CLUSTERING ] (20 Codes / 5 Families)                │
│   Symptom-sharing differential mimics, high-negative-predictive-value rule-outs, metabolic syndrome triads,     │
│   shared toxic habits, continuous anatomical spread, and healthcare utilization density artifacts.              │
│                                                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

### 3.1. Class I: Causal & Pathophysiological Mechanisms
*Scope: Relationships in which Concept A acts as an antecedent biological pathogen, mechanical trigger, chemical insult, genetic driver, or primary organ failure precipitating Concept B.*

#### Clinical & Epidemiological Foundations
In observational data, causal relationships manifest as forward-predominant longitudinal sequences ($N_{A \to B} \gg N_{B \to A}$, yielding Directionality Ratios $DR \ge 1.50$) with high stratified lift over long-term observation windows. Class I captures the biological and environmental etiology of human illness:
- **Primary Infectious Etiologies (`ETIOL_CAUS_01`–`03`)**: Pathogens invading host tissues resulting in acute or subacute disease (e.g., *Streptococcus pyogenes* $\to$ *Post-streptococcal glomerulonephritis*; *Influenza A virus* $\to$ *Secondary Staphylococcus aureus pneumonia*; *Human immunodeficiency virus* $\to$ *Pneumocystis jirovecii pneumonia*).
- **Toxic & Iatrogenic Pathologies (`ETIOL_TOX_01`–`04`)**: Unintended drug-induced organ toxicities where pharmacotherapy causes cellular necrosis, apoptosis, or physiological dysfunction (e.g., *Paclitaxel* $\to$ *Peripheral sensory neuropathy*; *Acetaminophen supratherapeutic ingestion* $\to$ *Acute hepatic failure*; *Gentamicin* $\to$ *Acute tubular necrosis*; *Doxorubicin* $\to$ *Dilated cardiomyopathy*).
- **Acute Organ Failure Cascades (`ETIOL_COMP_01`–`04`)**: Decompensation in one physiological system triggering rapid failure in another (e.g., *Severe sepsis* $\to$ *Acute respiratory distress syndrome*; *Atrial fibrillation* $\to$ *Cardioembolic ischemic stroke*; *Type 1 diabetes* $\to$ *Diabetic ketoacidosis*).
- **Traumatic & Environmental Triggers (`ETIOL_TRAUM_01`–`02`, `ETIOL_ENV_01`–`02`)**: External mechanical forces or particulate/radiation exposures causing tissue disruption (e.g., *Motor vehicle crash* $\to$ *Traumatic splenic laceration*; *Inhaled crystalline silica* $\to$ *Silicosis*).
- **Genetic & Immunological Etiologies (`ETIOL_GEN_01`–`02`, `ETIOL_IMM_01`–`03`)**: Inborn monogenic errors or immune complex deposition driving chronic organ pathology (e.g., *CFTR mutation* $\to$ *Bronchiectasis*; *Systemic lupus erythematosus* $\to$ *Lupus nephritis Class IV*).
- **Secondary Endocrine & Hematologic Derangements (`ETIOL_SECO_01`–`02`)**: Systemic diseases disrupting distant endocrine axes or marrow hematopoiesis (e.g., *Stage 5 chronic kidney disease* $\to$ *Secondary hyperparathyroidism*; *Rheumatoid arthritis* $\to$ *Anemia of chronic disease*).

---

### 3.2. Class II: Diagnostic Laboratory & Procedural Evaluations
*Scope: Relationships in which Concept A serves as an objective clinical measurement, diagnostic procedure, physical examination sign, or surveillance assessment that establishes, stages, monitors, or rules out Concept B.*

#### Clinical & Epidemiological Foundations
Diagnostic evaluations are characterized by close temporal proximity to the index diagnosis, manifesting primarily as same-day recordings ($N_{A=B}$) or contemporaneous recordings within narrow observation intervals (e.g., $[-7, +7]$ days, yielding balanced directionality $0.67 < DR < 1.50$):
- **Gold-Standard Confirmatory Diagnostics (`DIAG_CONF_01`–`03`)**: Definitive objective findings that establish conclusive diagnostic presence (e.g., *Serum cardiac Troponin I $> 99\text{th}$ percentile* $\leftrightarrow$ *Acute myocardial infarction*; *BCR-ABL1 translocation by RT-PCR* $\leftrightarrow$ *Chronic myeloid leukemia*; *Renal core needle biopsy* $\leftrightarrow$ *Membranous nephropathy*).
- **Population Screening Tests (`DIAG_SCRN_01`–`02`)**: Routine evaluations performed on asymptomatic populations where the procedure precedes the diagnosis ($DR \ge 1.50$) (e.g., *Screening colonoscopy* $\to$ *Colonic tubular adenoma*; *Serum prostate-specific antigen elevation* $\to$ *Prostatic adenocarcinoma*).
- **Quantitative Strain & Inflammatory Biomarkers (`DIAG_MARK_01`–`04`)**: Laboratory measurements that gauge inflammatory activity, neurohormonal ventricular strain, or metabolic control (e.g., *Serum C-reactive protein* $\leftrightarrow$ *Giant cell arteritis*; *Serum NT-proBNP* $\leftrightarrow$ *Congestive heart failure decompensation*; *Hemoglobin A1c* $\leftrightarrow$ *Type 2 diabetes mellitus*).
- **Anatomical Imaging & Functional Studies (`DIAG_IMAG_01`–`03`)**: Cross-sectional tomography, sonography, or scintigraphy visualizing organ morphology (e.g., *Contrast-enhanced CT of abdomen and pelvis* $\leftrightarrow$ *Acute appendicitis*; *Transthoracic echocardiogram* $\leftrightarrow$ *Severe aortic valve stenosis*).
- **Cardinal Physical Examination Signs (`DIAG_SIGN_01`–`02`)**: Physical signs or electrophysiological waveforms pathognomonic of an underlying disorder (e.g., *Ascites with shifting dullness* $\leftrightarrow$ *Decompensated hepatic cirrhosis*; *ST-segment elevation on 12-lead ECG* $\leftrightarrow$ *ST-elevation myocardial infarction*).
- **Therapeutic Drug Level & Coagulation Monitoring (`DIAG_MONI_01`–`02`)**: Laboratory assays required to maintain narrow therapeutic windows (e.g., *Serum trough vancomycin concentration* $\leftrightarrow$ *Intravenous vancomycin infusion*; *Prothrombin time / International Normalized Ratio* $\leftrightarrow$ *Warfarin oral anticoagulation*).

---

### 3.3. Class III: Therapeutic & Interventional Strategies
*Scope: Relationships in which Concept A represents an evidence-based pharmacologic agent, surgical procedure, medical device, or rehabilitation protocol indicated, contraindicated, or tailored for Concept B.*

#### Clinical & Epidemiological Foundations
In canonical orientation where Concept A represents the intervention (Drug or Procedure) and Concept B represents the indication (Disorder), clinical diagnosis typically precedes the prescription or intervention, yielding reverse directionality ($DR \le 0.67$). When evaluated in reverse orientation (Concept A = Disorder, Concept B = Treatment), the active code is the inverse relation (e.g., `THER_FIRST_01_INV`) and the ratio reciprocates to $DR' \ge 1.50$:
- **First-Line Guideline Pharmacotherapies (`THER_FIRST_01`–`02`)**: Initial standard-of-care pharmacotherapy recommended by clinical consensus guidelines (e.g., *Metformin oral tablet* for *Type 2 diabetes mellitus*; *Ceftriaxone + Azithromycin* for *Inpatient community-acquired pneumonia*).
- **Combination & Adjuvant Therapies (`THER_ADJ_01`–`02`)**: Second-line add-on agents or post-surgical chemotherapy regimens (e.g., *Amlodipine added to Lisinopril* for *Stage 2 essential hypertension*; *Adjuvant Paclitaxel + Carboplatin* for *Resected triple-negative breast cancer*).
- **Acute Symptomatic Rescue Agents (`THER_RESC_01`–`03`)**: Rapid-acting agents administered during acute physiological crises, exhibiting high contemporaneous co-occurrence ($0.67 < DR < 1.50$) (e.g., *Inhaled albuterol sulfate* for *Acute asthma bronchospasm*; *Intravenous norepinephrine infusion* for *Distributive septic shock*; *Intravenous 50% dextrose* for *Severe symptomatic hypoglycemia*).
- **Long-Term Maintenance & Plaque Stabilization (`THER_MAINT_01`–`03`)**: Chronic therapies intended to alter long-term disease trajectories (e.g., *Methotrexate* for *Rheumatoid arthritis*; *High-intensity Atorvastatin 80 mg* for *Coronary atherosclerosis*; *Apixaban* for *Non-valvular atrial fibrillation stroke prophylaxis*).
- **Curative Surgical Resections & Bypass Grafting (`THER_SURG_01`–`03`)**: Mechanical tissue removal or vascular reconstruction (e.g., *Laparoscopic appendectomy* for *Acute suppurative appendicitis*; *Coronary artery bypass grafting* for *Triple-vessel ischemic heart disease*).
- **Catheter Interventions & Dialytic Support (`THER_PROC_01`–`03`)**: Percutaneous endovascular or extracorporeal life-support procedures (e.g., *Percutaneous coronary intervention with drug-eluting stent* for *Acute ST-elevation myocardial infarction*; *Intermittent hemodialysis* for *End-stage renal disease*).
- **Implantable Electronic Devices & Prostheses (`THER_DEV_01`–`03`)**: Permanent mechanical or electrical hardware (e.g., *Implantable cardioverter-defibrillator* for *Severe ischemic cardiomyopathy with LVEF $\le 35\%$*; *Total hip arthroplasty* for *End-stage coxarthrosis*).
- **Absolute Clinical Contraindications (`THER_CONTRA_01`–`02`)**: Interventions known to produce catastrophic toxicity in specific underlying states (e.g., *Pioglitazone* contraindicated in *NYHA Class III/IV congestive heart failure*; *Metformin* contraindicated in *Severe renal impairment with eGFR $< 30\text{ mL/min}/1.73\text{m}^2$*).

---

### 3.4. Class IV: Prognostic & Disease Evolution Sequences
*Scope: Relationships in which Concept A represents an early baseline condition, intermediate pathological stage, or acute exacerbation evolving chronologically into downstream complications, remissions, or terminal events (Concept B).*

#### Clinical & Epidemiological Foundations
Disease evolution relationships are characterized by substantial longitudinal latency ($N_{A \to B} \gg N_{B \to A}$, $DR \ge 1.50$), with lag decay distributions spanning months to decades:
- **Stage-Wise Disease Progression (`PROG_PROG_01`–`03`)**: Continuous organ functional decline across clinically defined stages (e.g., *Chronic kidney disease Stage 3* $\to$ *End-stage renal disease requiring replacement therapy*; *Colonic tubular adenoma with high-grade dysplasia* $\to$ *Invasive colonic adenocarcinoma*; *Metabolic dysfunction-associated steatohepatitis (MASH)* $\to$ *Micronodular cirrhosis with portal hypertension*).
- **Acute Clinical Flares of Chronic Inflammatory Disease (`PROG_FLARE_01`–`03`)**: Rapid, recurrent surges of disease activity punctuating an otherwise indolent course (e.g., *Chronic obstructive pulmonary disease* $\leftrightarrow$ *Acute exacerbation of COPD*; *Systemic lupus erythematosus* $\leftrightarrow$ *Acute severe lupus nephritis flare*).
- **Late Microvascular & Structural Sequelae (`PROG_LATE_01`–`03`)**: Pathologies arising from cumulative vascular or cellular stress (e.g., *Type 2 diabetes mellitus* $\to$ *Proliferative diabetic retinopathy*; *Transmural anterior myocardial infarction* $\to$ *Left ventricular aneurysm with ischemic cardiomyopathy*).
- **Malignant Metastatic Dissemination (`PROG_META_01`–`03`)**: Secondary tumor seeding into distant parenchyma (e.g., *Invasive ductal carcinoma of breast* $\to$ *Osteolytic bone metastases*; *Non-small cell lung carcinoma* $\to$ *Leptomeningeal carcinomatosis*).
- **Post-Infectious Inflammatory Sequelae (`PROG_SEQL_01`–`04`)**: Autoimmune or immune-mediated syndromes triggered by cleared microbiological infections (e.g., *Campylobacter jejuni gastroenteritis* $\to$ *Acute inflammatory demyelinating polyneuropathy (Guillain-Barré)*; *Acute SARS-CoV-2 infection* $\to$ *Post-acute sequelae of COVID-19 (PASC)*).
- **Remission & Survivorship Milestones (`PROG_REMIS_01`–`02`, `PROG_SURV_01`, `PROG_DEATH_01`)**: Resolution of active pathology, sustained cancer-free intervals, or terminal agonal events (e.g., *Severe idiopathic nephrotic syndrome* $\to$ *Complete remission of proteinuria*; *Multi-organ failure refractory to vasopressors* $\to$ *In-hospital cardiopulmonary arrest*).

---

### 3.5. Class V: Differential Diagnostic Mimics & Associational Clustering
*Scope: Relationships in which Concept A and Concept B frequently co-occur due to shared phenotypic presentation, overlapping symptomatology, shared etiological exposures, contiguous anatomy, or high healthcare utilization density, without direct linear causality.*

#### Clinical & Epidemiological Foundations
Class V relationships represent the most critical source of confounding in observational health data. Without structured semantic typing, crude association algorithms mistake these pairs for direct etiologies or indications:
- **Phenotypic Mimics & Competing Differential Diagnoses (`DIAG_DIFF_01`, `ASSOC_PHENO_01`)**: Distinct pathological entities sharing clinical presentation that clinicians must actively differentiate (e.g., *Acute viral gastroenteritis* sharing symptoms with *New-onset ileal Crohn's disease*; *Fibromyalgia* co-occurring with *Irritable bowel syndrome* due to central pain sensitization).
- **Biomarker Rule-Out Assays (`DIAG_DIFF_02`)**: High-sensitivity, high-negative-predictive-value tests performed to exclude a catastrophic diagnosis (e.g., *Negative quantitative D-dimer assay* ordered to rule out *Acute pulmonary embolism*).
- **Syndromic & Polyendocrine Clustering (`ASSOC_SYND_01`–`04`)**: Genetic or pathophysiological traits that cluster within individuals without direct linear causality (e.g., *Essential hypertension* co-occurring with *Hypertriglyceridemia and central adiposity* in Metabolic Syndrome; *Hashimoto thyroiditis* co-occurring with *Type 1 diabetes* in Autoimmune Polyendocrine Syndrome Type II).
- **Shared Toxic & Environmental Habitus (`ASSOC_RISK_01`–`04`)**: Distinct end-organ damage caused by a single shared external insult (e.g., *Chronic obstructive pulmonary disease* co-occurring with *Coronary artery disease* due to heavy cigarette smoking; *Chronic calcific pancreatitis* co-occurring with *Alcoholic liver cirrhosis* due to heavy ethanol consumption).
- **Contiguous Anatomical Spread (`ASSOC_ANAT_01`–`03`)**: Direct local extension of pathology across contiguous tissue planes (e.g., *Acute maxillary sinusitis* developing from an adjacent *Maxillary molar periapical abscess*).
- **Healthcare Contact Density Artifacts (`ASSOC_UTIL_01`–`03`)**: Concepts that co-occur with high statistical association strictly because a patient is hospitalized, hyper-monitored, or undergoing bundled procedural evaluations (e.g., *Indwelling radial arterial line placement* co-occurring with *Continuous venovenous hemofiltration* during septic shock care; *Routine annual wellness examination* co-occurring with *Screening lipid profile*).

---

## 4. The Complete Catalog of 112 Standardized Relation Codes

The following table documents the complete, formal catalog of 112 relation codes across all 32 semantic families. Every relation enforces bidirectional consistency through a designated inverse code ($A \xrightarrow{R} B \iff B \xrightarrow{R^{-1}} A$):

| Code ID | Inverse Code ID | Family | Canonical Label | Domain Constraint | Expected DR | Real-World Clinical Exemplar |
|---|---|---|---|---|:---:|---|
| **`ETIOL_CAUS_01`** | `ETIOL_CAUS_01_INV` | Primary Etiology | Primary Infectious Etiology | `Condition -> Condition` | $\ge 1.50$ | *Streptococcal pharyngitis* $\to$ *Post-streptococcal glomerulonephritis* |
| **`ETIOL_CAUS_02`** | `ETIOL_CAUS_02_INV` | Primary Etiology | Bacterial Superinfection | `Condition -> Condition` | $\ge 1.50$ | *Influenza A infection* $\to$ *Staphylococcal pneumonia* |
| **`ETIOL_CAUS_03`** | `ETIOL_CAUS_03_INV` | Primary Etiology | Opportunistic Infection | `Condition -> Condition` | $\ge 1.50$ | *HIV disease* $\to$ *Pneumocystis jirovecii pneumonia* |
| **`ETIOL_TOX_01`** | `ETIOL_TOX_01_INV` | Toxicity | Drug-Induced Toxic Neuropathy | `Drug -> Condition` | $\ge 1.50$ | *Paclitaxel* $\to$ *Peripheral sensory neuropathy* |
| **`ETIOL_TOX_02`** | `ETIOL_TOX_02_INV` | Toxicity | Drug-Induced Hepatotoxicity | `Drug -> Condition` | $\ge 1.50$ | *Acetaminophen supratherapeutic dose* $\to$ *Acute liver injury* |
| **`ETIOL_TOX_03`** | `ETIOL_TOX_03_INV` | Toxicity | Drug-Induced Nephrotoxicity | `Drug -> Condition` | $\ge 1.50$ | *Gentamicin sulfate* $\to$ *Acute tubular necrosis* |
| **`ETIOL_TOX_04`** | `ETIOL_TOX_04_INV` | Toxicity | Drug-Induced Cardiotoxicity | `Drug -> Condition` | $\ge 1.50$ | *Doxorubicin hydrochloride* $\to$ *Dilated cardiomyopathy* |
| **`ETIOL_COMP_01`** | `ETIOL_COMP_01_INV` | Complication | Acute Organ Failure Cascade | `Condition -> Condition` | $\ge 1.50$ | *Severe sepsis* $\to$ *Acute respiratory distress syndrome* |
| **`ETIOL_COMP_02`** | `ETIOL_COMP_02_INV` | Complication | Vascular Ischemic Embolism | `Condition -> Condition` | $\ge 1.50$ | *Atrial fibrillation* $\to$ *Cardioembolic ischemic stroke* |
| **`ETIOL_COMP_03`** | `ETIOL_COMP_03_INV` | Complication | Metabolic Decompensation | `Condition -> Condition` | $\ge 1.50$ | *Type 1 diabetes mellitus* $\to$ *Diabetic ketoacidosis* |
| **`ETIOL_COMP_04`** | `ETIOL_COMP_04_INV` | Complication | Secondary Hemorrhagic Event | `Condition -> Condition` | $\ge 1.50$ | *Peptic ulcer disease* $\to$ *Upper gastrointestinal bleeding* |
| **`ETIOL_TRAUM_01`**| `ETIOL_TRAUM_01_INV`| Trauma | Mechanical Trauma Injury | `Condition -> Condition` | $\ge 1.50$ | *Blunt abdominal trauma* $\to$ *Splenic parenchymal laceration* |
| **`ETIOL_TRAUM_02`**| `ETIOL_TRAUM_02_INV`| Trauma | Chronic Post-Traumatic Syndrome | `Condition -> Condition` | $\ge 1.50$ | *Traumatic brain injury* $\to$ *Post-concussive syndrome* |
| **`ETIOL_GEN_01`** | `ETIOL_GEN_01_INV` | Genetics | Monogenic Phenotypic Defect | `Condition -> Condition` | $\ge 1.50$ | *Cystic fibrosis mutation* $\to$ *Bilateral bronchiectasis* |
| **`ETIOL_GEN_02`** | `ETIOL_GEN_02_INV` | Genetics | Familial Cancer Predisposition | `Condition -> Condition` | $\ge 1.50$ | *Lynch syndrome (MLH1 mutation)* $\to$ *Colorectal carcinoma* |
| **`ETIOL_IMM_01`** | `ETIOL_IMM_01_INV` | Immunology | Autoimmune End-Organ Attack | `Condition -> Condition` | $\ge 1.50$ | *Systemic lupus erythematosus* $\to$ *Lupus nephritis* |
| **`ETIOL_IMM_02`** | `ETIOL_IMM_02_INV` | Immunology | Immediate Hypersensitivity Anaphylaxis | `Drug -> Condition` | $\ge 1.50$ | *Intravenous Penicillin G* $\to$ *Anaphylactic shock* |
| **`ETIOL_IMM_03`** | `ETIOL_IMM_03_INV` | Immunology | Immune Complex Vasculitis | `Condition -> Condition` | $\ge 1.50$ | *Chronic Hepatitis B infection* $\to$ *Polyarteritis nodosa* |
| **`ETIOL_ENV_01`** | `ETIOL_ENV_01_INV` | Environment | Inhaled Mineral Dust Exposure | `Condition -> Condition` | $\ge 1.50$ | *Occupational silica dust exposure* $\to$ *Pulmonary silicosis* |
| **`ETIOL_ENV_02`** | `ETIOL_ENV_02_INV` | Environment | Physical Radiation Damage | `Condition -> Condition` | $\ge 1.50$ | *Pelvic external beam radiation* $\to$ *Radiation proctitis* |
| **`ETIOL_MET_01`** | `ETIOL_MET_01_INV` | Metabolism | Micronutrient Deficiency | `Condition -> Condition` | $\ge 1.50$ | *Vitamin B12 deficiency* $\to$ *Subacute combined degeneration* |
| **`ETIOL_MET_02`** | `ETIOL_MET_02_INV` | Metabolism | Insoluble Crystal Deposition | `Condition -> Condition` | $\ge 1.50$ | *Chronic hyperuricemia* $\to$ *Monosodium urate gouty arthropathy* |
| **`ETIOL_SECO_01`** | `ETIOL_SECO_01_INV` | Secondary | Secondary Endocrine Axis Failure | `Condition -> Condition` | $\ge 1.50$ | *Chronic kidney disease Stage 5* $\to$ *Secondary hyperparathyroidism* |
| **`ETIOL_SECO_02`** | `ETIOL_SECO_02_INV` | Secondary | Secondary Inflammatory Anemia | `Condition -> Condition` | $\ge 1.50$ | *Active rheumatoid arthritis* $\to$ *Anemia of chronic inflammation* |
| **`DIAG_CONF_01`** | `DIAG_CONF_01_INV` | Confirmation | Pathognomonic Confirmatory Biomarker | `Measurement -> Condition` | $[0.67, 1.50]$ | *Cardiac Troponin I $> 99\text{th}$ percentile* $\leftrightarrow$ *Acute MI* |
| **`DIAG_CONF_02`** | `DIAG_CONF_02_INV` | Confirmation | Molecular Genetic Confirmation | `Measurement -> Condition` | $[0.67, 1.50]$ | *BCR-ABL1 transcript detection* $\leftrightarrow$ *Chronic myeloid leukemia* |
| **`DIAG_CONF_03`** | `DIAG_CONF_03_INV` | Confirmation | Histopathologic Biopsy Confirmation | `Procedure -> Condition` | $[0.67, 1.50]$ | *Core needle renal biopsy* $\leftrightarrow$ *IgA nephropathy* |
| **`DIAG_SCRN_01`** | `DIAG_SCRN_01_INV` | Screening | Routine Endoscopic Screening | `Procedure -> Condition` | $\ge 1.50$ | *Asymptomatic screening colonoscopy* $\to$ *Colonic adenomatous polyp* |
| **`DIAG_SCRN_02`** | `DIAG_SCRN_02_INV` | Screening | Routine Serologic Screen Titer | `Measurement -> Condition` | $\ge 1.50$ | *Elevated serum PSA titer* $\to$ *Prostatic adenocarcinoma* |
| **`DIAG_MARK_01`** | `DIAG_MARK_01_INV` | Biomarkers | Inflammatory Acute Phase Reactant | `Measurement -> Condition` | $[0.67, 1.50]$ | *High-sensitivity C-reactive protein* $\leftrightarrow$ *Giant cell arteritis* |
| **`DIAG_MARK_02`** | `DIAG_MARK_02_INV` | Biomarkers | Ventricular Neurohormonal Strain | `Measurement -> Condition` | $[0.67, 1.50]$ | *Serum NT-proBNP elevation* $\leftrightarrow$ *Heart failure decompensation* |
| **`DIAG_MARK_03`** | `DIAG_MARK_03_INV` | Biomarkers | Chronic Glycemic Biomarker | `Measurement -> Condition` | $[0.67, 1.50]$ | *Hemoglobin A1c $\ge 6.5\%$* $\leftrightarrow$ *Type 2 diabetes mellitus* |
| **`DIAG_MARK_04`** | `DIAG_MARK_04_INV` | Biomarkers | Quantitative Cytopenia Index | `Measurement -> Condition` | $[0.67, 1.50]$ | *Absolute neutrophil count $< 500/\mu\text{L}$* $\leftrightarrow$ *Neutropenic fever* |
| **`DIAG_IMAG_01`** | `DIAG_IMAG_01_INV` | Imaging | Cross-Sectional Diagnostic Imaging | `Procedure -> Condition` | $[0.67, 1.50]$ | *Contrast CT abdomen/pelvis* $\leftrightarrow$ *Acute appendicitis* |
| **`DIAG_IMAG_02`** | `DIAG_IMAG_02_INV` | Imaging | Echocardiographic Doppler Flow | `Procedure -> Condition` | $[0.67, 1.50]$ | *Transthoracic echocardiography* $\leftrightarrow$ *Severe aortic valve stenosis* |
| **`DIAG_IMAG_03`** | `DIAG_IMAG_03_INV` | Imaging | Myocardial Perfusion Scintigraphy | `Procedure -> Condition` | $[0.67, 1.50]$ | *SPECT nuclear perfusion scan* $\leftrightarrow$ *Coronary artery disease* |
| **`DIAG_SIGN_01`** | `DIAG_SIGN_01_INV` | Physical Sign | Cardinal Examination Sign | `Condition -> Condition` | $[0.67, 1.50]$ | *Ascites with fluid wave* $\leftrightarrow$ *Decompensated hepatic cirrhosis* |
| **`DIAG_SIGN_02`** | `DIAG_SIGN_02_INV` | Physical Sign | Diagnostic Electrocardiographic Wave | `Procedure -> Condition` | $[0.67, 1.50]$ | *Convex ST-segment elevation* $\leftrightarrow$ *ST-elevation myocardial infarction* |
| **`DIAG_STAG_01`** | `DIAG_STAG_01_INV` | Staging | Whole-Body Staging Tomography | `Procedure -> Condition` | $\le 0.67$ | *Primary non-small cell lung cancer* $\to$ *FDG PET-CT staging* |
| **`DIAG_STAG_02`** | `DIAG_STAG_02_INV` | Staging | Invasive Hemodynamic Catheterization | `Procedure -> Condition` | $\le 0.67$ | *Severe pulmonary hypertension* $\to$ *Right heart catheterization* |
| **`DIAG_MONI_01`** | `DIAG_MONI_01_INV` | Monitoring | Therapeutic Drug Level Assay | `Measurement -> Drug` | $[0.67, 1.50]$ | *Serum vancomycin trough concentration* $\leftrightarrow$ *Vancomycin infusion* |
| **`DIAG_MONI_02`** | `DIAG_MONI_02_INV` | Monitoring | Anticoagulation Prothrombin Time | `Measurement -> Drug` | $[0.67, 1.50]$ | *International Normalized Ratio (INR)* $\leftrightarrow$ *Warfarin therapy* |
| **`DIAG_SURV_01`** | `DIAG_SURV_01_INV` | Surveillance | Post-Remission Oncologic Scan | `Procedure -> Condition` | $\le 0.67$ | *Resected stage III colon cancer* $\to$ *Surveillance contrast CT scan* |
| **`DIAG_SURV_02`** | `DIAG_SURV_02_INV` | Surveillance | Surveillance Upper Endoscopy | `Procedure -> Condition` | $\le 0.67$ | *Barrett's esophagus with metaplasia* $\to$ *Periodic surveillance EGD* |
| **`DIAG_DIFF_01`** | `DIAG_DIFF_01_INV` | Differential | Phenotypic Symptom Mimic | `Condition -> Condition` | $[0.67, 1.50]$ | *Viral gastroenteritis* $\leftrightarrow$ *Initial presentation of Crohn's disease* |
| **`DIAG_DIFF_02`** | `DIAG_DIFF_02_INV` | Differential | High-NPV Rule-Out Assay | `Measurement -> Condition` | $[0.67, 1.50]$ | *Normal quantitative D-dimer assay* $\leftrightarrow$ *Pulmonary embolism rule-out* |
| **`THER_FIRST_01`**| `THER_FIRST_01_INV`| First-Line | Guideline First-Line Pharmacotherapy | `Drug -> Condition` | $\le 0.67$ | *Metformin oral tablet* $\to$ *Type 2 diabetes mellitus* |
| **`THER_FIRST_02`**| `THER_FIRST_02_INV`| First-Line | Empirical Broad-Spectrum Antibiotic | `Drug -> Condition` | $\le 0.67$ | *Ceftriaxone + Azithromycin* $\to$ *Community-acquired pneumonia* |
| **`THER_ADJ_01`**  | `THER_ADJ_01_INV`  | Add-On | Add-On Antihypertensive Combination | `Drug -> Condition` | $\le 0.67$ | *Amlodipine added to Lisinopril* $\to$ *Refractory essential hypertension* |
| **`THER_ADJ_02`**  | `THER_ADJ_02_INV`  | Add-On | Adjuvant Post-Surgical Chemotherapy | `Drug -> Condition` | $\le 0.67$ | *Adjuvant Paclitaxel + Carboplatin* $\to$ *Resected breast carcinoma* |
| **`THER_RESC_01`** | `THER_RESC_01_INV` | Rescue | Inhaled Bronchodilator Rescue | `Drug -> Condition` | $[0.67, 1.50]$ | *Inhaled albuterol sulfate* $\leftrightarrow$ *Acute asthma exacerbation* |
| **`THER_RESC_02`** | `THER_RESC_02_INV` | Rescue | Vasopressor Hemodynamic Infusion | `Drug -> Condition` | $[0.67, 1.50]$ | *Intravenous norepinephrine infusion* $\leftrightarrow$ *Distributive septic shock* |
| **`THER_RESC_03`** | `THER_RESC_03_INV` | Rescue | Rapid Hypoglycemia Reversal Agent | `Drug -> Condition` | $[0.67, 1.50]$ | *Intravenous dextrose 50%* $\leftrightarrow$ *Severe insulin-induced hypoglycemia* |
| **`THER_MAINT_01`**| `THER_MAINT_01_INV`| Maintenance | Chronic Disease-Modifying DMARD | `Drug -> Condition` | $\le 0.67$ | *Oral Methotrexate* $\to$ *Seropositive rheumatoid arthritis* |
| **`THER_MAINT_02`**| `THER_MAINT_02_INV`| Maintenance | Plaque-Stabilizing Statin Therapy | `Drug -> Condition` | $\le 0.67$ | *High-intensity Atorvastatin 80 mg* $\to$ *Coronary atherosclerosis* |
| **`THER_MAINT_03`**| `THER_MAINT_03_INV`| Maintenance | Chronic Stroke Prevention Anticoagulant | `Drug -> Condition` | $\le 0.67$ | *Apixaban oral anticoagulant* $\to$ *Non-valvular atrial fibrillation* |
| **`THER_SURG_01`** | `THER_SURG_01_INV` | Surgical | Curative Total Organ Resection | `Procedure -> Condition` | $\le 0.67$ | *Laparoscopic appendectomy* $\to$ *Acute suppurative appendicitis* |
| **`THER_SURG_02`** | `THER_SURG_02_INV` | Surgical | Emergent Mechanical Decompression | `Procedure -> Condition` | $[0.67, 1.50]$ | *Emergent craniotomy* $\leftrightarrow$ *Acute epidural hematoma* |
| **`THER_SURG_03`** | `THER_SURG_03_INV` | Surgical | Revascularization Bypass Grafting | `Procedure -> Condition` | $\le 0.67$ | *Coronary artery bypass grafting (CABG)* $\to$ *Triple-vessel CAD* |
| **`THER_PROC_01`** | `THER_PROC_01_INV` | Catheter | Percutaneous Transluminal Angioplasty | `Procedure -> Condition` | $[0.67, 1.50]$ | *Primary PCI with drug-eluting stent* $\leftrightarrow$ *Acute STEMI presentation* |
| **`THER_PROC_02`** | `THER_PROC_02_INV` | Catheter | Chronic Maintenance Hemodialysis | `Procedure -> Condition` | $\le 0.67$ | *Extracorporeal hemodialysis access* $\to$ *End-stage renal disease* |
| **`THER_PROC_03`** | `THER_PROC_03_INV` | Catheter | Endoscopic Hemostatic Cauterization | `Procedure -> Condition` | $[0.67, 1.50]$ | *Endoscopic thermal coagulation / clip* $\leftrightarrow$ *Active bleeding peptic ulcer* |
| **`THER_DEV_01`**  | `THER_DEV_01_INV`  | Device | Sudden Death Prevention Defibrillator | `Procedure -> Condition` | $\le 0.67$ | *Implantable cardioverter-defibrillator* $\to$ *Ischemic cardiomyopathy* |
| **`THER_DEV_02`**  | `THER_DEV_02_INV`  | Device | Positive Airway Pressure Device | `Procedure -> Condition` | $\le 0.67$ | *Nocturnal CPAP machine* $\to$ *Severe obstructive sleep apnea* |
| **`THER_DEV_03`**  | `THER_DEV_03_INV`  | Device | Artificial Joint Prosthesis | `Procedure -> Condition` | $\le 0.67$ | *Total knee arthroplasty prosthesis* $\to$ *End-stage tricompartmental OA* |
| **`THER_CONTRA_01`**| `THER_CONTRA_01_INV`| Safety | Absolute Clinical Contraindication | `Drug -> Condition` | N/A | *Pioglitazone prescription* $\times$ *Decompensated NYHA IV heart failure* |
| **`THER_CONTRA_02`**| `THER_CONTRA_02_INV`| Safety | Renal Insufficiency Discontinuation | `Drug -> Condition` | N/A | *Metformin prescription* $\times$ *Severe renal failure (eGFR $< 30$)* |
| **`THER_PALL_01`** | `THER_PALL_01_INV` | Palliative | High-Potency Terminal Analgesia | `Drug -> Condition` | $\le 0.67$ | *Transdermal fentanyl patch* $\to$ *Metastatic pancreatic adenocarcinoma* |
| **`THER_PALL_02`** | `THER_PALL_02_INV` | Palliative | Malignant Fluid Drainage Catheter | `Procedure -> Condition` | $\le 0.67$ | *Tunneled peritoneal drainage catheter* $\to$ *Refractory malignant ascites* |
| **`THER_REHAB_01`**| `THER_REHAB_01_INV`| Rehabilitation | Supervised Phase II Cardiac Rehab | `Procedure -> Condition` | $\le 0.67$ | *Structured outpatient cardiac rehab* $\to$ *Post-myocardial infarction recovery* |
| **`THER_REHAB_02`**| `THER_REHAB_02_INV`| Rehabilitation | Neurologic Functional Gait Retraining | `Procedure -> Condition` | $\le 0.67$ | *Specialized physical therapy gait training* $\to$ *Post-stroke hemiparesis* |
| **`THER_SUBST_01`**| `THER_SUBST_01_INV`| Replacement | Exogenous Thyroid Hormone Substitution | `Drug -> Condition` | $\le 0.67$ | *Oral Levothyroxine sodium* $\to$ *Primary autoimmune hypothyroidism* |
| **`PROG_PROG_01`** | `PROG_PROG_01_INV` | Progression | Chronic Organ Disease Stage Advancement | `Condition -> Condition` | $\ge 1.50$ | *Chronic kidney disease Stage 3* $\to$ *End-stage renal disease (ESRD)* |
| **`PROG_PROG_02`** | `PROG_PROG_02_INV` | Progression | Malignant Dysplastic Transformation | `Condition -> Condition` | $\ge 1.50$ | *Colonic tubular adenoma with dysplasia* $\to$ *Invasive colonic cancer* |
| **`PROG_PROG_03`** | `PROG_PROG_03_INV` | Progression | Fibrotic End-Organ Remodeling | `Condition -> Condition` | $\ge 1.50$ | *Non-alcoholic steatohepatitis (MASH)* $\to$ *Decompensated liver cirrhosis* |
| **`PROG_FLARE_01`**| `PROG_FLARE_01_INV`| Exacerbation | Acute Chronic Airway Exacerbation | `Condition -> Condition` | $[0.67, 1.50]$ | *Chronic obstructive pulmonary disease* $\leftrightarrow$ *Acute COPD flare* |
| **`PROG_FLARE_02`**| `PROG_FLARE_02_INV`| Exacerbation | Systemic Autoimmune Disease Relapse | `Condition -> Condition` | $[0.67, 1.50]$ | *Systemic lupus erythematosus* $\leftrightarrow$ *Severe systemic lupus flare* |
| **`PROG_FLARE_03`**| `PROG_FLARE_03_INV`| Exacerbation | Relapsing Inflammatory Bowel Flare | `Condition -> Condition` | $[0.67, 1.50]$ | *Ulcerative colitis in remission* $\leftrightarrow$ *Acute severe ulcerative colitis flare* |
| **`PROG_LATE_01`** | `PROG_LATE_01_INV` | Sequelae | Late Microvascular Capillary Compromise | `Condition -> Condition` | $\ge 1.50$ | *Type 2 diabetes mellitus* $\to$ *Proliferative diabetic retinopathy* |
| **`PROG_LATE_02`** | `PROG_LATE_02_INV` | Sequelae | Macrovascular Critical Limb Ischemia | `Condition -> Condition` | $\ge 1.50$ | *Peripheral artery atherosclerosis* $\to$ *Wet gangrene of lower foot* |
| **`PROG_LATE_03`** | `PROG_LATE_03_INV` | Sequelae | Post-Infarction Ventricular Remodeling | `Condition -> Condition` | $\ge 1.50$ | *Transmural myocardial infarction* $\to$ *Dilated ischemic cardiomyopathy* |
| **`PROG_META_01`** | `PROG_META_01_INV` | Metastasis | Distant Solid Organ Metastasis | `Condition -> Condition` | $\ge 1.50$ | *Primary invasive breast cancer* $\to$ *Multiple osteolytic bone metastases* |
| **`PROG_META_02`** | `PROG_META_02_INV` | Metastasis | Regional Sentinel Lymph Node Seeding | `Condition -> Condition` | $\ge 1.50$ | *Cutaneous malignant melanoma* $\to$ *Sentinel lymph node micrometastasis* |
| **`PROG_META_03`** | `PROG_META_03_INV` | Metastasis | Leptomeningeal Meningeal Seeding | `Condition -> Condition` | $\ge 1.50$ | *Stage IV non-small cell lung cancer* $\to$ *Leptomeningeal carcinomatosis* |
| **`PROG_SEQL_01`** | `PROG_SEQL_01_INV` | Late Post-Inf | Post-Infectious Autoimmune Demyelination | `Condition -> Condition` | $\ge 1.50$ | *Campylobacter jejuni gastroenteritis* $\to$ *Guillain-Barré syndrome* |
| **`PROG_SEQL_02`** | `PROG_SEQL_02_INV` | Late Post-Inf | Chronic Post-Surgical Inguinodynia | `Procedure -> Condition` | $\ge 1.50$ | *Open mesh inguinal hernia repair* $\to$ *Chronic neuropathic inguinodynia* |
| **`PROG_SEQL_03`** | `PROG_SEQL_03_INV` | Late Post-Inf | Post-Acute Infection Syndrome (PASC) | `Condition -> Condition` | $\ge 1.50$ | *Acute SARS-CoV-2 infection* $\to$ *Post-acute sequelae of COVID-19* |
| **`PROG_SEQL_04`** | `PROG_SEQL_04_INV` | Late Post-Inf | Post-Endocarditis Valvular Destruction | `Condition -> Condition` | $\ge 1.50$ | *Staphylococcus aureus endocarditis* $\to$ *Severe mitral valve regurgitation* |
| **`PROG_REMIS_01`**| `PROG_REMIS_01_INV`| Remission | Spontaneous Proteinuria Remission | `Condition -> Condition` | $\ge 1.50$ | *Idiopathic nephrotic syndrome* $\to$ *Complete proteinuria remission* |
| **`PROG_REMIS_02`**| `PROG_REMIS_02_INV`| Remission | Pharmacologic Mucosal Remission | `Condition -> Condition` | $\ge 1.50$ | *Severe Crohn's colitis* $\to$ *Deep endoscopic mucosal healing* |
| **`PROG_SURV_01`** | `PROG_SURV_01_INV` | Remission | Five-Year Cancer Disease-Free Interval | `Condition -> Condition` | $\ge 1.50$ | *Resected stage II colonic cancer* $\to$ *Five-year disease-free survivorship* |
| **`PROG_DEATH_01`**| `PROG_DEATH_01_INV`| Terminal | Terminal Agonal Arrest Cascade | `Condition -> Condition` | $\ge 1.50$ | *Refractory septic multi-organ shock* $\to$ *In-hospital cardiac arrest* |
| **`ASSOC_SYND_01`**| `ASSOC_SYND_01_INV`| Syndromes | Insulin Resistance Comorbidity Triad | `Condition -> Condition` | $[0.67, 1.50]$ | *Essential hypertension* $\leftrightarrow$ *Hypertriglyceridemic dyslipidemia* |
| **`ASSOC_SYND_02`**| `ASSOC_SYND_02_INV`| Syndromes | Polyendocrine Autoimmune Destruction | `Condition -> Condition` | $[0.67, 1.50]$ | *Hashimoto autoimmune thyroiditis* $\leftrightarrow$ *Type 1 autoimmune diabetes* |
| **`ASSOC_SYND_03`**| `ASSOC_SYND_03_INV`| Syndromes | Neurocutaneous Ectodermal Dysplasia | `Condition -> Condition` | $[0.67, 1.50]$ | *Café-au-lait cutaneous macules* $\leftrightarrow$ *Plexiform neurofibromas* |
| **`ASSOC_SYND_04`**| `ASSOC_SYND_04_INV`| Syndromes | Atopic March Hypersensitivity Triad | `Condition -> Condition` | $[0.67, 1.50]$ | *Childhood atopic dermatitis* $\leftrightarrow$ *Allergic extrinsic asthma* |
| **`ASSOC_RISK_01`**| `ASSOC_RISK_01_INV`| Toxic Exposure | Chronic Tobacco Inhalation Morbidities | `Condition -> Condition` | $[0.67, 1.50]$ | *Chronic obstructive pulmonary disease* $\leftrightarrow$ *Coronary atherosclerosis* |
| **`ASSOC_RISK_02`**| `ASSOC_RISK_02_INV`| Toxic Exposure | Chronic Ethanol Ingestion Morbidities | `Condition -> Condition` | $[0.67, 1.50]$ | *Chronic calcific pancreatitis* $\leftrightarrow$ *Alcohol-related hepatic cirrhosis* |
| **`ASSOC_RISK_03`**| `ASSOC_RISK_03_INV`| Toxic Exposure | Severe Adiposity Mechanical Stressors | `Condition -> Condition` | $[0.67, 1.50]$ | *Severe morbid obesity (BMI $> 40$)* $\leftrightarrow$ *Severe knee osteoarthritis* |
| **`ASSOC_RISK_04`**| `ASSOC_RISK_04_INV`| Toxic Exposure | Shared Systemic Microvascular Sclerosis | `Condition -> Condition` | $[0.67, 1.50]$ | *Hypertensive benign nephrosclerosis* $\leftrightarrow$ *Arteriolosclerotic retinopathy* |
| **`ASSOC_ANAT_01`**| `ASSOC_ANAT_01_INV`| Anatomy | Contiguous Tissue Inflammation Spread | `Condition -> Condition` | $[0.67, 1.50]$ | *Acute odontogenic molar infection* $\leftrightarrow$ *Maxillary sinusitis empyema* |
| **`ASSOC_ANAT_02`**| `ASSOC_ANAT_02_INV`| Anatomy | Shared Coronary Arterial Bed Ischemia | `Condition -> Condition` | $[0.67, 1.50]$ | *Left anterior descending stenosis* $\leftrightarrow$ *Left circumflex atheroma* |
| **`ASSOC_ANAT_03`**| `ASSOC_ANAT_03_INV`| Anatomy | Bilateral Symmetric Joint Narrowing | `Condition -> Condition` | $[0.67, 1.50]$ | *Right knee medial osteoarthritis* $\leftrightarrow$ *Left knee medial osteoarthritis* |
| **`ASSOC_EPID_01`**| `ASSOC_EPID_01_INV`| Epidemiology | Senile Degenerative Co-Morbidities | `Condition -> Condition` | $[0.67, 1.50]$ | *Age-related senile osteoporosis* $\leftrightarrow$ *Benign prostatic hyperplasia* |
| **`ASSOC_EPID_02`**| `ASSOC_EPID_02_INV`| Epidemiology | Social Vulnerability Co-Morbidities | `Condition -> Condition` | $[0.67, 1.50]$ | *Severe major depressive disorder* $\leftrightarrow$ *Uncontrolled brittle type 2 diabetes* |
| **`ASSOC_EPID_03`**| `ASSOC_EPID_03_INV`| Epidemiology | Seasonal Epidemic Respiratory Viruses | `Condition -> Condition` | $[0.67, 1.50]$ | *Seasonal Influenza A infection* $\leftrightarrow$ *Respiratory syncytial virus (RSV)* |
| **`ASSOC_UTIL_01`**| `ASSOC_UTIL_01_INV`| Utilization | Intensive Care Invasive Line Monitoring | `Procedure -> Condition` | $[0.67, 1.50]$ | *Radial artery pressure catheterization* $\leftrightarrow$ *Septic shock vasopressor support* |
| **`ASSOC_UTIL_02`**| `ASSOC_UTIL_02_INV`| Utilization | Pre-Operative Surgical Clearance | `Procedure -> Condition` | $\ge 1.50$ | *Pre-operative 12-lead screening ECG* $\to$ *Elective total hip replacement* |
| **`ASSOC_UTIL_03`**| `ASSOC_UTIL_03_INV`| Utilization | Bundled Preventive Ambulatory Exam | `Procedure -> Procedure` | $[0.67, 1.50]$ | *Annual preventive physical examination* $\leftrightarrow$ *Routine outpatient screening lipid panel* |
| **`ASSOC_PHENO_01`**| `ASSOC_PHENO_01_INV`| Symptom Cluster | Central Pain Sensitization Cluster | `Condition -> Condition` | $[0.67, 1.50]$ | *Fibromyalgia chronic widespread pain* $\leftrightarrow$ *Irritable bowel syndrome* |
| **`ASSOC_PHENO_02`**| `ASSOC_PHENO_02_INV`| Symptom Cluster | Reactive Affective Depressive Syndrome | `Condition -> Condition` | $\ge 1.50$ | *Intractable lumbar radiculopathy pain* $\to$ *Secondary major depressive episode* |
| **`ASSOC_PHENO_03`**| `ASSOC_PHENO_03_INV`| Symptom Cluster | Subcortical Vascular Encephalopathy | `Condition -> Condition` | $\ge 1.50$ | *Diffuse cerebral small vessel disease* $\leftrightarrow$ *Subcortical vascular cognitive decline* |

---

## 5. Mathematical Coordination with Association Mining Pipeline v57

The 112 relation codes are formally coordinated with empirical statistical metrics produced by Pipeline v57 (`cab_s55_pair_all`):

### 5.1. Directionality Ratio ($DR$) Mechanics
The Directionality Ratio quantifies temporal asymmetry while enforcing continuity corrections for low-cell stability:

$$DR = \frac{N_{A \to B} + 0.5}{N_{B \to A} + 0.5}$$

Where:
- $N_{A \to B}$ is the number of distinct persons in whom the initial recording of Concept A strictly preceded the initial recording of Concept B ($t_A < t_B$);
- $N_{B \to A}$ is the number of distinct persons in whom Concept B preceded Concept A ($t_B < t_A$);
- Same-day co-occurrences ($t_A = t_B$) are tracked independently as $N_{A=B}$ and excluded from the directionality ratio to prevent false symmetric dilution.

```text
                                        TAXIS DIRECTIONALITY SPECTRUM
                Reverse Predominant            Balanced / Indeterminate         Forward Predominant
               (Concept B Precedes A)         (Balanced Precedence Counts)     (Concept A Precedes B)
          ◄─────────────────────────────┼─────────────────────────────┼─────────────────────────────►
                        │                             │                             │
                    DR ≤ 0.67                0.67 < DR < 1.50                   DR ≥ 1.50
                        │                             │                             │
             Interventions evaluated          Diagnostic Biomarkers            Etiologic Insults
             as A=Drug/Proc, B=Condition      Syndromic Clusters               Intermediate Precursors
             where diagnosis precedes rx      Contemporaneous Presentations    Late Complications
```

### 5.2. Mantel-Haenszel Stratified Lift ($\text{Lift}_{\text{strat}}$)
In unstratified association mining, hospitalized and frail patients generate elevated co-occurrence counts across all domains due to high **healthcare contact density**. TAXIS eliminates this confounding by calculating Stratified Lift across 10 empirical healthcare utilization deciles:

$$\text{Lift}_{\text{strat}}(A, B) = \frac{\sum_{k=1}^{10} w_k \cdot \text{Obs}_k(A, B)}{\sum_{k=1}^{10} w_k \cdot \text{Exp}_k(A, B)}$$

Where:
- $k \in \{1, \dots, 10\}$ indexes patient healthcare utilization deciles based on total unique concept-day counts;
- $\text{Obs}_k(A, B)$ is the observed patient co-occurrence count in decile $k$;
- $\text{Exp}_k(A, B) = \frac{\text{Obs}_k(A) \cdot \text{Obs}_k(B)}{N_k}$ is the expected co-occurrence count under independent assortment within decile $k$;
- $w_k = \frac{N_k}{\sum_{j} N_j}$ represents decile population weighting.

Pairs meeting statistical significance gates ($N_{AB} \ge 100$, $\text{Lift}_{\text{strat}} \ge 1.50$, Cochran-Mantel-Haenszel $p < 0.001$, Binomial directionality $p < 0.01$) are forwarded to the two-stage semantic classification framework.

---

## 6. Operational Translation to OHDSI Circe Phenotyping

When integrated into automated or agentic phenotype builders, Taxonomy v6.0 relations map to deterministic criteria slots within OHDSI Circe JSON cohort expressions:

### 6.1. The 6-Bucket Criteria Architecture
1. **Bucket 1: Primary Index Criteria (Entry Events)**:
   - Sourced from Class II diagnostic concepts or Class I primary disorder codes defining initial cohort entry.
2. **Bucket 2: Confirmatory Secondary Inclusion Criteria**:
   - Class II confirmatory assays (`DIAG_CONF_01`, `DIAG_CONF_02`, `DIAG_CONF_03`) and Class III first-line interventions (`THER_FIRST_01`, `THER_PROC_01`) occurring within qualified observation windows (e.g., $[-7, +30]$ days of index).
3. **Bucket 3: Baseline Risk Stratification & Historical Covariates**:
   - Class I antecedent etiologies (`ETIOL_CAUS_01`, `ETIOL_COMP_01`) and Class IV prior stages (`PROG_PROG_01`) observed in the baseline period (e.g., $[-365, -1]$ days).
4. **Bucket 4: Rule-Out Exclusion Boundaries & The 10% Anchor Mimic Cap (`DEC-GR-008`)**:
   - Restricted strictly to explicit differential diagnostic codes: `DIAG_DIFF_01` (Phenotypic Mimic Presentation) and `DIAG_DIFF_02` (Biomarker Rule-Out Assay).
   - In accordance with `DEC-GR-008`, rule-out exclusion candidates are capped at $\le 10\%$ co-occurrence with the index anchor. Blanket exclusions that eliminate $>10\%$ of anchor patients are rejected to prevent destructive attrition and selection bias.
5. **Bucket 5: Downstream Outcome & Endpoint Definition**:
   - Class IV late microvascular sequelae (`PROG_LATE_01`), distant metastases (`PROG_META_01`), and terminal agonal events (`PROG_DEATH_01`) occurring in the prospective risk window ($[+1, +\infty]$ days).
6. **Bucket 6: Candidate Negative Control Hypotheses**:
   - Concept pairs exhibiting an absence of biological mechanisms across all 112 taxonomy codes, formulated as explicit causal-null hypotheses ($H_0: \text{RR} = 1.0$) for empirical calibration.

---

## 7. Governance, Privacy & Dissemination

All implementations and derivative knowledge graphs must adhere to core study governance:
1. **Aggregate-Only Public Knowledge (`DEC-GR-005`)**: All 112 taxonomy codes represent generalizable, public medical facts.
2. **Small-Cell Privacy Suppression**: Cell counts $<5$ are masked to $-1$.
3. **Repository Cleanliness (`DEC-GR-028`)**: Zero person-level data or raw database dumps in GitHub repositories.
4. **Attribution Integrity**: Any academic or clinical dissemination must credit the study leadership: Stephen H. Bandeian, MD, JD (PI), J. Marc Overhage, MD, PhD (Co-PI), Gowtham Rao, MD, PhD, and Shaun Grannis, MD, MS.
5. **Scholarly Language Standard (`DEC-GR-032`)**: All descriptions must maintain publication-grade medical and scientific English.

---
