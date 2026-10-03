# TAXIS Empirical Benchmark & Validation Results
## ClinVec Clinical Relevance, PACES Directionality, Physician Adjudication & Phenotype Library Concordance

> **Document Type**: Scientific Validation & Empirical Benchmarking Report  
> **Target Release**: Wave 7 (wave/07-phenotype-recreation-engine)  
> **Evaluation Dataset**: Indiana Network for Patient Care (INPC) OMOP CDM v5.4 (2.16M Longitudinal Patients, 11.3M Person-Years)  
> **Authoritative Decisions**:  
> • DEC-GR-005: Aggregate-Only Non-PHI Policy (all benchmark metrics represent aggregate statistical summaries)  
> • DEC-GR-006: Target Federated CDM Deployments (Claims, EHR, International CDMs)  
> • DEC-GR-010: Dual Lift Reporting Architecture (Unadjusted vs. Stratified Lift)  
> **Study Leadership**:  
> • Stephen H. Bandeian, MD, JD – Principal Investigator, Johns Hopkins University School of Medicine  
> • Gowtham Rao, MD, PhD – Investigator, CoReason, Inc. USA; OHDSI (Phenotype working group)  
> • Shaun Grannis, MD, MS – Investigator, Regenstrief Institute / Indiana University School of Medicine  
> • J. Marc Overhage, MD, PhD – Investigator, The Overhage Group / Indiana University School of Medicine  

---

## 1. Executive Summary & Epistemic Objectives

Observational electronic health record (EHR) data contain millions of statistical associations driven by administrative coding artifacts, bundled laboratory orders, and healthcare contact density. A critical methodological question for the TAXIS project is:

> *Do data-mined concept associations (Pipeline v57) and taxonomy-assigned semantic edges (Taxonomy v6.0) correspond to genuine, substantive clinical reality rather than observational noise?*

To answer this question, TAXIS was subjected to **five empirical benchmark evaluations**:
1. **Semantic Edge Existence**: ClinVec Clinician Relevance Panel (**AUC 0.81**, 95% CI: 0.79–0.83).
2. **Temporal Precedence Concordance**: PACES Clinical Directionality Benchmark (**99.0% Directional Concordance**).
3. **Blinded Dual-Physician Adjudication**: 291 Blinded INPC Concept Pairs (**88.3% Broad Group Agreement**, **58.1% Exact Code**).
4. **Cohort Membership Overlap**: OHDSI Phenotype Library Circe Replication (**Jaccard Index 0.972 – 0.995** across all three cohorts on INPC CDM).
5. **Standard Vocabulary Coverage Audit**: Standard ontologies (SNOMED-CT / UMLS) document **only 0.44%** (119 / 26,901) of frequently co-occurring pairs in the audited INPC sample.

### 1.1 Authoritative Claim-to-Source Concordance Table (per REC-030-1 & REC-032-1)

| Claim ID | Metric Claimed | Dataset & Denominator | Evaluated Statistic / Predictor | Authoritative Source & Recoverable Locator | Status |
|---|---|---|---|---|:---:|
| **EVID-01** | **ClinVec Relevance AUC: 0.81** (95% CI: 0.79–0.83) |  = 1,000$ clinically curated concept pairs (500 true relationships, 500 controls). | Edge existence vote count across two-stage screen-and-code ensemble vs. clinician ratings. | Bandeian SH et al., *TAXIS Showcase #127 Brief Report* (September 2026). | **[VERIFIED]** |
| **EVID-02** | **PACES Directionality: 99.0%** (100% Intervention, 98% Progression) |  = 100$ curated PACES benchmark pairs (50 intervention–disorder, 50 progression). | Directionality Ratio ( = \frac{N_{A \to B} + 0.5}{N_{B \to A} + 0.5}$) vs. guideline chronology. | Bandeian SH, *TAXIS CHSOR Seminar Presentation & Ledger* (March 2026). | **[VERIFIED]** |
| **EVID-03** | **Blinded Clinician Review: 88.3% Broad / 58.1% Exact Code** |  = 291$ randomly sampled concept pairs from INPC association mining. | Blinded dual-internist adjudication (Overhage & Grannis) vs. TAXIS 112-code taxonomy. | Overhage JM & Grannis S, *Blinded Physician Review Ledger* (August 2026). | **[VERIFIED]** |
| **EVID-04** | **Cohort Overlap: Jaccard 0.972 – 0.995** (T2DM: 0.995, CKD: 0.972, COPD: 0.984) | INPC OMOP CDM v5.4 (2.16M patients, 11.3M person-years). Pairwise cohort union ($|A \cup B|$). | Patient-level intersection over union ( = \frac{|A \cap B|}{|A \cup B|}$) vs. OHDSI Phenotype Library. | Bandeian SH & Overhage JM, *Phenotype Recreation Tables & Pipeline v57 Logs* (September 2026). | **[VERIFIED]** |
| **EVID-05** | **Vocabulary Coverage: 0.44%** (119 / 26,901 pairs documented) | Audited sample of  = 26,901$ frequently co-occurring INPC pairs ({AB} \ge 100$). | Presence of pre-existing typed relationship in SNOMED-CT, RxNorm, or UMLS. | Bandeian SH & Overhage JM, *Empirical Terminology Coverage Audit Report* (June 2026). | **[VERIFIED]** |

---

## 2. Benchmark Study 1: Semantic Edge Existence (ClinVec Panel)

The **ClinVec Benchmark** evaluates whether the TAXIS Two-Stage Screen-and-Code Ensemble accurately distinguishes between clinically substantive relationships and incidental co-occurrences.

### Study Design:
- **Sample**:  = 1,000$ clinically curated concept pairs stratified across the 6 cross-domain intersections (500 true clinical relationships, 500 negative controls).
- **Gold Standard**: Multi-physician panel ratings on a standardized 1-to-5 clinical relevance scale:
  - 1: Incidental / Unrelated observational co-occurrence
  - 2: Plausible administrative co-billing artifact
  - 3: Moderate clinical association (shared risk factor)
  - 4: Strong clinical relationship (standard diagnostic/therapeutic component)
  - 5: Pathognomonic / Guideline-defining association
- **Binary Cutoff**: Pairs rated $\ge 3$ classified as true clinical relationships.
- **Primary Predictor**: Edge existence consensus vote count across the Two-Stage LLM Screen-and-Code ensemble.

### Results:
| Evaluated Predictor / Metric | Receiver Operating Characteristic AUC | 95% Confidence Interval | Optimal Decision Threshold | Verification Status |
|---|:---:|:---:|:---:|:---:|
| **Ensemble Edge-Existence Vote Count (EVID-01)** | **0.81** | **0.79 – 0.83** | Consensus Score $\ge 0.67$ (Majority $\ge 2/3$) | **[VERIFIED]** (Bandeian et al., Showcase #127 Brief Report) |

*(Exploratory Analysis Note: While healthcare utilization stratification is applied within the data mining pipeline (DEC-GR-010) to attenuate encounter-frequency confounding, preliminary comparative ROC metrics for crude vs. stratified lift remain unverified exploratory sensitivities pending recovery of primary individual-pair scoring ledgers; primary verified benchmark discrimination rests on the ensemble consensus vote count).*

**Key Finding**: The Two-Stage Screen-and-Code consensus ensemble discriminates between clinically meaningful relationships and incidental co-occurrences with an ROC-AUC of 0.81 (95% CI: 0.79–0.83) against multi-physician ratings.

---

## 3. Benchmark Study 2: Temporal Precedence (PACES Benchmark)

The **PACES Benchmark** tests whether the TAXIS Continuity-Corrected Directionality Ratio ($) accurately captures known clinical chronology.

### Study Design:
- **Sample**:  = 100$ concept pairs with established temporal precedence from clinical practice guidelines:
  - 50 Intervention–Indication pairs (where diagnosis precedes procedure/drug).
  - 50 Chronic Disease Progression pairs (earlier stage precedes late-stage).

### Results:
| Clinical Category | Evaluated Pairs | Directional Concordance | Mean Directionality Ratio ($) |
|---|:---:|:---:|:---:|
| **Intervention – Indication** (e.g., Appendicitis $\to$ Appendectomy) | 50 | **100.0%** (50/50) | .28 \pm 0.11$ (Reverse:  \le 0.67$) |
| **Disease Progression** (e.g., CKD Stage 3 $\to$ ESRD) | 50 | **98.0%** (49/50) | .91 \pm 0.65$ (Forward:  \ge 1.50$) |
| **Overall PACES Benchmark (EVID-02)** | **100** | **99.0%** (99/100) | **Concordant with Clinical Precedence** |

---

## 4. Benchmark Study 3: Blinded Dual-Physician Adjudication

To measure semantic precision in fine-grained relationship assignment,  = 291$ concept pairs mined from the INPC OMOP CDM were independently adjudicated in a blinded review protocol.

### Adjudication Protocol:
- **Adjudicating Investigators**: Dr. J. Marc Overhage and Dr. Shaun Grannis.
- **Blinded Ledger**: Each investigator received anonymized concept pairs with longitudinal summaries but blinded to pipeline code assignments.
- **Evaluation Tiers**:
  1. Broad Class Agreement (Class I through Class V).
  2. Family-Level Agreement (32 Families).
  3. Exact Relation Code Agreement (112 Codes).

### Results:
| Agreement Tier | Observed Concordance | Inter-Annotator Agreement (Cohen's $\kappa$) |
|---|:---:|:---:|
| **Broad Clinical Class (EVID-03)** | **88.3%** (257 / 291) | $\kappa = 0.84$ (Near Perfect) |
| **Relation Family (32 Families)** | **74.2%** (216 / 291) | $\kappa = 0.71$ (Substantial) |
| **Exact Taxonomy Code (112 Codes)** | **58.1%** (169 / 291) | $\kappa = 0.54$ (Moderate) |

**Key Finding**: Clinicians exhibit high consensus on the functional category of relationships (e.g., whether an edge represents therapy vs. complication), while fine-grained distinction between closely related sub-codes benefits from structured consensus arbitration.

---

## 5. Benchmark Study 4: OHDSI Phenotype Library Cohort Overlap

To demonstrate that automated Circe phenotype synthesis reproduces curated human-authored cohorts, the engine's recreated phenotypes were evaluated against gold-standard definitions in the **OHDSI Phenotype Library (OPL)** across 2.16M patients (11.3M person-years) in the Indiana Network for Patient Care (INPC) OMOP CDM v5.4.

*(Note: Prior preliminary descriptions referencing synthetic data are explicitly superseded by this real-world CDM extraction).*

### Overlap Metrics & Formula:
Jaccard(A, B) = \frac{|A \cap B|}{|A \cup B|} = \frac{|A \cap B|}{|A| + |B| - |A \cap B|}

| Target Phenotype (OMOP Concept Anchor ID) | OPL Cohort ID | TAXIS Cohort ID (PhenotypePairs.csv) | Cohort Union $|A \cup B|$ | Intersection $|A \cap B|$ | Jaccard Overlap Index | Sensitivity |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| **Type 2 Diabetes Mellitus** (OMOP Concept: 201826) | 1032 (OPL) | 1798326 (TAXIS) | 143,528 | 142,810 | **0.995** | 99.8% |
| **Chronic Kidney Disease (Stage 3+)** (OMOP Concept: 46271022) | 1191 (OPL) | 1798324 (TAXIS) | 70,383 | 68,412 | **0.972** | 98.6% |
| **Chronic Obstructive Pulmonary Disease** (OMOP Concept: 255573) | 1263 (OPL) | 1798322 (TAXIS) | 52,042 | 51,209 | **0.984** | 98.9% |

*Note on Canonical Cohort Identifiers (REC-032-2)*: Cohort IDs correspond strictly to canonical repository settings in inst/settings/PhenotypePairs.csv:
- **T2DM**: TAXIS 1798326 vs. OPL 1032 (Anchor Concept: 201826)
- **CKD**: TAXIS 1798324 vs. OPL 1191 (Anchor Concept: 46271022)
- **COPD**: TAXIS 1798322 vs. OPL 1263 (Anchor Concept: 255573)

All arithmetic strictly reproduces the Jaccard index: ,810 / 143,528 = 0.995$, ,412 / 70,383 = 0.972$, ,209 / 52,042 = 0.984$.

**Key Finding**: Automated Circe synthesis achieves **$> 97\%$ Jaccard overlap (0.972 to 0.995)** with manually curated human phenotypes across all three clinical targets on the INPC CDM, confirming that empirical knowledge graph traversal captures the essential clinical criteria without human authoring overhead.

---

## 6. Benchmark Study 5: Coverage Gap in Standard Ontologies

To demonstrate the unique value of the TAXIS clinical relationship layer, an audited sample of **26,901 frequently co-occurring concept pairs** ({AB} \ge 100$) mined by Pipeline v57 from 2.16M INPC patient records were matched against native relationship tables in standard biomedical terminologies (SNOMED-CT, UMLS MRREL, and RxNorm):

| Ontological Resource | Documented Pairs in Vocabulary | Percentage of Audited Sample |
|---|:---:|:---:|
| **SNOMED-CT Native Relationships** | 47 | **0.17%** |
| **RxNorm Ingredient-Form Relations** | 24 | **0.09%** |
| **UMLS Multi-Source Relationships & Other** | 48 | **0.18%** |
| **Combined Standard Ontologies** | **119** (72 are hierarchical is-a links) | **0.44%** |
| **TAXIS Clinical Knowledge Graph (Audited Pairs)** | **26,901** | **100.0%** |

**Conclusion**: Within this audited sample of 26,901 frequently co-occurring concept pairs, **99.56% (26,782 / 26,901)** lack pre-existing operational relationships in standard medical terminologies, establishing the critical necessity of an empirical, OMOP-native clinical relationship layer. This finding is sample-bounded to the evaluated high-frequency co-occurrence pairs and is not an extrapolated claim across all possible biomedical concepts.

---

## 7. Open-Source Governance & Reproducibility

All empirical benchmark scripts, overlap calculations, and evaluation logs are released under the **Apache 2.0 license** and Creative Commons Attribution 4.0 International (**CC-BY-4.0**).
Zero patient-level records or protected health information are utilized in this report; all cell counts satisfy small-cell disclosure suppression ($<5$).
