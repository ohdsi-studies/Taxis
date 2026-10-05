# TAXIS Network Study: Call for Collaborators

> **Study Title**: Transparent Analytic Knowledge Graph for Interoperable Science (TAXIS)  
> **Collaborator Showcase Entry**: #127 (2026 OHDSI Global Symposium, October 20–22, 2026, New Brunswick, NJ)  
> **Study Leadership**:  
> • **Stephen H. Bandeian, MD, JD** – Principal Investigator, [Johns Hopkins University School of Medicine](https://www.hopkinsmedicine.org)  
> • **J. Marc Overhage, MD, PhD** – Co-Principal Investigator, The Overhage Group / [Indiana University School of Medicine](https://medicine.iu.edu)  
> • **Gowtham Rao, MD, PhD** – Investigator, [CoReason, Inc.](https://www.coreason.ai) USA; OHDSI Phenotype Development & Evaluation Workgroup  
> • **Shaun Grannis, MD, MS** – Investigator, [Regenstrief Institute](https://www.regenstrief.org) / [Indiana University School of Medicine](https://medicine.iu.edu)  
> **Decision Code Reference**: `DEC-GR-057` (Two-Track Collaborator Invitation Architecture)

---

## 1. Overview & Invitation

The **TAXIS network study** invites international OHDSI collaborators across two distinct, complementary participation pathways launching simultaneously:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                          TAXIS NETWORK COLLABORATION PATHWAYS                          │
└───────────────────────────────────────────┬────────────────────────────────────────────┘
                                            │
               ┌────────────────────────────┴────────────────────────────┐
               ▼                                                         ▼
┌───────────────────────────────────────────┐ ┌───────────────────────────────────────────┐
│     TRACK A: KNOWLEDGE GRAPH CONTRIBUTORS │ │     TRACK B: APPLICATION VALIDATORS       │
│     (Data Partners with OMOP CDMs)        │ │     (Data Sites & Clinical Experts)       │
├───────────────────────────────────────────┤ ├───────────────────────────────────────────┤
│ • Run association mining on local CDM     │ │ • Sub-track B1: Phenotype Validation      │
│ • Choice: Full mining OR Targeted mining  │ │   (CohortDiagnostics & PheValuator)       │
│ • Expand knowledge graph beyond Indiana   │ │ • Sub-track B2: Negative Control Testing  │
│ • Tiered data sharing (Open vs DUA)       │ │   (Empirical error calibration)           │
│ • Backends: PostgreSQL, SQL Server,       │ │ • Sub-track B3: Clinical Adjudication     │
│   Snowflake                               │ │   (Blinded review, no database needed)    │
└───────────────────────────────────────────┘ └───────────────────────────────────────────┘
```

Whether you are an institutional data partner holding an OMOP CDM v5.4 database or a clinician/methodologist interested in evaluating candidate phenotypes and negative controls, TAXIS provides a clear, structured pathway for participation.

---

## 2. Track A: Knowledge Graph Contributors

### 2.1 Scientific Purpose
To date, the TAXIS clinical knowledge graph has been mined from a single large-scale healthcare system—the Indiana Network for Patient Care (INPC), encompassing 2.16 million longitudinal patients and 11.3 million person-years. 

**Track A collaborators will execute TAXIS association rule mining on their local OMOP CDMs**, allowing the network to evaluate cross-site consistency, measure between-database heterogeneity, and build an open, multi-site clinical knowledge graph.

### 2.2 Execution Scope Options
Participating Track A data partners may choose between two execution tiers based on local computational capacity:

1. **Full-Database Association Mining (Comprehensive)**:
   * Executes the full 40-batch Pipeline v57 mining engine across all six cross-domain intersections (`Condition–Drug`, `Condition–Measurement`, `Condition–Procedure`, `Condition–Condition`, `Drug–Procedure`, and `Drug–Drug`).
   * Computes pair-level co-occurrences, temporal directionality ratios ($DR$), unadjusted lift, and healthcare utilization-stratified lift across 10 deciles of contact frequency.
2. **Targeted Condition-of-Interest Mining (Focused)**:
   * Executes association mining focused specifically on participating sites' disease areas of interest or selected clinical phenotypes.
   * Significantly reduces computational footprint while contributing multi-site evidence for target clinical domains.

### 2.3 Technical Requirements & Standardization
* **Common Data Model**: OMOP CDM v5.4 (or v5.3 with standard vocabulary mappings).
* **Database Platforms Supported**: **PostgreSQL**, **Microsoft SQL Server**, and **Snowflake** (verified via HADES `SqlRender` and `DatabaseConnector`).
* **Standardized Temporal Parameters** (for multi-site meta-analytic comparability):
  * *Wash-in Period*: Mandatory $\ge 365$ days of prior continuous observation.
  * *Prospective Follow-up Window*: Configurable parameter `win_w` with standardized primary default of **182 days** ($[+1, +182]$ days).
  * *Same-Day Tie Handling*: Same-day events ($N_{A=B}$, Day 0) recorded separately and excluded from temporal directionality ratios.
  * *Minimum Support Threshold*: $N_{AB} \ge 100$ (configurable for smaller datasets).

### 2.4 Tiered Data Sharing Model
Track A operates under a **two-tiered governance model** designed to protect institutional data privacy:

| Sharing Tier | Artifact Exported | Privacy Safeguards | Sharing Mechanism |
|---|---|---|---|
| **Tier 1: Open Network Deliverables** | Standard study archive (`Results_<databaseId>.zip`) containing 6 summary tables | Mandatory small-cell masking ($<5 \to -1$) with companion-field suppression; zero patient-level data | Open community sharing (GitHub, OHDSI network results repository) |
| **Tier 2: Central Consortium Synthesis** | Unmasked or threshold-filtered concept-pair co-occurrence matrix (`cab_s55_pair_all`) | Aggregate concept-level pairs only; zero PHI, zero person IDs, zero dates | Transmitted to central coordinating center under formal Consortium Data Use Agreement (DUA) |

---

## 3. Track B: Application Validators

Track B invites collaborators to empirically evaluate downstream translational applications and audit the clinical veracity of the TAXIS knowledge graph. 

Grounded in the **Six-Point Empirical Validation Framework**, Track B establishes a structured, multi-dimensional protocol to answer the central scientific question: *"Did the algorithm get it right?"*
1. **Candidate Set Efficiency & Threshold Sensitivity**: Evaluating whether association screening ($N_{AB} \ge 100, \text{Lift}_{\text{strat}} \ge 1.50$) filters billions of pairs into a tractable review set without dropping benchmark edges.
2. **Formal Comparison Against Curated Sources**: Measuring edge recovery against established clinical resources (PheKB, ClinVec, OHDSI Phenotype Library).
3. **Expected-Pair Recovery & Missingness Audit**: Auditing sensitivity and systematically diagnosing why any expected clinical relationship was missed.
4. **Adjudication Validity Yield**: Evaluating the distribution of valid, invalid, and uncertain edges across the 112 taxonomy codes.
5. **Statistical Evidence vs. Clinical Concordance**: Confirming that clinically validated edges exhibit significantly stronger empirical support (higher lift, odds ratios, and consistent directionality).
6. **Focused Discordant-Edge Error Taxonomy**: Analyzing high-information edge cases (e.g., coding artifacts, threshold cutoffs, or novel clinical practices).

Track B features three distinct sub-tracks:

### 3.1 Sub-track B1: Phenotype Evaluation Across Partner CDMs
* **Execution Vehicle**: The standalone HADES companion package [`TaxisPhenotypeEvaluation`](../../extras/TaxisPhenotypeEvaluation/README.md).
* **Target Benchmark Phenotypes**:
  1. *Type 2 Diabetes Mellitus* (T2DM: TAXIS `1798326` vs. OPL `1032`)
  2. *Chronic Kidney Disease Stage 3+* (CKD: TAXIS `1798324` vs. OPL `1191`)
  3. *Chronic Obstructive Pulmonary Disease* (COPD: TAXIS `1798325` vs. OPL `1263`)
  4. *Acute Myocardial Infarction* (AMI: TAXIS `1798322` vs. OPL `1033`)
  5. *Major Depressive Disorder* (MDD: TAXIS `1798323` vs. OPL `1034`)
* **Methodology**:
  * **Cohort Overlap**: Evaluates patient-level intersection-over-union (Jaccard similarity index) comparing TAXIS auto-generated Circe phenotypes against gold-standard OHDSI Phenotype Library definitions.
  * **Diagnostic Operating Characteristics**: Executes `PheValuator` semi-automated evaluation (*Swerdel et al., 2019*) estimating Sensitivity, Specificity, PPV, NPV, and F1 Score with 95% confidence intervals without manual chart review.
  * **Cohort Diagnostics**: Executes `CohortDiagnostics` to characterize incidence rates, index event breakdowns, and orphan concepts.

### 3.2 Sub-track B2: Negative Control Outcome Calibration
* **Scientific Focus**: Observational comparative effectiveness studies require negative control outcomes to estimate and calibrate residual systematic error (confounding, selection bias, measurement error).
* **Methodology**:
  * Query the TAXIS clinical knowledge graph for concept pairs exhibiting an absence of pathophysiologic, etiologic, or therapeutic mechanisms across all 112 taxonomy codes.
  * Generate candidate negative control sets for independent clinical and literature review.
  * Execute OHDSI `EmpiricalCalibration` on participating partner CDMs to measure whether TAXIS-derived negative control batteries generate empirical null distributions that successfully calibrate systematic error.

### 3.3 Sub-track B3: Clinical Expert Adjudication (No Database Access Required)
* **Target Audience**: Board-certified clinicians, epidemiologists, informaticians, and medical terminologists who do not have direct access to an OMOP CDM database.
* **Activities**:
  * **Blinded Pair Review**: Review randomly sampled concept pairs to evaluate clinical plausibility and validate the 112-code Clinical Pair Taxonomy.
  * **Clinical Description Authoring**: Author standardized Clinical Descriptions (presentation, confirmatory labs, first-line treatments, diagnostic mimics) to serve as semantic anchors for phenotype generation.
  * **Exclusionary Mimic Review**: Clinically evaluate candidate rule-out mimics to ensure phenotypic specificity without exceeding the pre-execution 10% anchor patient exclusion threshold.

---

## 4. Academic Authorship & Consortium Governance

To recognize the substantial contributions of participating researchers while maintaining high scientific standards, TAXIS establishes a **multi-tiered authorship model** (`DEC-GR-057`):

```
┌────────────────────────────────────────────────────────────────────────┐
│                   TAXIS ACADEMIC ATTRIBUTION MODEL                     │
├────────────────────────────────────────────────────────────────────────┤
│ • Lead Study Authors & Co-PIs: Primary scientific manuscript leads     │
│ • Named Co-Authorship (ICMJE): Lead analysts and investigators from    │
│   active Track A data sites and active Track B validation sites        │
│ • Consortium Authorship: Execution team members, clinical adjudicators,│
│   and site coordinators recognized under the TAXIS Study Group banner  │
└────────────────────────────────────────────────────────────────────────┘
```

1. **Named Co-Authorship**: Participating data partner PIs and lead analysts from Track A (contributing mining results) and Track B (executing phenotype/negative control evaluations) who fulfill ICMJE criteria will receive named co-authorship on primary network publications and symposium manuscripts.
2. **Consortium Authorship**: Local data extraction analysts, software engineers, and clinical adjudicators will be recognized as consortium authors under the **TAXIS Study Group** banner in PubMed/MEDLINE indexable formats.
3. **Data Ownership**: Participating institutions retain 100% ownership and control over their local data assets.

---

## 5. Participation Matrix & Getting Started

| Collaborator Type | Primary Track | Required Prerequisites | Primary Deliverable |
|---|:---:|---|---|
| **EHR / Claims Data Partner** | **Track A** | OMOP CDM v5.4, R execution environment, DatabaseConnector | `Results_<databaseId>.zip` (and central pair matrix under DUA) |
| **Phenotyping Research Site** | **Track B1** | OMOP CDM v5.4, HADES packages (`CohortDiagnostics`, `PheValuator`) | `Results_<databaseId>.zip` containing overlap & performance metrics |
| **Causal Inference Methodologist** | **Track B2** | R environment, HADES `EmpiricalCalibration` | Empirical null distributions and calibration error profiles |
| **Clinician / Clinical Informatician** | **Track B3** | Web browser, medical domain expertise | Blinded adjudication scores, semantic descriptions |

### How to Join
1. **GitHub Repository**: [https://github.com/ohdsi-studies/Taxis](https://github.com/ohdsi-studies/Taxis)
2. **Contact Study Leadership**: Reach out to Dr. Stephen H. Bandeian (PI), Dr. J. Marc Overhage (Co-PI), or Dr. Gowtham Rao (Investigator).
3. **Network Study Call**: Attend the dedicated TAXIS network study kickoff session at the upcoming OHDSI Phenotype Development & Evaluation Workgroup meeting and the 2026 Global Symposium Collaborator Showcase.
