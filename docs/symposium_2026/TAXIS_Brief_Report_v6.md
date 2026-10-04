# TAXIS: An OMOP-Native Clinical Relationship Layer to Support Reusable Phenotype Engineering and Observational Analytics

**Brief Report for the 2026 OHDSI Global Symposium Collaborator Showcase**  
*Showcase Entry #127*  

### Authors
**Stephen H. Bandeian, MD, JD**¹ (Principal Investigator); **Gowtham Rao, MD, PhD**²,³ (Investigator); **Shaun Grannis, MD, MS**⁴,⁵ (Investigator); **J. Marc Overhage, MD, PhD**⁶,⁵ (Co-Principal Investigator)  

¹Johns Hopkins University School of Medicine, Division of Health Sciences Informatics, Department of Medicine, Baltimore, MD, USA  
²CoReason, Inc. USA  
³OHDSI Phenotype Development and Evaluation Workgroup  
⁴Regenstrief Institute, Indianapolis, IN, USA  
⁵Indiana University School of Medicine, Indianapolis, IN, USA  
⁶The Overhage Group, Indianapolis, IN, USA  

---

## 1. Introduction & Background

The Observational Medical Outcomes Partnership (OMOP) Common Data Model (CDM) provides standardized vocabularies that systematically harmonize electronic health record (EHR) and administrative claims data across hundreds of clinical databases worldwide. Within individual clinical domains, these standard vocabularies offer rich hierarchical structures—such as *is-a* relationships in SNOMED-CT for conditions, RxNorm ingredient-to-brand hierarchies for medications, and LOINC class hierarchies for laboratory measurements. 

However, empirical vocabulary investigations demonstrate that standard vocabularies capture **less than 0.5%** of the operational, cross-domain semantic relationships essential for rigorous observational research. Standard vocabularies rarely specify which laboratory measurement serves as confirmatory evidence for a diagnosis, which medication represents guideline-recommended first-line pharmacotherapy, which concurrent syndrome represents a diagnostic rule-out mimic, or which downstream manifestation reflects chronic disease progression.

Consequently, phenotype engineers in observational health research face a severe manual bottleneck. Constructing computable cohort definitions (e.g., in OHDSI ATLAS / Circe) requires investigators to manually curate concept sets and specify complex temporal inclusion rules across distinct clinical domains. This ad-hoc authoring process contributes directly to phenotypic divergence, where multiple research groups studying the same clinical condition implement conflicting logic, compromising study reproducibility and network portability.

To resolve this foundational challenge, we introduce **TAXIS (Transparent Analytic Knowledge Graph for Interoperable Science)**. TAXIS constructs an open-source, empirical clinical relationship layer directly from large-scale observational health records. By integrating distributed association rule mining across 2.16 million longitudinal patient trajectories with Large Language Model (LLM) semantic classification and automated Circe cohort synthesis, TAXIS bridges the gap between observational data and computable, knowledge-grounded phenotyping.

---

## 2. Methods

The TAXIS architecture is structured into four interconnected modules: (1) large-scale observational association mining, (2) dual lift and temporal precedence estimation, (3) clinical knowledge graph construction with two-stage LLM semantic coding, and (4) automated phenotype recreation and federated HADES evaluation.

```text
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                               TAXIS END-TO-END METHODOLOGY                             │
└────────────────────────────────────────────────────────────────────────────────────────┘
                                             │
               ┌─────────────────────────────┴─────────────────────────────┐
               ▼                                                           ▼
    [ MODULE 1: MINING ENGINE ]                                 [ MODULE 2: TAXONOMY & KG ]
    • INPC 2.16M OMOP CDM v5.4                                  • Clinical Pair Taxonomy v6.0
    • 6 Cross-Domain Intersections                              • 112 Standardized Relation Codes
    • ≥365-Day Wash-in & Incident Rule                          • Two-Stage LLM Screen & Code
    • Utilization Decile Stratification                         • Multi-Model Consensus Ensemble
               │                                                           │
               └─────────────────────────────┬─────────────────────────────┘
                                             │
               ┌─────────────────────────────┴─────────────────────────────┐
               ▼                                                           ▼
    [ MODULE 3: PHENOTYPE ENGINE ]                              [ MODULE 4: HADES EVALUATION ]
    • Semantic Anchor Ingestion                                 • TaxisPhenotypeEvaluation Package
    • Knowledge Graph Neighborhood Traversal                    • 2x2 Complementary Cell Suppression
    • Circe JSON Slot Compilation                               • Aggregate Non-PHI Results Export
    • Configurable 10% Mimic Rule-Out Cap                       • Cross-Database Multi-CDM Protocol
```

### 2.1 Large-Scale Observational Association Mining (Pipeline v57)
We executed large-scale concept association mining across 2,160,000 longitudinal patient records in the Indiana Network for Patient Care (INPC) mapped to the OMOP CDM v5.4. We evaluated all pairwise concept co-occurrences across six cross-domain combinations: `Condition–Drug`, `Condition–Measurement`, `Condition–Procedure`, `Condition–Condition`, `Drug–Procedure`, and `Drug–Drug`.

To eliminate acute artifactual co-occurrences and healthcare contact confounding, the mining engine implemented rigorous epidemiological constraints:
- **Baseline Observation Wash-in**: A mandatory continuous observation window of $\ge 365$ days prior to the anchor event to distinguish incident clinical events from chronic pre-existing conditions.
- **Incident Manifestation Rule**: Concept B was required to have zero recorded occurrences during the patient's baseline lookback window, ensuring that associations reflect prospective temporal emergence rather than chronic co-management.
- **Same-Day Tie Handling**: Same-day co-occurrences ($N_{A=B}$) were recorded as independent counts and strictly excluded from directional ordering calculations.

### 2.2 Dual Lift Architecture & Utilization Stratification
In observational healthcare data, patients with high healthcare utilization (e.g., hospitalized patients or multi-morbid elderly individuals) receive disproportionately more diagnoses, laboratory tests, and medications. Simple crude co-occurrence metrics severely conflate true clinical mechanisms with healthcare utilization frequency.

In compliance with project design directive `DEC-GR-010`, TAXIS computes and reports both unadjusted crude lift and healthcare utilization-stratified lift:
- **Crude Lift**: Quantifies overall co-occurrence relative to marginal independence across the entire cohort.
- **Stratified Lift ($Lift_{\text{util}}$)**: Patients are stratified into ten deciles of annualized healthcare contact volume ($U_1, \dots, U_{10}$) measured during the baseline wash-in period. Expected joint co-occurrences are computed within each utilization stratum and aggregated via Cochran-Mantel-Haenszel (CMH) weighting. Lift attenuation (the ratio of crude lift to stratified lift) serves as an empirical diagnostic indicator of contact confounding. Pairs were gated on stratified lift ($Lift_{\text{util}} \ge 1.50$, CMH $p < 0.001$).

### 2.3 Temporal Precedence & Binomial Directionality Testing
To establish empirical temporal ordering between concept pairs $(A, B)$, TAXIS computes a continuity-corrected Directionality Ratio ($DR$):

$$DR = \frac{N_{A \to B} + 0.5}{N_{B \to A} + 0.5}$$

where $N_{A \to B}$ represents the count of patients where Concept A predates Concept B within prospective observation windows ($[+1, +30]$, $[+1, +90]$, $[+1, +365]$, or $[+1, +730]$ days), and $N_{B \to A}$ represents the count of patients where Concept B predates Concept A. Directional asymmetry was formally tested against the binomial null hypothesis of equal temporal probability ($H_0: p = 0.5$) with a significance cutoff of $p < 0.01$. Pairs failing statistical significance remain categorized as balanced or indeterminate ($0.67 < DR < 1.50$).

### 2.4 Clinical Knowledge Graph & Two-Stage LLM Semantic Taxonomy
Pairs meeting statistical significance criteria ($N_{AB} \ge 100$, $Lift_{\text{util}} \ge 1.50$, CMH $p < 0.001$, Binomial $p < 0.01$) were processed by the **Clinical Pair Taxonomy v6.0**. The taxonomy establishes **112 standardized relation codes** organized into **32 relation families** across **5 broad clinical classes**:
1. **Class I: Causal & Etiologic** (24 codes): Infectious agents, toxic exposures, and primary metabolic triggers ($DR \ge 1.50$).
2. **Class II: Diagnostic & Indicative** (22 codes): Pathognomonic laboratory assays, abnormal imaging findings, and physical exam indicators ($0.67 < DR < 1.50$).
3. **Class III: Therapeutic & Interventional** (26 codes): Guideline-recommended first-line pharmacotherapies, surgical procedures, and rescue interventions (canonical $DR \le 0.67$ where Concept A is treatment and Concept B is indication; reciprocal $DR' \ge 1.50$).
4. **Class IV: Prognostic & Disease Evolution** (20 codes): Chronic progression stages, fibrotic remodeling, acute exacerbations, and late-stage complications ($DR \ge 1.50$).
5. **Class V: Associational & Phenotypic** (20 codes): Syndromic clusters, shared-risk comorbidities, and reciprocal disease associations ($0.67 < DR < 1.50$).

Semantic relationship assignment was executed using a **Two-Stage Screen-and-Code LLM Framework**:
- **Stage 1 (Coarse Screen)**: Evaluates the concept pair, clinical definitions, and observational metrics to select one of the five primary functional classes.
- **Stage 2 (Fine-Grained Code Assignment)**: Assigns the precise relation code from the selected class catalog, accompanied by an explicit clinical justification.
- **Consensus & Adjudication**: Enforces multi-model consensus across independent runs (measuring inter-annotator agreement via Fleiss' Kappa, requiring $\kappa \ge 0.85$) with supervisory adjudication for divergent classifications.

### 2.5 Automated Phenotype Recreation Engine (`build_1032.py`)
To demonstrate translational utility, TAXIS compiles knowledge graph subgraphs directly into executable OHDSI Circe JSON cohort definitions using structured semantic anchors:
- **Index Criteria**: Seed condition standard concepts supplemented with Class II diagnostic indicators. In accordance with `DEC-GR-007`, public baseline definitions implement `PrimaryCriteriaLimit: First` to ensure reproducible cohort entry.
- **Confirmatory Criteria**: Class II confirmatory assays and Class III first-line therapies within $[-7, +30]$ days of index presentation.
- **Differential Rule-Out Exclusions**: Strictly mapped from differential diagnosis codes (`DIAG_DIFF_01`, `DIAG_DIFF_02`). In accordance with `DEC-GR-008`, rule-out exclusions implement a configurable **10% anchor patient attrition cap**, ensuring that competing diagnostic exclusions do not cause unintended cohort attrition.

### 2.6 Multi-Tier Data Governance & HADES Evaluation Package
To resolve data-sharing barriers across federated networks, TAXIS enforces an **Aggregate-Only Non-PHI Policy** (`DEC-GR-005`):
- **Tier 1 (Local Mining)**: Data partners execute Concept AB mining and patient-level co-occurrence analysis entirely within their local firewall.
- **Tier 2 (Aggregate Export)**: The deployable HADES study package `TaxisPhenotypeEvaluation` evaluates cohort overlap (Jaccard index, sensitivity, agreement) and PheValuator diagnostic operating characteristics (Sensitivity, Specificity, PPV, NPV, F1 Score with 95% CIs). All exported metrics implement **mathematical $2 \times 2$ complementary cell suppression**: whenever any cell in the cohort overlap partition contains $0 < N < 5$, all interior partition cells and derived ratios are masked to $-1$, completely preventing algebraic reconstruction of small patient counts.

---

## 3. Results & Empirical Evidence Register

In accordance with rigorous evidence accounting standards, TAXIS explicitly separates three distinct evidence categories: (1) clinical relevance and semantic concordance panels, (2) empirical cohort agreement across 2.16M INPC patients, and (3) prospective federated multi-CDM evaluation.

| Evidence Category | Analytical Target | Denominator / Dataset | Comparator / Standard | Empirical Metric | Status |
|---|---|---|---|---|:---:|
| **Semantic Edge Relevance (EVID-01)** | Edge existence classification | 1,000 clinically curated pairs | ClinVec Physician Panel Ratings | **AUC 0.81** (95% CI: 0.79–0.83) | Completed |
| **Temporal Precedence (EVID-02)** | Directional chronology ($DR$) | 100 PACES guideline pairs | Clinical Practice Guidelines | **99.0%** Directional Concordance | Completed |
| **Blinded Physician Review (EVID-03)** | 112-code taxonomy typing | 291 sampled INPC pairs | Dual Internist Review (Overhage & Grannis) | **88.3%** broad group ($\kappa=0.84$); **58.1%** exact code ($\kappa=0.54$) | Completed |
| **Empirical Cohort Overlap: T2DM (EVID-04)** | Recreated Circe phenotype | INPC 2.16M CDM ($|A \cup B| = 143,528$) | OHDSI Phenotype Library Cohort #1032 | **99.5%** Jaccard Overlap ($142,810 / 143,528$); **99.8%** Sensitivity | Completed |
| **Empirical Cohort Overlap: CKD (EVID-04)** | Recreated Circe phenotype | INPC 2.16M CDM ($|A \cup B| = 70,383$) | OHDSI Phenotype Library Cohort #1191 | **97.2%** Jaccard Overlap ($68,412 / 70,383$); **98.6%** Sensitivity | Completed |
| **Empirical Cohort Overlap: COPD (EVID-04)** | Recreated Circe phenotype | INPC 2.16M CDM ($|A \cup B| = 52,042$) | OHDSI Phenotype Library Cohort #1263 | **98.4%** Jaccard Overlap ($51,209 / 52,042$); **98.9%** Sensitivity | Completed |
| **Multi-CDM Network Evaluation** | Cross-database portability | CCAE, MDCR, MDCD, Optum EHR, CPRD | Hand-crafted Library definitions & PheValuator | Sensitivity, Specificity, PPV, NPV, F1 | Prospective (JnJ) |

```text
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                    EMPIRICAL INPC COHORT OVERLAP CONCORDANCE (JACCARD)                 │
└────────────────────────────────────────────────────────────────────────────────────────┘
  100% ┼───────────────────────────────────────────────────────────────────────────────┐
       │   █████████                     █████████                     █████████       │
   90% ┼───█████████─────────────────────█████████─────────────────────█████████───────┤
       │   █████████                     █████████                     █████████       │
   80% ┼───█████████─────────────────────█████████─────────────────────█████████───────┤
       │   █████████                     █████████                     █████████       │
   70% ┼───█████████─────────────────────█████████─────────────────────█████████───────┤
       │     T2DM (99.5%)                  CKD (97.2%)                   COPD (98.4%)  │
       └───────────────────────────────────────────────────────────────────────────────┘
```

### 3.1 Association Mining Scale & Confounder Pruning
Across 2.16M longitudinal INPC patient records, the mining engine evaluated over 3.2 million candidate concept pairs. Application of the $\ge 365$-day observation wash-in and incident manifestation rule eliminated 44.8% of co-occurrences that represented prevalent chronic co-management. Healthcare utilization decile stratification attenuated lift by an average of 42.1% across high-utilizer deciles, successfully filtering out encounter-frequency artifacts. A final catalog of over 52,000 high-confidence clinical relationship edges met all statistical gates.

### 3.2 Automated Phenotype Recreation Concordance
On the Indiana Network for Patient Care (INPC) OMOP CDM v5.4 (2.16M patients, 11.3M person-years), phenotypes compiled by `build_1032.py` achieved high concordance with official OHDSI Phenotype Library definitions, matching canonical IDs in `inst/settings/PhenotypePairs.csv`:
- **Type 2 Diabetes Mellitus** (Anchor Concept ID: 201826, TAXIS Cohort ID: `1798326` vs. OPL Cohort 1032): Mined first-line pharmacotherapies (Metformin, Sulfonylureas) and diagnostic labs (HbA1c $\ge 6.5\%$) reproduced the OHDSI definition with a Jaccard index of **99.5%** ($142,810 / 143,528$) and sensitivity of **99.8%**.
- **Chronic Kidney Disease (Stage 3+)** (Anchor Concept ID: 46271022, TAXIS Cohort ID: `1798324` vs. OPL Cohort 1191): Incorporation of staged eGFR lab thresholds and albuminuria indicators achieved a Jaccard index of **97.2%** ($68,412 / 70,383$) and sensitivity of **98.6%**.
- **Chronic Obstructive Pulmonary Disease** (Anchor Concept ID: 255573, TAXIS Cohort ID: `1798322` vs. OPL Cohort 1263): Inclusion of spirometry indicators and bronchodilator rescue therapies achieved a Jaccard index of **98.4%** ($51,209 / 52,042$) and sensitivity of **98.9%**.
Across all three evaluation targets, automated Circe phenotype synthesis achieves $> 97\%$ Jaccard overlap (0.972 to 0.995).

---

## 4. Discussion & Ecosystem Integration

### 4.1 Synergy with OHDSI Phenotype Library 3.0
TAXIS directly addresses the core operational priorities established for the **OHDSI Phenotype Library Version 3.0**. By providing an algorithmic generator grounded in empirical data associations, TAXIS transforms the library from a static repository into an active phenotyping lifecycle. candidate phenotypes generated by TAXIS can be systematically ingested into the library, where automated redundancy testing (via Jaccard overlap matrices) and longitudinal concept drift monitoring can be performed autonomously.

### 4.2 Integration with PHOEBE 2.0 Concept Recommendation
TAXIS creates an essential bridge between semantic relationship knowledge and real-world vocabulary utilization. By interfacing with **PHOEBE 2.0** network concept prevalence data, TAXIS ensures that concept sets compiled into Circe expressions prioritize concepts with observed empirical frequency across diverse network databases, preventing omission of clinically relevant lexical variants.

### 4.3 Autonomous Phenotyping Agents & Expression Optimization
TAXIS establishes a knowledge backend for emerging autonomous agent frameworks in the OHDSI community:
- **Dynamic Knowledge Provider for `PhenotypingAgent`**: In LangGraph state machines (such as `schuemie/PhenotypingAgent`), TAXIS acts as a Model Context Protocol (MCP) server providing structured clinical mechanisms during error-profile sampling and iterative logic refinement.
- **Syntactic Minimization via `ConceptSetCondenser`**: Pairing TAXIS's substantive clinical association discovery with Martijn Schuemie's `ConceptSetCondenser` enables set-covering optimization that produces minimal, human-auditable Circe expressions without altering patient cohort membership.

### 4.4 Causal Inference & Pearlian DAG Covariate Selection
Beyond phenotyping, the TAXIS clinical relationship layer supports rigorous causal study design. By distinguishing primary etiologies (Class I) and intermediate complications (Class IV) from diagnostic indicators (Class II) and symptomatic treatments (Class III), TAXIS assists epidemiologists in identifying true baseline confounders while preventing conditioning on post-baseline intermediate mediators or collider variables.

---

## 5. Conclusions

TAXIS demonstrates that an OMOP-native, computable clinical relationship layer can be derived directly from longitudinal observational healthcare data. By integrating large-scale association mining, healthcare utilization decile stratification, the 112-code Clinical Pair Taxonomy v6.0, and automated Circe cohort compilation, TAXIS eliminates manual curation bottlenecks while preserving high diagnostic fidelity. The complete open-source suite—including the mining SQL engine, taxonomy specifications, phenotype builder, and HADES evaluation package—provides foundational infrastructure for knowledge-driven observational analytics across the global OHDSI research network.

---

## 6. References

1. **Shoaibi A, Ostropolets A, Weaver J, Rao G, et al.** Variation in phenotype definitions in observational clinical research: a review of three conditions. *AMIA Annu Symp Proc*. 2024.
2. **Shoaibi A, Ostropolets A, Murphy JD, Rao GA, et al.** Clinical Descriptions as Semantic Anchors: A Best Practice in OHDSI Phenotype Development. *OHDSI Phenotype Development and Evaluation Workgroup Consensus Statement*; 2025.
3. **Rao GA, et al.** Neuro-Symbolic Conceptual Workflows for Phenotyping in Observational Research: The Proposer-Validator Architecture. *OHDSI Phenotype Development and Evaluation Workgroup*; 2026.
4. **Bandeian SH, Tompkins CP, Davison A.** A Future Health Care Analytic System: Part 1—What the Destination Looks Like & Part 2—Building Blocks and Implementation Roadmap. In: *Healthcare Information Management Systems*. 5th ed. Springer; 2022.
5. **Ostropolets A, et al.** PHOEBE 2.0: selecting the right concept sets for the right patients using lexical, semantic, and data-driven recommendations. *OHDSI Symposium*; 2022. Available from: https://www.ohdsi.org/wp-content/uploads/2022/10/6-Ostropolets_Phoebe2.0-abstract.pdf
6. **Schuemie MJ, et al.** Automated Phenotype Definition Optimization Using Large Language Model Agents and Concept Set Condensation. *OHDSI Global Symposium Proceedings*; 2025.
