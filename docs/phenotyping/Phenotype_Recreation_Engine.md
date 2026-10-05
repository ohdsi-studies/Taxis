# Proof-of-Concept Applications of TAXIS
## Demonstrating How the Empirical Relationship Layer Can Inform Downstream Phenotyping and Negative Controls

> **Document Type**: Proof-of-Concept Technical Specification  
> **Study Leadership**:  
> • Stephen H. Bandeian, MD, JD – Principal Investigator, [Johns Hopkins University School of Medicine](https://www.hopkinsmedicine.org) (Original SQL & Analytic Code Author)  
> • J. Marc Overhage, MD, PhD – Co-Principal Investigator, The Overhage Group / [Indiana University School of Medicine](https://medicine.iu.edu)  
> • Gowtham Rao, MD, PhD – Investigator, [CoReason, Inc.](https://www.coreason.ai) USA; OHDSI Phenotype Development & Evaluation Workgroup Lead  
> • Shaun Grannis, MD, MS – Investigator, [Regenstrief Institute](https://www.regenstrief.org) / [Indiana University School of Medicine](https://medicine.iu.edu)  

---

## 1. Architectural Scope: TAXIS as an Empirical Foundation

This document defines the architectural boundaries and translational applications of the TAXIS empirical layer. **TAXIS is an empirical association mining engine and an OHDSI network study execution package; it is not an end-user cohort algorithm builder or negative control selector application.** TAXIS establishes the underlying empirical data foundation upon which translational informatics applications may be engineered.

The primary objective of the TAXIS initiative is the development, release, maintenance, and multi-site execution of an OHDSI network study across federated OMOP Common Data Model databases. This network study executes large-scale empirical concept association mining to compute comprehensive concept A–B pair summaries—including observed co-occurrence counts, temporal sequence directionality, and crude and stratified lift metrics. These computed summaries will be disseminated as an open, public scientific resource for observational health research.

Within this repository, we demonstrate proof-of-concept workflows illustrating how downstream informatics tools may leverage these empirical pair summaries for computable phenotype definition and methodological study design.

---

## 2. Neuro-Symbolic Phenotyping Architecture: Integrating Clinical Intent with Empirical Evidence

Computable phenotype engineering requires translating high-level clinical definitions and diagnostic guidelines into executable observational study criteria. While automated large language models and heuristic methods can propose candidate synonyms, symptomatic presentations, and diagnostic markers, ungrounded generative models are prone to hallucinating non-standard terminology and proposing clinical relationships that lack empirical support in observational health databases.

```text
┌────────────────────────────────────────────────────────────────────────────────────────┐
│             PROOF-OF-CONCEPT: BRIDGING CLINICAL INTENT TO CIRCE LOGIC                  │
└────────────────────────────────────────────────────────────────────────────────────────┘
                    [ 1. Clinical Description ]
                    Clinical intent, symptoms, diagnostic tests, treatments, mimics
                                          │
                                          ▼
                    [ 2. Empirical Grounding (TAXIS) ]
                    Query computed concept pair summaries and directionality metrics
                                          │
                                          ▼
                    [ 3. Circe Expression Synthesis ]
                    Proof-of-concept compilation into standard OHDSI Circe JSON:
                    • Primary Event Criteria (Index Condition)
                    • Confirmatory Labs (Measurement [-7, +30] days)
                    • Indicated Drugs (Drug Exposure Criteria)
                    • Rule-Out Exclusions (Occurrence = 0 Mimics)
                                          │
                                          ▼
                    [ 4. Evaluation via HADES Tools ]
                    Run CohortDiagnostics and PheValuator across network CDMs
```

Our proof-of-concept architecture bridges clinical intent with empirical observational evidence through a two-phase protocol:
1. **The Clinical Proposer Phase**: Evaluates a structured clinical description to identify candidate clinical concepts—including presenting symptoms, confirmatory diagnostic assays, first-line therapeutics, and differential diagnostic mimics.
2. **Empirical Verification & Circe Compilation**: Queries TAXIS concept-pair summaries to evaluate which proposed clinical associations empirically co-occur in longitudinal patient data, verifies temporal sequence and directionality, and compiles verified criteria into standard OHDSI Circe JSON cohort definitions.

---

## 3. Decomposing Clinical Logic into Six Functional Building Blocks

Rather than structuring phenotypes as monolithic, unstratified concept sets, the proof-of-concept compiler decomposes clinical logic into six standardized functional slots aligned with the clinical diagnostic lifecycle:

- **Bucket 1: Primary Index Criteria (`PrimaryCriteria.CriteriaList`)**: The core condition of interest defining the initial qualifying incident event, requiring $\ge 365$ days of prior continuous observation to establish baseline disease-free status.
- **Bucket 2: Clinical Presentation & Prodrome (`InclusionRules[1]`)**: Presenting complaints, physical signs, and prodromal symptoms evaluated within the peri-index window ($[-7, +1]$ days).
- **Bucket 3: Confirmatory Diagnostic Biomarkers & Procedures (`InclusionRules[2]`)**: Objective laboratory measurements and diagnostic imaging modalities ordered during acute diagnostic workup ($[-1, +3]$ days) to confirm clinical diagnosis.
- **Bucket 4: Disease-Specific Therapeutics (`InclusionRules[3]`)**: Pharmacotherapies and procedural interventions initiated upon diagnostic confirmation ($[0, +2]$ days). Because disease-specific therapeutics are rarely administered for negative rule-out evaluations, this slot provides the highest discriminatory power against false positives.
- **Bucket 5: Clinical Sequelae & Disease Progression (`InclusionRules[4]`)**: Secondary complications and downstream organ dysfunction manifesting during extended follow-up ($[+1, +30]$ days).
- **Bucket 6: Differential Diagnoses & Rule-Out Mimics (`CensoringCriteria`)**: Competing clinical conditions sharing symptomatic features that warrant explicit rule-out exclusion logic.

### Multi-Tiered Cohort Stratification
Observational research questions necessitate distinct optimizations between phenotypic sensitivity and specificity. The proof-of-concept compiler demonstrates the synthesis of three coordinated cohort tiers for a single target phenotype:
- **Tier 1 (Strict / High Specificity)**: Enforces the primary diagnosis alongside confirmatory laboratory findings and mandatory disease-specific therapeutics. Designed for active-comparator comparative safety and effectiveness studies where misclassification error must be minimized.
- **Tier 2 (Broad / High Sensitivity)**: Captures incident presentations across inpatient and outpatient care settings with corroborating diagnostic evaluations, omitting mandatory invasive procedures to avoid excluding conservatively managed patients.
- **Tier 3 (Diagnostic Evaluator Cohorts)**: Generates paired `xSpec` (extremely high specificity) and `xSens` (extremely high sensitivity) cohorts to train regularized predictive models within `PheValuator`.

---

## 4. Empirical Negative Control Discovery

The identification of valid negative control outcomes represents a foundational requirement for empirical calibration and residual systematic error quantification in observational epidemiology. Valid negative controls require outcome concepts exhibiting genuine biological and clinical independence from the exposure of interest.

While TAXIS does not incorporate an interactive selection tool, its empirical association matrix provides the necessary quantitative substrate for negative control discovery:
1. **Clinical Independence**: Investigators can query the relationship layer for concept pairs exhibiting zero documented clinical connections across the 112-code taxonomy.
2. **Preservation of Confounding by Health-Seeking Behavior**: Candidate negative controls are selected based on clinical and biological independence rather than filtering strictly on observed statistical nulls. Valid negative controls that exhibit modest non-zero associations due to healthcare contact frequency or health-seeking behavior are valuable—they enable calibration algorithms to estimate and adjust for residual systematic bias across the network.

---

## 5. Integration with OHDSI Community Ecosystem

Downstream informatics systems utilizing the public TAXIS concept-pair datasets integrate directly with established OHDSI analytical packages:
- **OHDSI Phenotype Library**: Candidate cohort definitions generated through empirical workflows can be submitted to the Phenotype Library for peer review, versioned archiving, and community dissemination.
- **PHOEBE**: Vocabulary recommendations from PHOEBE can be paired with TAXIS empirical co-occurrences to expand concept sets with commonly used institutional codes while pruning obsolete concepts.
- **CohortDiagnostics & PheValuator**: Cohort definitions informed by TAXIS data can be evaluated across network partner databases using standardized OHDSI diagnostic tools to assess incidence stability, cohort overlap, and operating characteristics.

---

## 6. Open-Source Licensing & Governance

All architecture specifications, Circe JSON schemas, and demonstration scripts in this repository are licensed under the **Apache 2.0 license**, and documentation is provided under Creative Commons Attribution 4.0 International (**CC-BY-4.0**). All outputs and test datasets contain zero patient-level data or protected health information.
