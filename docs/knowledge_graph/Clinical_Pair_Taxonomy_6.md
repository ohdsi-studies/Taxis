# TAXIS Clinical Pair Taxonomy v6.0
## Formal Knowledge Graph Schema, Relationship Catalog & Directional Precedence Rules

> **Document Type**: Scientific Architecture & Knowledge Representation Specification  
> **Target Release**: Wave 6 (`wave/06-clinical-kg-taxonomy`)  
> **Taxonomic Scale**: 112 Standardized Relation Codes across 32 Relation Families and 5 Broad Clinical Classes  
> **Source Pipeline**: Indiana Network for Patient Care (INPC) OMOP CDM v5.4 Production Run (2.16M Longitudinal Patients)  
> **Authoritative Decisions**:  
> • `DEC-GR-005`: Aggregate-Only Non-PHI Policy (all taxonomy codes represent public medical facts)  
> • `DEC-GR-006`: Target Federated CDM Deployments (Claims, EHR, International CDMs)  
> • `DEC-GR-010`: Dual Lift Reporting Architecture (Unadjusted vs. Stratified Lift)  
> **Study Leadership**:  
> • Stephen H. Bandeian, MD, JD – Principal Investigator, Johns Hopkins University School of Medicine  
> • J. Marc Overhage, MD, PhD – Co-Principal Investigator, The Overhage Group / Indiana University School of Medicine  
> • Gowtham Rao, MD, PhD – Investigator, [CoReason, Inc.](https://www.coreason.ai) USA; OHDSI (Phenotype working group)  
> • Shaun Grannis, MD, MS – Investigator, Regenstrief Institute / Indiana University School of Medicine  

> **Operational Boundary Notice (`DEC-GR-027`, `DEC-GR-029`)**:
> The TAXIS network study package (`ohdsi-studies/Taxis`) is an **empirical association mining engine**, designed to execute standardized SQL across network partners to materialize population-level co-occurrence statistics (`cab_s55_pair_all`). The Clinical Pair Taxonomy described below is an **illustrative downstream knowledge representation schema** for organizing mined relationships. It is **not** part of the SQL package execution on partner CDMs (`extras/CodeToRun.R`).

---

## 1. Executive Summary & Epistemic Foundations

Standard biomedical ontologies (such as SNOMED-CT, RxNorm, and LOINC) structure clinical concepts through hierarchical taxonomies (*is-a* relationships). However, empirical vocabulary audits demonstrate that standard vocabularies reflect **less than 0.5%** of the operational, cross-domain semantic relationships required for real-world healthcare analytics (such as which laboratory measurement confirms a diagnosis, which medication represents first-line therapy, or which chronic condition precipitates an acute complication).

The **TAXIS Clinical Pair Taxonomy v6.0** provides the formal semantic schema bridging empirical data-mined concept associations (Pipeline v57) with neuro-symbolic reasoning and automated Circe phenotype generation.

The taxonomy comprises **112 standardized relation codes** organized into **32 relation families** across **5 broad clinical classes**:

```text
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        TAXIS CLINICAL PAIR TAXONOMY v6.0 ARCHITECTURE                  │
└────────────────────────────────────────────────────────────────────────────────────────┘
                                            │
        ┌───────────────────┬───────────────┴───────────────┬───────────────────┐
        ▼                   ▼                               ▼                   ▼
  [ CLASS I ]         [ CLASS II ]                    [ CLASS III ]        [ CLASS IV ]
  Causal &            Diagnostic &                    Therapeutic &        Prognostic &
  Etiologic           Indicative                      Interventional       Evolutionary
  (24 Codes /         (22 Codes /                     (26 Codes /          (20 Codes /
   7 Families)         6 Families)                     8 Families)          6 Families)
        │                   │                               │                   │
        └───────────────────┼───────────────────────────────┴───────────────────┘
                            │
                            ▼
                      [ CLASS V ]
                      Associational & Phenotypic
                      (20 Codes / 5 Families)
```

Each relation code in Taxonomy v6.0 is defined by:
1. A **Unique Mnemonic Identifier** (e.g., `ETIOL_CAUS_01`, `DIAG_CONF_01`).
2. A **Canonical Natural Language Label**.
3. A **Strict Inverse Relation** ensuring bidirectional knowledge graph consistency.
4. **Valid Domain Constraints** across OMOP CDM domains (`Condition`, `Drug`, `Measurement`, `Procedure`).
5. **Expected Directionality Ratio ($DR$)** calibrated against empirical longitudinal pipeline cutoffs:
   - Forward Predominant ($DR \ge 1.50$): Index Concept A precedes Outcome Concept B.
   - Reverse Predominant ($DR \le 0.67$): Concept B precedes Concept A.
   - Symmetric / Non-Directional ($0.67 < DR < 1.50$): Co-incident or contemporaneous presentation.
6. **Clinical Inclusion & Exclusion Boundaries** defining exact semantic limits.

---

## 2. Taxonomic Schema & Relation Catalog (112 Codes)

### Class I: Causal & Etiologic Relationships (24 Codes / 7 Families)
*Relationships where Concept A acts as an antecedent pathogen, underlying etiology, mechanical trigger, or causal insult precipitating Concept B.*

| Code ID | Inverse Code | Canonical Label | Domain Constraint | Expected DR | Clinical Scope |
|---|---|---|---|:---:|---|
| `ETIOL_CAUS_01` | `ETIOL_CAUS_01_INV` | Primary Infectious Etiology | `Condition -> Condition` | $\ge 1.50$ | Pathogen infection causing clinical disease (e.g., *Streptococcal pharyngitis* $\to$ *Post-streptococcal glomerulonephritis*). |
| `ETIOL_CAUS_02` | `ETIOL_CAUS_02_INV` | Bacterial Superinfection | `Condition -> Condition` | $\ge 1.50$ | Secondary bacterial infection following viral illness (e.g., *Influenza* $\to$ *Bacterial pneumonia*). |
| `ETIOL_CAUS_03` | `ETIOL_CAUS_03_INV` | Opportunistic Infection | `Condition -> Condition` | $\ge 1.50$ | Pathogen manifesting in host immunocompromise (e.g., *HIV infection* $\to$ *Pneumocystis jirovecii pneumonia*). |
| `ETIOL_TOX_01` | `ETIOL_TOX_01_INV` | Drug-Induced Toxic Neuropathy | `Drug -> Condition` | $\ge 1.50$ | Pharmacologic agent causing peripheral nerve toxicity (e.g., *Paclitaxel* $\to$ *Peripheral neuropathy*). |
| `ETIOL_TOX_02` | `ETIOL_TOX_02_INV` | Drug-Induced Hepatotoxicity | `Drug -> Condition` | $\ge 1.50$ | Medication-induced liver injury (e.g., *Acetaminophen overdose* $\to$ *Acute hepatic failure*). |
| `ETIOL_TOX_03` | `ETIOL_TOX_03_INV` | Drug-Induced Nephrotoxicity | `Drug -> Condition` | $\ge 1.50$ | Renal insult secondary to drug administration (e.g., *Gentamicin* $\to$ *Acute tubular necrosis*). |
| `ETIOL_TOX_04` | `ETIOL_TOX_04_INV` | Drug-Induced Cardiotoxicity | `Drug -> Condition` | $\ge 1.50$ | Myocardial or arrhythmic insult from pharmacotherapy (e.g., *Doxorubicin* $\to$ *Cardiomyopathy*). |
| `ETIOL_COMP_01` | `ETIOL_COMP_01_INV` | Acute Organ Failure Complication | `Condition -> Condition` | $\ge 1.50$ | Acute decompensation of an organ system (e.g., *Sepsis* $\to$ *Acute respiratory distress syndrome*). |
| `ETIOL_COMP_02` | `ETIOL_COMP_02_INV` | Vascular Ischemic Complication | `Condition -> Condition` | $\ge 1.50$ | Thrombotic/embolic downstream occlusion (e.g., *Atrial fibrillation* $\to$ *Ischemic stroke*). |
| `ETIOL_COMP_03` | `ETIOL_COMP_03_INV` | Metabolic Decompensation | `Condition -> Condition` | $\ge 1.50$ | Acute metabolic crisis (e.g., *Type 1 diabetes* $\to$ *Diabetic ketoacidosis*). |
| `ETIOL_COMP_04` | `ETIOL_COMP_04_INV` | Hemorrhagic Complication | `Condition -> Condition` | $\ge 1.50$ | Secondary bleeding event (e.g., *Peptic ulcer disease* $\to$ *Upper gastrointestinal hemorrhage*). |
| `ETIOL_TRAUM_01`| `ETIOL_TRAUM_01_INV`| Mechanical Trauma Injury | `Condition -> Condition` | $\ge 1.50$ | Physical trauma producing anatomical damage (e.g., *Motor vehicle collision* $\to$ *Splenic laceration*). |
| `ETIOL_TRAUM_02`| `ETIOL_TRAUM_02_INV`| Post-Traumatic Syndrome | `Condition -> Condition` | $\ge 1.50$ | Chronic sequelae of acute mechanical injury (e.g., *Concussion* $\to$ *Post-concussion syndrome*). |
| `ETIOL_GEN_01` | `ETIOL_GEN_01_INV` | Monogenic Manifestation | `Condition -> Condition` | $\ge 1.50$ | Single-gene defect manifesting as organ pathology (e.g., *Cystic fibrosis mutation* $\to$ *Bronchiectasis*). |
| `ETIOL_GEN_02` | `ETIOL_GEN_02_INV` | Familial Predisposition State | `Condition -> Condition` | $\ge 1.50$ | Inherited disorder predisposing to malignancy (e.g., *Lynch syndrome* $\to$ *Colorectal carcinoma*). |
| `ETIOL_IMM_01` | `ETIOL_IMM_01_INV` | Autoimmune Target Attack | `Condition -> Condition` | $\ge 1.50$ | Systemic autoimmune disease targeting organ (e.g., *Systemic lupus erythematosus* $\to$ *Lupus nephritis*). |
| `ETIOL_IMM_02` | `ETIOL_IMM_02_INV` | Allergic Hypersensitivity Reaction | `Drug -> Condition` | $\ge 1.50$ | IgE or T-cell mediated drug reaction (e.g., *Amoxicillin* $\to$ *Anaphylaxis*). |
| `ETIOL_IMM_03` | `ETIOL_IMM_03_INV` | Immune Complex Vasculitis | `Condition -> Condition` | $\ge 1.50$ | Deposition of immune complexes (e.g., *Hepatitis B* $\to$ *Polyarteritis nodosa*). |
| `ETIOL_ENV_01` | `ETIOL_ENV_01_INV` | Occupational Particulate Exposure | `Condition -> Condition` | $\ge 1.50$ | Inhaled environmental mineral or chemical dust (e.g., *Silica exposure* $\to$ *Silicosis*). |
| `ETIOL_ENV_02` | `ETIOL_ENV_02_INV` | Thermal / Radiation Injury | `Condition -> Condition` | $\ge 1.50$ | Physical radiation or thermal damage (e.g., *Radiation therapy* $\to$ *Radiation enteritis*). |
| `ETIOL_MET_01` | `ETIOL_MET_01_INV` | Nutritional Deficiency State | `Condition -> Condition` | $\ge 1.50$ | Vitamin or trace element absence (e.g., *Vitamin B12 deficiency* $\to$ *Subacute combined degeneration*). |
| `ETIOL_MET_02` | `ETIOL_MET_02_INV` | Substrate Deposition Pathology | `Condition -> Condition` | $\ge 1.50$ | Insoluble metabolite accumulation (e.g., *Hyperuricemia* $\to$ *Gouty arthritis*). |
| `ETIOL_SECO_01` | `ETIOL_SECO_01_INV` | Secondary Endocrine Disorder | `Condition -> Condition` | $\ge 1.50$ | Non-endocrine disease altering hormone axis (e.g., *Chronic kidney disease* $\to$ *Secondary hyperparathyroidism*). |
| `ETIOL_SECO_02` | `ETIOL_SECO_02_INV` | Secondary Hematologic Disorder | `Condition -> Condition` | $\ge 1.50$ | Chronic systemic disease suppressing bone marrow (e.g., *Rheumatoid arthritis* $\to$ *Anemia of chronic disease*). |

---

### Class II: Diagnostic & Indicative Relationships (22 Codes / 6 Families)
*Relationships where Concept A serves as an objective biomarker, confirmatory test, clinical sign, or staging assessment for Concept B.*

| Code ID | Inverse Code | Canonical Label | Domain Constraint | Expected DR | Clinical Scope |
|---|---|---|---|:---:|---|
| `DIAG_CONF_01` | `DIAG_CONF_01_INV` | Pathognomonic Confirmatory Lab | `Measurement -> Condition` | $[0.67, 1.50]$ | Gold-standard diagnostic lab test (e.g., *Elevated Troponin I* $\leftrightarrow$ *Acute myocardial infarction*). |
| `DIAG_CONF_02` | `DIAG_CONF_02_INV` | Molecular Genetic Confirmation | `Measurement -> Condition` | $[0.67, 1.50]$ | Polymerase chain reaction or sequencing assay (e.g., *BCR-ABL1 detected* $\leftrightarrow$ *Chronic myeloid leukemia*). |
| `DIAG_CONF_03` | `DIAG_CONF_03_INV` | Histopathologic Biopsy Confirmation | `Procedure -> Condition` | $[0.67, 1.50]$ | Tissue biopsy demonstrating diagnostic histology (e.g., *Renal biopsy* $\leftrightarrow$ *IgA nephropathy*). |
| `DIAG_SCRN_01` | `DIAG_SCRN_01_INV` | Population Screening Test | `Procedure -> Condition` | $\ge 1.50$ | Routine asymptomatic screening procedure (e.g., *Screening colonoscopy* $\to$ *Colorectal adenoma*). |
| `DIAG_SCRN_02` | `DIAG_SCRN_02_INV` | Serologic Screening Titer | `Measurement -> Condition` | $\ge 1.50$ | Initial high-sensitivity blood screen (e.g., *Elevated PSA* $\to$ *Prostatic neoplasm*). |
| `DIAG_MARK_01` | `DIAG_MARK_01_INV` | Inflammatory Acute Phase Reactant | `Measurement -> Condition` | $[0.67, 1.50]$ | Non-specific systemic inflammatory marker (e.g., *Elevated C-reactive protein* $\leftrightarrow$ *Giant cell arteritis*). |
| `DIAG_MARK_02` | `DIAG_MARK_02_INV` | Hemodynamic Strain Marker | `Measurement -> Condition` | $[0.67, 1.50]$ | Neurohormonal ventricular strain peptide (e.g., *Elevated NT-proBNP* $\leftrightarrow$ *Congestive heart failure*). |
| `DIAG_MARK_03` | `DIAG_MARK_03_INV` | Metabolic Derangement Marker | `Measurement -> Condition` | $[0.67, 1.50]$ | Glycated hemoglobin or lipid fraction (e.g., *Elevated HbA1c* $\leftrightarrow$ *Type 2 diabetes mellitus*). |
| `DIAG_MARK_04` | `DIAG_MARK_04_INV` | Cellular Cytopenia Indicator | `Measurement -> Condition` | $[0.67, 1.50]$ | Quantitative marrow suppression (e.g., *Low absolute neutrophil count* $\leftrightarrow$ *Neutropenic fever*). |
| `DIAG_IMAG_01` | `DIAG_IMAG_01_INV` | Cross-Sectional Diagnostic CT/MRI | `Procedure -> Condition` | $[0.67, 1.50]$ | Advanced anatomical diagnostic imaging (e.g., *CT abdomen/pelvis* $\leftrightarrow$ *Acute appendicitis*). |
| `DIAG_IMAG_02` | `DIAG_IMAG_02_INV` | Echocardiographic Functional Study | `Procedure -> Condition` | $[0.67, 1.50]$ | Transthoracic/transesophageal echo (e.g., *Echocardiography* $\leftrightarrow$ *Aortic valve stenosis*). |
| `DIAG_IMAG_03` | `DIAG_IMAG_03_INV` | Nuclear Perfusion Scintigraphy | `Procedure -> Condition` | $[0.67, 1.50]$ | Radiotracer perfusion imaging (e.g., *Myocardial perfusion scan* $\leftrightarrow$ *Coronary artery disease*). |
| `DIAG_SIGN_01` | `DIAG_SIGN_01_INV` | Cardinal Physical Sign | `Condition -> Condition` | $[0.67, 1.50]$ | Physical examination finding characteristic of illness (e.g., *Ascites* $\leftrightarrow$ *Cirrhosis of liver*). |
| `DIAG_SIGN_02` | `DIAG_SIGN_02_INV` | Electrocardiographic Diagnostic Wave | `Procedure -> Condition` | $[0.67, 1.50]$ | Electrical recording anomaly (e.g., *ST elevation ECG* $\leftrightarrow$ *ST-elevation myocardial infarction*). |
| `DIAG_STAG_01` | `DIAG_STAG_01_INV` | Oncologic Staging Workup | `Procedure -> Condition` | $\le 0.67$ | Whole-body imaging evaluating metastatic burden (e.g., *Lung cancer* $\to$ *PET-CT scan whole body*). |
| `DIAG_STAG_02` | `DIAG_STAG_02_INV` | Invasive Hemodynamic Right Heart Cath | `Procedure -> Condition` | $\le 0.67$ | Pressure transducer catheterization (e.g., *Pulmonary hypertension* $\to$ *Right heart catheterization*). |
| `DIAG_MONI_01` | `DIAG_MONI_01_INV` | Therapeutic Drug Level Monitoring | `Measurement -> Drug` | $[0.67, 1.50]$ | Serum concentration assay (e.g., *Serum vancomycin level* $\leftrightarrow$ *Vancomycin therapy*). |
| `DIAG_MONI_02` | `DIAG_MONI_02_INV` | Anticoagulation Intensity Monitor | `Measurement -> Drug` | $[0.67, 1.50]$ | Coagulation cascade test guiding dose (e.g., *Prothrombin time / INR* $\leftrightarrow$ *Warfarin therapy*). |
| `DIAG_SURV_01` | `DIAG_SURV_01_INV` | Post-Remission Surveillance Imaging | `Procedure -> Condition` | $\le 0.67$ | Periodic interval scan detecting relapse (e.g., *Colorectal carcinoma in remission* $\to$ *Surveillance CT*). |
| `DIAG_SURV_02` | `DIAG_SURV_02_INV` | Endoscopic Surveillance Interval | `Procedure -> Condition` | $\le 0.67$ | Mucosal inspection in premalignant lesions (e.g., *Barrett's esophagus* $\to$ *Surveillance EGD*). |
| `DIAG_DIFF_01` | `DIAG_DIFF_01_INV` | Phenotypic Mimic Presentation | `Condition -> Condition` | $[0.67, 1.50]$ | Clinical syndrome sharing identical symptoms (e.g., *Viral gastroenteritis* $\leftrightarrow$ *Crohn's disease flare*). |
| `DIAG_DIFF_02` | `DIAG_DIFF_02_INV` | Biomarker Rule-Out Assay | `Measurement -> Condition` | $[0.67, 1.50]$ | High-negative-predictive value assay (e.g., *Negative D-dimer* $\leftrightarrow$ *Pulmonary embolism rule-out*). |

---

### Class III: Therapeutic & Interventional Relationships (26 Codes / 8 Families)
*Relationships where Concept A represents a pharmacologic, surgical, device, or behavioral treatment indicated, contraindicated, or tailored for Concept B.*

| Code ID | Inverse Code | Canonical Label | Domain Constraint | Expected DR | Clinical Scope |
|---|---|---|---|:---:|---|
| `THER_FIRST_01`| `THER_FIRST_01_INV`| First-Line Guideline Pharmacotherapy | `Drug -> Condition` | $\le 0.67$ | Primary drug recommended by standard of care (e.g., *Type 2 diabetes* $\to$ *Metformin*). |
| `THER_FIRST_02`| `THER_FIRST_02_INV`| Empirical First-Line Antimicrobial | `Drug -> Condition` | $\le 0.67$ | Initial broad-spectrum antibiotic (e.g., *Community-acquired pneumonia* $\to$ *Ceftriaxone + Azithromycin*). |
| `THER_ADJ_01`  | `THER_ADJ_01_INV`  | Add-On Combination Pharmacotherapy | `Drug -> Condition` | $\le 0.67$ | Second agent added for glycemic or BP control (e.g., *Hypertension* $\to$ *Amlodipine + Lisinopril*). |
| `THER_ADJ_02`  | `THER_ADJ_02_INV`  | Adjuvant Post-Surgical Chemotherapy | `Drug -> Condition` | $\le 0.67$ | Systemic therapy following tumor resection (e.g., *Resected breast cancer* $\to$ *Adjuvant paclitaxel*). |
| `THER_RESC_01` | `THER_RESC_01_INV` | Acute Bronchodilator Rescue Therapy | `Drug -> Condition` | $[0.67, 1.50]$ | Fast-acting symptomatic relief agent (e.g., *Acute asthma exacerbation* $\leftrightarrow$ *Inhaled albuterol*). |
| `THER_RESC_02` | `THER_RESC_02_INV` | Hemodynamic Vasopressor Support | `Drug -> Condition` | $[0.67, 1.50]$ | Intravenous inotrope or vasoconstrictor (e.g., *Septic shock* $\leftrightarrow$ *Norepinephrine infusion*). |
| `THER_RESC_03` | `THER_RESC_03_INV` | Hypoglycemia Reversal Agent | `Drug -> Condition` | $[0.67, 1.50]$ | Rapid glucose elevator (e.g., *Severe hypoglycemia* $\leftrightarrow$ *Intravenous dextrose / Glucagon*). |
| `THER_MAINT_01`| `THER_MAINT_01_INV`| Long-Term Disease-Modifying Agent | `Drug -> Condition` | $\le 0.67$ | Maintenance immunomodulator (e.g., *Rheumatoid arthritis* $\to$ *Methotrexate*). |
| `THER_MAINT_02`| `THER_MAINT_02_INV`| Secondary Cardiovascular Prevention | `Drug -> Condition` | $\le 0.67$ | Chronic plaque-stabilizing agent (e.g., *Coronary atherosclerosis* $\to$ *High-intensity Atorvastatin*). |
| `THER_MAINT_03`| `THER_MAINT_03_INV`| Chronic Anticoagulation Prophylaxis | `Drug -> Condition` | $\le 0.67$ | Long-term stroke prevention agent (e.g., *Atrial fibrillation* $\to$ *Apixaban*). |
| `THER_SURG_01` | `THER_SURG_01_INV` | Definitive Curative Organ Resection | `Procedure -> Condition` | $\le 0.67$ | Complete surgical extirpation (e.g., *Acute cholecystitis* $\to$ *Laparoscopic cholecystectomy*). |
| `THER_SURG_02` | `THER_SURG_02_INV` | Emergent Decompressive Procedure | `Procedure -> Condition` | $[0.67, 1.50]$ | Life-saving mechanical decompression (e.g., *Epidural hematoma* $\leftrightarrow$ *Emergent craniotomy*). |
| `THER_SURG_03` | `THER_SURG_03_INV` | Revascularization Bypass Grafting | `Procedure -> Condition` | $\le 0.67$ | Arterial bypass restoring flow (e.g., *Multivessel coronary disease* $\to$ *CABG surgery*). |
| `THER_PROC_01` | `THER_PROC_01_INV` | Percutaneous Coronary Angioplasty | `Procedure -> Condition` | $[0.67, 1.50]$ | Catheter-based balloon dilation/stenting (e.g., *Acute coronary syndrome* $\leftrightarrow$ *PCI with stent*). |
| `THER_PROC_02` | `THER_PROC_02_INV` | Renal Replacement Hemodialysis | `Procedure -> Condition` | $\le 0.67$ | Extracorporeal toxin filtration (e.g., *End-stage renal disease* $\to$ *Maintenance hemodialysis*). |
| `THER_PROC_03` | `THER_PROC_03_INV` | Endoscopic Hemostatic Intervention | `Procedure -> Condition` | $[0.67, 1.50]$ | Endoscopic clipping or cautery (e.g., *Bleeding peptic ulcer* $\leftrightarrow$ *Endoscopic hemoclip*). |
| `THER_DEV_01`  | `THER_DEV_01_INV`  | Implantable Cardiac Defibrillator | `Procedure -> Condition` | $\le 0.67$ | Electronic sudden death prevention device (e.g., *Low ejection fraction* $\to$ *ICD implantation*). |
| `THER_DEV_02`  | `THER_DEV_02_INV`  | Continuous Positive Airway Pressure | `Procedure -> Condition` | $\le 0.67$ | Mechanical airway splinting device (e.g., *Obstructive sleep apnea* $\to$ *CPAP application*). |
| `THER_DEV_03`  | `THER_DEV_03_INV`  | Total Joint Arthroplasty Prosthesis | `Procedure -> Condition` | $\le 0.67$ | Artificial joint replacement (e.g., *Severe knee osteoarthritis* $\to$ *Total knee replacement*). |
| `THER_CONTRA_01`| `THER_CONTRA_01_INV`| Absolute Black-Box Contraindication | `Drug -> Condition` | N/A | Medication causing fatal toxicity in disease (e.g., *End-stage heart failure* $\times$ *Thiazolidinediones*). |
| `THER_CONTRA_02`| `THER_CONTRA_02_INV`| Renal Impairment Dose Elimination | `Drug -> Condition` | N/A | Drug contraindicated at low eGFR (e.g., *eGFR < 30 mL/min* $\times$ *Metformin*). |
| `THER_PALL_01` | `THER_PALL_01_INV` | Terminal Oncologic Pain Palliation | `Drug -> Condition` | $\le 0.67$ | Opioid analgesia for advanced cancer (e.g., *Metastatic pancreatic cancer* $\to$ *Fentanyl patch*). |
| `THER_PALL_02` | `THER_PALL_02_INV` | Palliative Drainage Catheter | `Procedure -> Condition` | $\le 0.67$ | Indwelling catheter for malignant ascites (e.g., *Malignant ascites* $\to$ *PleurX peritoneal catheter*). |
| `THER_REHAB_01`| `THER_REHAB_01_INV`| Cardiac Phase II Rehabilitation | `Procedure -> Condition` | $\le 0.67$ | Structured supervised exercise protocol (e.g., *Post-MI state* $\to$ *Cardiac rehabilitation*). |
| `THER_REHAB_02`| `THER_REHAB_02_INV`| Neurologic Physical Therapy | `Procedure -> Condition` | $\le 0.67$ | Gait and balance retraining (e.g., *Post-stroke hemiparesis* $\to$ *Physical therapy gait training*). |
| `THER_SUBST_01`| `THER_SUBST_01_INV`| Hormone Replacement Therapy | `Drug -> Condition` | $\le 0.67$ | Exogenous endocrine replacement (e.g., *Primary hypothyroidism* $\to$ *Levothyroxine*). |

---

### Class IV: Prognostic & Disease Evolution Relationships (20 Codes / 6 Families)
*Relationships where Concept A represents an earlier stage, intermediate phenotype, or acute exacerbation evolving chronologically into Concept B.*

| Code ID | Inverse Code | Canonical Label | Domain Constraint | Expected DR | Clinical Scope |
|---|---|---|---|:---:|---|
| `PROG_PROG_01` | `PROG_PROG_01_INV` | Chronic Disease Progression Stage | `Condition -> Condition` | $\ge 1.50$ | Advancement to severe organ failure (e.g., *CKD Stage 3* $\to$ *End-Stage Renal Disease*). |
| `PROG_PROG_02` | `PROG_PROG_02_INV` | Malignant Transformation | `Condition -> Condition` | $\ge 1.50$ | Premalignant lesion developing invasive cancer (e.g., *Colonic tubular adenoma* $\to$ *Adenocarcinoma*). |
| `PROG_PROG_03` | `PROG_PROG_03_INV` | Fibrotic Tissue Remodeling | `Condition -> Condition` | $\ge 1.50$ | Chronic inflammation yielding end-stage scar (e.g., *NASH / MASH* $\to$ *Hepatic cirrhosis*). |
| `PROG_FLARE_01`| `PROG_FLARE_01_INV`| Acute Exacerbation of Chronic Airway | `Condition -> Condition` | $[0.67, 1.50]$ | Rapid respiratory decompensation (e.g., *Chronic obstructive pulmonary disease* $\leftrightarrow$ *Acute COPD exacerbation*). |
| `PROG_FLARE_02`| `PROG_FLARE_02_INV`| Autoimmune Systemic Disease Flare | `Condition -> Condition` | $[0.67, 1.50]$ | Acute clinical relapse of lupus or vasculitis (e.g., *Systemic lupus erythematosus* $\leftrightarrow$ *Lupus flare*). |
| `PROG_FLARE_03`| `PROG_FLARE_03_INV`| Inflammatory Bowel Relapse | `Condition -> Condition` | $[0.67, 1.50]$ | Mucosal ulceration surge in quiescent disease (e.g., *Ulcerative colitis* $\leftrightarrow$ *Severe UC flare*). |
| `PROG_LATE_01` | `PROG_LATE_01_INV` | End-Stage Microvascular Sequelae | `Condition -> Condition` | $\ge 1.50$ | Decades-long capillary compromise (e.g., *Diabetes mellitus* $\to$ *Proliferative diabetic retinopathy*). |
| `PROG_LATE_02` | `PROG_LATE_02_INV` | Late Macrovascular Claudication | `Condition -> Condition` | $\ge 1.50$ | Chronic lower-extremity ischemia (e.g., *Atherosclerosis* $\to$ *Gangrene of lower limb*). |
| `PROG_LATE_03` | `PROG_LATE_03_INV` | Post-Infarction Structural Remodeling | `Condition -> Condition` | $\ge 1.50$ | Dilated ventricular remodeling (e.g., *Transmural myocardial infarction* $\to$ *Ischemic cardiomyopathy*). |
| `PROG_META_01` | `PROG_META_01_INV` | Hematogenous Distant Metastasis | `Condition -> Condition` | $\ge 1.50$ | Solid tumor dissemination to solid organ (e.g., *Primary breast cancer* $\to$ *Bone metastasis*). |
| `PROG_META_02` | `PROG_META_02_INV` | Regional Lymph Node Dissemination | `Condition -> Condition` | $\ge 1.50$ | Tumor spread along regional lymph nodes (e.g., *Cutaneous melanoma* $\to$ *Sentinel node metastasis*). |
| `PROG_META_03` | `PROG_META_03_INV` | Leptomeningeal Carcinomatosis | `Condition -> Condition` | $\ge 1.50$ | CSF infiltration by malignant cells (e.g., *Non-small cell lung cancer* $\to$ *Leptomeningeal metastases*). |
| `PROG_SEQL_01` | `PROG_SEQL_01_INV` | Post-Infectious Inflammatory Sequela | `Condition -> Condition` | $\ge 1.50$ | Delayed immune response to cleared microbe (e.g., *Campylobacter jejuni* $\to$ *Guillain-Barré syndrome*). |
| `PROG_SEQL_02` | `PROG_SEQL_02_INV` | Post-Surgical Chronic Neuropathic Pain | `Procedure -> Condition` | $\ge 1.50$ | Persistent nerve pain following intervention (e.g., *Inguinal hernia repair* $\to$ *Chronic inguinodynia*). |
| `PROG_SEQL_03` | `PROG_SEQL_03_INV` | Post-Viral Chronic Fatigue Manifestation| `Condition -> Condition` | $\ge 1.50$ | Multisystem fatigue syndrome post-infection (e.g., *Acute COVID-19 infection* $\to$ *Long COVID syndrome*). |
| `PROG_SEQL_04` | `PROG_SEQL_04_INV` | Structural Valve Fibrosis Post-Endocarditis| `Condition -> Condition`| $\ge 1.50$ | Valvular insufficiency following bacteremia (e.g., *Infective endocarditis* $\to$ *Severe mitral regurgitation*). |
| `PROG_REMIS_01`| `PROG_REMIS_01_INV`| Spontaneous Complete Remission State | `Condition -> Condition` | $\ge 1.50$ | Resolution of active disease state (e.g., *Nephrotic syndrome* $\to$ *Complete remission of proteinuria*). |
| `PROG_REMIS_02`| `PROG_REMIS_02_INV`| Treatment-Induced Quiescent Phase | `Condition -> Condition` | $\ge 1.50$ | Pharmacologic stabilization (e.g., *Severe Crohn's disease* $\to$ *Clinical endoscopic remission*). |
| `PROG_SURV_01` | `PROG_SURV_01_INV` | Five-Year Cancer Survivorship State | `Condition -> Condition` | $\ge 1.50$ | Long-term disease-free interval (e.g., *Stage II colon cancer* $\to$ *5-year disease-free survivor*). |
| `PROG_DEATH_01`| `PROG_DEATH_01_INV`| Terminal Agonal Event Indicator | `Condition -> Condition` | $\ge 1.50$ | Physiological cascade preceding mortality (e.g., *Multi-organ failure* $\to$ *In-hospital cardiac arrest*). |

---

### Class V: Associational & Phenotypic Co-Occurrences (20 Codes / 5 Families)
*Relationships where Concept A and Concept B frequently co-occur due to shared epidemiological risk factors, syndromic clustering, or common pathophysiology without direct uni-directional causation.*

| Code ID | Inverse Code | Canonical Label | Domain Constraint | Expected DR | Clinical Scope |
|---|---|---|---|:---:|---|
| `ASSOC_SYND_01`| `ASSOC_SYND_01_INV`| Metabolic Syndrome Cluster Triad | `Condition -> Condition` | $[0.67, 1.50]$ | Concordant components of insulin resistance (e.g., *Essential hypertension* $\leftrightarrow$ *Hypertriglyceridemia*). |
| `ASSOC_SYND_02`| `ASSOC_SYND_02_INV`| Autoimmune Polyendocrine Syndrome | `Condition -> Condition` | $[0.67, 1.50]$ | Multiple endocrine gland immune attack (e.g., *Hashimoto thyroiditis* $\leftrightarrow$ *Type 1 diabetes*). |
| `ASSOC_SYND_03`| `ASSOC_SYND_03_INV`| Neurocutaneous Phakomatosis Triad | `Condition -> Condition` | $[0.67, 1.50]$ | Shared ectodermal developmental defect (e.g., *Café-au-lait macules* $\leftrightarrow$ *Neurofibromas*). |
| `ASSOC_SYND_04`| `ASSOC_SYND_04_INV`| Atopic March Symptom Cluster | `Condition -> Condition` | $[0.67, 1.50]$ | Allergic triad manifestation (e.g., *Atopic dermatitis* $\leftrightarrow$ *Allergic rhinitis*). |
| `ASSOC_RISK_01`| `ASSOC_RISK_01_INV`| Tobacco Smoke Exposure Morbidity | `Condition -> Condition` | $[0.67, 1.50]$ | Dual diseases driven by chronic smoking (e.g., *COPD* $\leftrightarrow$ *Coronary artery disease*). |
| `ASSOC_RISK_02`| `ASSOC_RISK_02_INV`| Chronic Alcohol Consumption Morbidity | `Condition -> Condition` | $[0.67, 1.50]$ | Dual organs damaged by heavy ethanol use (e.g., *Chronic pancreatitis* $\leftrightarrow$ *Alcoholic cirrhosis*). |
| `ASSOC_RISK_03`| `ASSOC_RISK_03_INV`| Severe Obesity Mechanical Co-Morbidity| `Condition -> Condition` | $[0.67, 1.50]$ | Pathology driven by excess adiposity (e.g., *Obstructive sleep apnea* $\leftrightarrow$ *Bilateral knee osteoarthritis*). |
| `ASSOC_RISK_04`| `ASSOC_RISK_04_INV`| Chronic Renal Vasculopathy Marker | `Condition -> Condition` | $[0.67, 1.50]$ | Shared microvascular end-organ damage (e.g., *Hypertensive nephrosclerosis* $\leftrightarrow$ *Arteriolosclerotic retinopathy*). |
| `ASSOC_ANAT_01`| `ASSOC_ANAT_01_INV`| Contiguous Anatomical Co-Involvement | `Condition -> Condition` | $[0.67, 1.50]$ | Inflammatory spread across neighboring organs (e.g., *Acute sinusitis* $\leftrightarrow$ *Maxillary odontogenic infection*). |
| `ASSOC_ANAT_02`| `ASSOC_ANAT_02_INV`| Shared Vascular Territory Ischemia | `Condition -> Condition` | $[0.67, 1.50]$ | Multi-focal occlusion in same arterial bed (e.g., *Left anterior descending stenosis* $\leftrightarrow$ *Left circumflex disease*). |
| `ASSOC_ANAT_03`| `ASSOC_ANAT_03_INV`| Bilateral Symmetric Arthropathy | `Condition -> Condition` | $[0.67, 1.50]$ | Symmetric joint space narrowing (e.g., *Right knee osteoarthritis* $\leftrightarrow$ *Left knee osteoarthritis*). |
| `ASSOC_EPID_01`| `ASSOC_EPID_01_INV`| Shared Demographic Age Cluster | `Condition -> Condition` | $[0.67, 1.50]$ | Geriatric frailty co-morbidities (e.g., *Senile osteoporosis* $\leftrightarrow$ *Benign prostatic hyperplasia*). |
| `ASSOC_EPID_02`| `ASSOC_EPID_02_INV`| Socioeconomic Deprivation Correlate | `Condition -> Condition` | $[0.67, 1.50]$ | Diseases correlated with social vulnerability (e.g., *Poor glycemic control* $\leftrightarrow$ *Severe depression*). |
| `ASSOC_EPID_03`| `ASSOC_EPID_03_INV`| Seasonal Viral Epidemic Concordance | `Condition -> Condition` | $[0.67, 1.50]$ | Winter viral respiratory infections (e.g., *Influenza A infection* $\leftrightarrow$ *Respiratory syncytial virus*). |
| `ASSOC_UTIL_01`| `ASSOC_UTIL_01_INV`| Hyper-Monitored Inpatient Encounter | `Procedure -> Condition` | $[0.67, 1.50]$ | High testing density during ICU admission (e.g., *Arterial line placement* $\leftrightarrow$ *Continuous venovenous hemofiltration*). |
| `ASSOC_UTIL_02`| `ASSOC_UTIL_02_INV`| Pre-Operative Clearance Evaluation | `Procedure -> Condition` | $\ge 1.50$ | Baseline evaluation before elective surgery (e.g., *Pre-op electrocardiogram* $\to$ *Elective total hip replacement*). |
| `ASSOC_UTIL_03`| `ASSOC_UTIL_03_INV`| Routine Health Maintenance Visit | `Procedure -> Procedure` | $[0.67, 1.50]$ | Bundled preventive outpatient care (e.g., *Annual wellness exam* $\leftrightarrow$ *Routine lipid panel*). |
| `ASSOC_PHENO_01`| `ASSOC_PHENO_01_INV`| Overlapping Clinical Symptom Complex | `Condition -> Condition` | $[0.67, 1.50]$ | Somatization and central sensitization (e.g., *Fibromyalgia* $\leftrightarrow$ *Irritable bowel syndrome*). |
| `ASSOC_PHENO_02`| `ASSOC_PHENO_02_INV`| Secondary Mood Disorder in Pain | `Condition -> Condition` | $\ge 1.50$ | Affective disorder arising from chronic pain (e.g., *Chronic intractable back pain* $\to$ *Major depressive disorder*). |
| `ASSOC_PHENO_03`| `ASSOC_PHENO_03_INV`| Cognitive Impairment in Cerebrovascular| `Condition -> Condition` | $\ge 1.50$ | Microvascular disease with cognitive decline (e.g., *Vascular dementia* $\leftrightarrow$ *Cerebral white matter disease*). |

---

## 3. Directional Precedence Rules & Empirical Lift Alignment

Taxonomy v6.0 explicitly coordinates with the empirical statistical metrics produced by Pipeline v57 (`cab_s55_pair_all`):

```text
                                        TAXIS DIRECTIONALITY SPECTRUM
                Reverse Predominant            Balanced / Indeterminate         Forward Predominant
               (Concept B Precedes A)         (Balanced Precedence Counts)     (Concept A Precedes B)
          ◄─────────────────────────────┼─────────────────────────────┼─────────────────────────────►
                        │                             │                             │
                    DR ≤ 0.67                0.67 < DR < 1.50                   DR ≥ 1.50
                        │                             │                             │
             Intervention evaluated           Diagnostic Biomarkers            Etiologic Insults
             as A=Drug/Proc, B=Condition      Syndromic Clusters               Intermediate Precursors
             where diagnosis precedes rx      Reciprocal Comorbidities         Late Complications
```

### Empirical Directionality & Diagnostic Precedence Rules:
The Directionality Ratio $DR = \frac{N_{A \to B} + 0.5}{N_{B \to A} + 0.5}$ reflects the relative frequency with which the index presentation of Concept A precedes Concept B versus Concept B preceding Concept A.

1. **Forward Predominant ($DR \ge 1.50$, Binomial $p < 0.01$)**:
   - The index recording of Concept A precedes Concept B with at least a 1.5-to-1 ratio.
   - Typically observed in Class I (Causal/Etiologic) and Class IV (Progression/Complication) pairs where exposure or precursor condition A predates manifestation or complication B.
2. **Reverse Predominant ($DR \le 0.67$, Binomial $p < 0.01$)**:
   - The index recording of Concept B precedes Concept A with at least a 1.5-to-1 ratio.
   - In Class III (Therapeutic/Interventional) where canonical relation definitions place Concept A = Treatment (Drug or Procedure) and Concept B = Indication (Condition), the underlying disease diagnosis B typically precedes therapeutic intervention A ($N_{B \to A} > N_{A \to B}$), yielding $DR \le 0.67$.
   - **Reciprocal Evaluation**: When evaluated in reverse orientation (Concept A = Condition, Concept B = Treatment), the active code is the inverse relation (e.g., `THER_FIRST_01_INV`), and the observed ratio reciprocates to $DR' = 1/DR \ge 1.50$.
3. **Balanced / Indeterminate ($0.67 < DR < 1.50$)**:
   - Reflects balanced directional ordering across patient trajectories ($N_{A \to B} \approx N_{B \to A}$).
   - **Important Distinction**: Balanced $DR$ does *not* necessarily imply same-day presentation; same-day occurrences are tracked as an independent count $N_{A=B}$ and excluded from the $DR$ calculation.
   - Common in contemporaneous diagnostic testing (Class II) and reciprocal syndromic clustering (Class V).
4. **Diagnostic Signal vs. Ontological Truth**:
   - Observed recording order in observational health data serves as an empirical **consistency diagnostic** rather than a rigid ontological proof. Administrative coding artifacts, delayed physician documentation, and long-standing chronic recurrences can alter empirical ordering without invalidating clinical relationship semantics.

---

## 4. Integration with OMOP Common Data Model & Circe Phenotyping

When integrated into the TAXIS downstream engines:
1. **Triples Materialization**: Each mined concept pair $(A, B)$ meeting statistical significance gates ($N_{AB} \ge 100$, stratified Lift $> 1.50$, CMH $p < 0.001$, Binomial $p < 0.01$) is evaluated by the two-stage LLM screen-and-code framework to assign candidate relation codes.
2. **Circe Cohort Ingestion & Phenotype Role Mapping**:
   Taxonomy relations map to distinct functional criteria in computable Circe phenotypes based on clinical role rather than broad class-wide exclusions:
   - **Index & Primary Defining Criteria**: Class II (Diagnostic/Indicative) concepts that establish the primary clinical event presentation.
   - **Confirmatory Secondary Criteria**: Class II confirmatory assays (`DIAG_CONF_01`, `DIAG_CONF_02`) and Class III first-line interventions (`THER_FIRST_01`, `THER_PROC_01`) occurring within qualified observation windows (e.g., $[-7, +30]$ days of index event).
   - **Differential Exclusions & Phenotypic Mimics**: Strictly restricted to specific differential diagnosis codes such as `DIAG_DIFF_01` (Phenotypic Mimic Presentation) and `DIAG_DIFF_02` (Biomarker Rule-Out Assay). In accordance with `DEC-GR-008`, rule-out exclusions enforce the configurable 10% anchor mimic-attrition cap to prevent catastrophic cohort shrinkage.
   - **Comorbidities & Disease Progression**: Class IV (Prognostic & Longitudinal Complications) and Class I (Etiologic Insults) represent natural disease progression, downstream outcomes, or upstream common causes. They are **never default exclusions**; they inform baseline risk stratification, covariate balance in comparative designs, or downstream outcome cohorts.
   - **Candidate Negative Controls**: Inverse relation codes provide bidirectional navigation across the knowledge graph ($A \xrightarrow{R} B \iff B \xrightarrow{R^{-1}} A$). They do **not** define candidate negative controls. Negative control generation requires formulating an explicit causal-null hypothesis ($H_0: \text{RR} = 1.0$), reviewing mechanistic and clinical literature to confirm the absence of plausible biological mechanisms, and independent clinical expert adjudication per protocol Section 6. Observational association statistics (e.g., from PHOEBE or INPC mining) serve as descriptive empirical baseline evidence with their source dataset identified, rather than an exclusionary filter, enabling empirical error calibration.

---

## 5. Governance & Data Privacy Safeguards

In compliance with `DEC-GR-005` and `DEC-GR-006`:
- All taxonomy definitions, relation codes, and inclusion/exclusion criteria represent **public biomedical knowledge**.
- No institutional patient identifiers, provider names, or localized data schemas are embedded within the taxonomy.
- The taxonomy is distributed under the open-source **Apache 2.0 license** and Creative Commons Attribution 4.0 International (**CC-BY-4.0**).
