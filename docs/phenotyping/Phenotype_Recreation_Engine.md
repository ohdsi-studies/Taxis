# TAXIS Automated Phenotype Recreation Engine
## Neuro-Symbolic Proposer-Validator Architecture, Clinical Description Anchor Mapping & Circe Synthesis Specifications

> **Document Type**: Scientific Architecture & Engineering Specification  
> **Target Release**: Wave 7 (`wave/07-phenotype-recreation-engine`)  
> **Epistemic Foundation**: OHDSI Phenotype Development and Evaluation Workgroup Consensus Standards  
> **Authoritative Decisions**:  
> • `DEC-GR-005`: Aggregate-Only Non-PHI Policy (all synthesized cohort logic is open-source and non-PHI)  
> • `DEC-GR-006`: Target Federated CDM Deployments (Claims, EHR, International CDMs)  
> • `DEC-GR-010`: Dual Lift Reporting Architecture  
> **Study Leadership**:  
> • Stephen H. Bandeian, MD, JD – Principal Investigator, Johns Hopkins University School of Medicine  
> • J. Marc Overhage, MD, PhD – Co-Principal Investigator, The Overhage Group / Indiana University School of Medicine  
> • Gowtham Rao, MD, PhD – Investigator, CoReason, Inc. USA; OHDSI (Phenotype working group)  
> • Shaun Grannis, MD, MS – Investigator, Regenstrief Institute / Indiana University School of Medicine  

---

## 1. Executive Summary & Translational Rationale

In observational health research, cohort definition authoring has historically been an artisan, manual, study-by-study craft. Systematic evaluations of published observational literature have revealed severe methodological heterogeneity: independent investigator teams studying the identical target clinical condition often produce algorithms yielding up to a **tenfold difference in cohort size**, with divergent index event definitions and uncalibrated exclusion rules (*Shoaibi, Ostropolets, Weaver, Rao, et al., AMIA 2024*).

The **TAXIS Automated Phenotype Recreation Engine** addresses this reproducibility crisis by automating the translation of structured clinical intent into formal, computable OHDSI Circe JSON cohort definitions.

By coupling empirical associations mined across **2.16 million longitudinal patients** (Pipeline v57) with the **112-relation Clinical Pair Taxonomy v6.0**, the engine synthesizes multi-domain cohort criteria—integrating presentation conditions, confirmatory laboratory measurements, first-line pharmacotherapies, and rule-out exclusions—directly into reproducible Circe cohort expressions.

```text
┌────────────────────────────────────────────────────────────────────────────────────────┐
│             TAXIS AUTOMATED PHENOTYPE RECREATION ENGINE: WORKFLOW ARCHITECTURE         │
└────────────────────────────────────────────────────────────────────────────────────────┘
                    [ 1. SEMANTIC ANCHOR: CLINICAL DESCRIPTION ]
                     OHDSI Phenotype Workgroup Standard Schema
                     (Overview, Presentations, Labs, Meds, Exclusions)
                                         │
                                         ▼
                    [ 2. NEURAL PROPOSER: KG SUBGRAPH TRAVERSAL ]
                     Traverses 112 Taxonomy Codes & Empirical Lift Matrix
                     Extracts Candidate Multi-Domain Clinical Associations
                                         │
                                         ▼
                    [ 3. SYMBOLIC COMPILER: CIRCE JSON SYNTHESIZER ]
                     Deterministic Slot-Mapping into Computable Logic Blocks:
                     • Primary Event Criteria (Index Condition)
                     • Confirmatory Labs (Measurement [-7, +30] days)
                     • Indicated Drugs (Drug Exposure Criteria)
                     • Rule-Out Exclusions (Occurrence = 0 Mimics)
                                         │
                                         ▼
                    [ 4. EMPIRICAL VALIDATOR: HADES EVALUATION SUITE ]
                     Multi-Site Benchmark Execution:
                     • CohortDiagnostics (Prevalence, Overlap, Jaccard)
                     • PheValuator (Diagnostic Sensitivity, Specificity, PPV, NPV, F1)
```

---

## 2. Neuro-Symbolic Proposer-Validator Framework

Drawing upon cognitive architecture foundations (Kahneman System 1 vs. System 2) formalized for observational health informatics (*Rao et al., 2026*), TAXIS implements a **Neuro-Symbolic Proposer-Validator Framework**:

1. **Neural / Associative Proposer (System 1)**:
   - Traverses empirical co-occurrences mined across 2.16M longitudinal patients in the INPC OMOP CDM paired with the two-stage screen-and-code LLM ensemble (Taxonomy v6.0).
   - Generates candidate multi-domain clinical associations (identifying relevant lab tests, treatments, and complications), mitigating ungrounded hallucinations through empirical data grounding.
2. **Symbolic Structural Compiler & Validator (System 2)**:
   - Operates deterministically via formal AST compilers (`synthesize_circe_cohort.py`), mapping proposed clinical concepts into syntactically valid OHDSI Circe JSON schemas.
   - Evaluates diagnostic performance and clinical validity through empirical execution across network Common Data Models using HADES packages (`CohortDiagnostics` and `PheValuator`).

---

## 3. Deterministic Slot-Mapping Specification

The engine ingests the standardized OHDSI Phenotype Development & Evaluation Workgroup clinical description schema (`clinicalDescriptionPromptBriefWithExclusions.txt`) and executes deterministic 1-to-1 slot mapping:

### Slot 1: Primary Index Criteria (`PrimaryCriteria.CriteriaList`)
- **Clinical Anchor Source**: *Condition Overview & Acute/Chronic Presentation*.
- **Circe Construction**:
  - `ConditionOccurrence` criteria block.
  - Standard SNOMED condition concept set expression (including descendants).
  - Observation window requirement: $\ge 365$ days prior continuous observation (`PriorDays = 365`, `PostDays = 0`).
  - First-in-history restriction (`First = true`) or recurrent episode parameterization.

### Slot 2: Confirmatory Diagnostic Criteria (`InclusionRules[1]`)
- **Clinical Anchor Source**: *Diagnostic Criteria, Cardinal Physical Signs & Laboratory Values*.
- **Taxonomy Family**: `Class II: Diagnostic & Indicative` (`DIAG_CONF_01`, `DIAG_MARK_01`, `DIAG_MARK_03`).
- **Circe Construction**:
  - `Measurement` criteria block.
  - Standard LOINC test concept set expression.
  - Temporal relative window: $[-7, +30]$ days relative to index event.
  - Value thresholds: `Operator: ">="` or `"<="` mapped to guideline cutoffs (e.g., $HbA1c \ge 6.5\%$ for Type 2 Diabetes; $eGFR < 60\text{ mL/min}/1.73\text{m}^2$ for CKD).

### Slot 3: Indicated Pharmacotherapy Criteria (`InclusionRules[2]`)
- **Clinical Anchor Source**: *Medications Usually Given & First-Line Therapies*.
- **Taxonomy Family**: `Class III: Therapeutic & Interventional` (`THER_FIRST_01`, `THER_FIRST_02`, `THER_MAINT_01`).
- **Circe Construction**:
  - `DrugExposure` criteria block.
  - RxNorm ingredient concept set expression (with dose-form and ingredient grouping).
  - Temporal relative window: $[0, +30]$ days for acute disease; $[0, +180]$ days for chronic maintenance.
  - Occurrence count: $\ge 1$ prescription/dispensing event.

### Slot 4: Differential Diagnoses & Rule-Out Exclusions (`InclusionRules[3]`)
- **Clinical Anchor Source**: *Differential Diagnoses & Excluded Conditions*.
- **Taxonomy Family**: `Class I / II / V` (`DIAG_DIFF_01`, `ASSOC_PHENO_01`).
- **Circe Construction**:
  - Negative condition criteria (`Occurrence: {"Type": 0, "Count": 0}`).
  - Standard concept set expression of clinical mimics (e.g., *Type 1 diabetes* and *Gestational diabetes* excluded when defining Type 2 diabetes).
  - Lookback window: all time prior to index presentation ($[- \infty, 0]$ days).
  - **Prevalence Cost Cap**: Exclusions are capped to eliminate clinical mimics without excessively restricting target populations (strictly $<10\%$ anchor cohort patient reduction).

---

## 4. Candidate Negative Control Generation Engine

A critical challenge in observational causal inference is the synthesis of valid **negative control outcome cohorts** to detect and quantify network systematic error (*VanderWeele, 2015; Shoaibi et al., 2024*).

The TAXIS Phenotype Recreation Engine automates negative control generation:
1. **Clinical Independence Traversal**: The engine queries the relationship layer for concept pairs $(A, B)$ that exhibit **zero documented relationships** across all 112 taxonomy codes in the TAXIS Knowledge Graph.
2. **Preserving Residual Confounding**:
   - Crucially, candidate selection is driven by **substantive clinical and literature review** (establishing causal independence) rather than conditioning on observed statistical nulls.
   - Baseline observational metrics (such as lift and directionality in a given dataset) are retained strictly as descriptive diagnostics.
   - Valid negative controls that exhibit non-null observed associations due to health-seeking behavior, contact density, or residual confounding are **intentionally preserved**, allowing empirical calibration batteries to detect and adjust for network systematic bias.

---

## 5. Integration with OHDSI Phenotype Library 3.0 & PHOEBE

Following the 2026 symposium demonstration, the engine connects into the broader OHDSI analytics ecosystem:
1. **OHDSI Phenotype Library Version 3.0 (Autonomous Governance)**:
   - Synthesized Circe definitions are submitted directly into the automated intake pipeline of Phenotype Library 3.0 (*Rao, 2026*).
   - The engine supports automated metadata annotation, schema standardization, and documentation completeness scoring.
   - Variant mapping compares synthesized phenotypes against existing library cohorts (concept set Jaccard and logic flow comparisons) to identify novel phenotypes vs. targeted refinements.
2. **PHOEBE 2.0 Network Prevalence Integration**:
   - Integrates empirical concept prevalence and lexical recommendations from **PHOEBE** (*Ostropolets et al., 2022*).
   - Balances substantive clinical semantics (confirmatory labs, indicated medications) with network-wide frequency data to prioritize frequently used concept codes while avoiding obsolete terms.
3. **CohortDiagnostics & PheValuator Evaluation Lifecycle**:
   - Every synthesized cohort is evaluated using `CohortDiagnostics` (cohort count, incidence rate, cohort overlap Jaccard) and `PheValuator` (*Swerdel et al., 2019*) for empirical diagnostic sensitivity, specificity, positive predictive value, negative predictive value, and F1 score estimation across network partner CDMs.

---

## 6. Open-Source Licensing & Data Governance

All architecture specifications, Circe JSON schemas, and synthesis scripts are licensed under the **Apache 2.0 license** and Creative Commons Attribution 4.0 International (**CC-BY-4.0**).
Zero patient-level data, personal health information, or proprietary table definitions are embedded within this framework.
