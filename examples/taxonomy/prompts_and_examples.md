# TAXIS Neuro-Symbolic LLM Semantic Classification Framework
## Two-Stage Screen-and-Code Prompts, Clinical Anchor Schemas & Exemplar Classifications

> **Document Type**: Machine Learning Architecture & Prompt Engineering Specification  
> **Target Release**: Wave 6 (`wave/06-clinical-kg-taxonomy`)  
> **Companion Document**: [`docs/knowledge_graph/Clinical_Pair_Taxonomy_6.md`](../../docs/knowledge_graph/Clinical_Pair_Taxonomy_6.md)  
> **Source Empirical Data**: Concept AB Association Mining Pipeline v57 (2.16M Longitudinal Patients in INPC OMOP CDM)  
> **Study Leadership**:  
> • Stephen H. Bandeian, MD, JD – Principal Investigator, Johns Hopkins University School of Medicine  
> • Gowtham Rao, MD, PhD – Investigator, CoReason, Inc. USA; OHDSI (Phenotype working group)  
> • Shaun Grannis, MD, MS – Investigator, Regenstrief Institute / Indiana University School of Medicine  
> • J. Marc Overhage, MD, PhD – Investigator, The Overhage Group / Indiana University School of Medicine  

---

## 1. Executive Summary & Architectural Overview

Statistical co-occurrence mining across electronic health records (EHR) identifies high-confidence, non-random concept pairs ($N_{AB} \ge 100$, stratified Lift $> 1.50$, $p < 0.001$). However, numerical association metrics cannot inherently distinguish whether a drug treats a disease, causes a complication, or serves as a diagnostic challenge agent.

The **TAXIS Neuro-Symbolic LLM Classification Framework** solves this semantic disambiguation challenge through a structured **two-stage screen-and-code pipeline** combined with **multi-agent consensus arbitration**:

```text
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        TAXIS TWO-STAGE SCREEN-AND-CODE ARCHITECTURE                    │
└────────────────────────────────────────────────────────────────────────────────────────┘
                   Mined Concept Pair from Pipeline v57
                   (Concept A, Concept B, Lift, DR, Hazard Ratios)
                                    │
                                    ▼
       ┌──────────────────────────────────────────────────────────┐
       │   STAGE 1: BROAD CLINICAL CLASS SCREENING (High Recall)   │
       │   Anchored by OHDSI Clinical Descriptions                │
       └────────────────────────────┬─────────────────────────────┘
                                    │
                  Assigned Class (e.g., Class III: Therapeutic)
                                    │
                                    ▼
       ┌──────────────────────────────────────────────────────────┐
       │   STAGE 2: PRECISE RELATION CODE ASSIGNMENT (Precision)  │
       │   Evaluated against Family Inclusion / Exclusion Rules   │
       └────────────────────────────┬─────────────────────────────┘
                                    │
                     Assigned Code (e.g., THER_FIRST_01)
                                    │
                                    ▼
       ┌──────────────────────────────────────────────────────────┐
       │   MULTI-AGENT CONSENSUS ARBITRATION                      │
       │   3 Independent Model Runs + Tiebreaker Judge (κ > 0.85) │
       └────────────────────────────┬─────────────────────────────┘
                                    │
                                    ▼
                    Final Semantic Knowledge Graph Triple
```

---

## 2. Harmonization with OHDSI Phenotype Working Group Standards

In accordance with OHDSI Phenotype Development & Evaluation Workgroup consensus practices:
1. **Clinical Descriptions as Semantic Anchors** (*Shoaibi et al., 2025*): Each concept pair evaluation begins by grounding both concepts in clinical descriptions defining:
   - Overview & Pathophysiology
   - Diagnostic Criteria & Cardinal Signs
   - Standard Clinical Presentation
   - Differential Diagnoses & Exclusions
2. **Proposer-Validator Architecture** (*Rao et al., 2026*): The LLM prompt acts as the semantic *Proposer*, while deterministic data-mined metrics (lift $> 1.50$, directionality ratio $DR$) act as the empirical *Validator*. If an LLM proposes a causal relation (`ETIOL_CAUS_01`), but empirical $DR < 1.50$, the pair is flagged for supervisory adjudication.

---

## 3. Stage 1 Prompt: Broad Clinical Class Screening

```markdown
SYSTEM PROMPT:
You are an expert clinical informatician and physician reasoning over the OHDSI Common Data Model (CDM v5.4).
Your task is to classify the clinical relationship between Concept A and Concept B into one of 5 broad clinical classes, or determine that no clinical association exists.

INPUT DATA:
- Concept A: {concept_a_name} (Domain: {domain_a}, Concept ID: {concept_a_id})
- Concept B: {concept_b_name} (Domain: {domain_b}, Concept ID: {concept_b_id})
- Unadjusted Person Lift: {person_lift_unadj}
- Healthcare Utilization Stratified Lift: {person_lift_strat}
- Continuity-Corrected Directionality Ratio (DR): {directionality_ratio}
- Same-Day Co-occurrence Count: {same_day_count}

CLINICAL CLASSES:
- CLASS_I: Causal & Etiologic (Concept A causes, precipitates, or acts as an etiologic agent for Concept B)
- CLASS_II: Diagnostic & Indicative (Concept A acts as a diagnostic biomarker, test, sign, or monitor for Concept B)
- CLASS_III: Therapeutic & Interventional (Concept A treats, palliates, or intervenes for Concept B, or is contraindicated)
- CLASS_IV: Prognostic & Evolutionary (Concept A evolves, progresses, flares, or leads to sequelae in Concept B)
- CLASS_V: Associational & Phenotypic (Concepts co-occur due to syndromic clustering or shared risk factors without direct causation)
- NO_CLINICAL_ASSOCIATION: Co-occurrence is an administrative artifact, contact-density bias, or spurious data artifact.

OUTPUT FORMAT:
Respond with a strict JSON object:
{
  "selected_class": "CLASS_I" | "CLASS_II" | "CLASS_III" | "CLASS_IV" | "CLASS_V" | "NO_CLINICAL_ASSOCIATION",
  "confidence_score": 0.0 to 1.0,
  "clinical_rationale": "Concise medical explanation justifying why this pair belongs to the selected class."
}
```

---

## 4. Stage 2 Prompt: Precision Relation Code Assignment

```markdown
SYSTEM PROMPT:
You are an expert medical ontologist. Given that Concept A and Concept B belong to {selected_class}, select the single most precise relation code from the TAXIS Clinical Pair Taxonomy v6.0.

CANDIDATE CODES FOR {selected_class}:
{candidate_relation_codes_and_definitions}

INPUT DATA:
- Concept A: {concept_a_name} ({domain_a})
- Concept B: {concept_b_name} ({domain_b})
- Stratified Lift: {person_lift_strat}
- Directionality Ratio: {directionality_ratio}

EVALUATION RULES:
1. Adhere strictly to the Inclusion and Exclusion criteria for each candidate code.
2. Confirm that the empirical Directionality Ratio matches expected boundaries:
   - Forward Predominant (DR >= 1.50)
   - Reverse Predominant (DR <= 0.67)
   - Symmetric / Contemporaneous (0.67 < DR < 1.50)
3. If criteria for multiple codes are met, select the more specific clinical subtype over a generic parent.

OUTPUT FORMAT:
Respond with a strict JSON object:
{
  "relation_code": "EXACT_CODE_ID",
  "inverse_code": "EXACT_INVERSE_CODE_ID",
  "directionality_concordance": true | false,
  "precision_score": 0.0 to 1.0,
  "differential_exclusion_notes": "Why other candidate codes in this family were excluded."
}
```

---

## 5. Multi-Agent Consensus Arbitration Protocol

To guarantee reproducibility and eliminate stochastic hallucinations:
1. **Triplicate Execution**: Every candidate pair is evaluated by 3 independent model runs (with temperature settings $T = 0.0$, $T = 0.2$, $T = 0.4$).
2. **Unanimous (3/3) or Majority (2/3) Consensus**: The modal relation code is accepted directly if confidence $\ge 0.80$.
3. **Split Decision (1/1/1)**: Triggers an autonomous Supervisory Judge persona that inspects the 3 rationales, checks empirical $DR$, and renders a binding determination or marks the edge as `AMBIGUOUS_CLINICAL_PAIR`.
4. **Inter-Annotator Concordance**: System tracks Fleiss' Kappa across batches; production runs require $\kappa \ge 0.85$.

---

## 6. Exemplar Classifications Across 6 Cross-Domain Intersections

### Exemplar 1: `Condition -> Drug` (Therapeutic First-Line)
- **Concept A**: Type 2 diabetes mellitus (Concept ID: `201826`)
- **Concept B**: Metformin (Concept ID: `1503297`)
- **Pipeline v57 Metrics**: Stratified Lift = $4.82$, $DR = 0.31$ (Reverse: Diagnosis precedes drug), $p < 10^{-15}$.
- **Stage 1 Assignment**: `CLASS_III` (Therapeutic & Interventional).
- **Stage 2 Assignment**:
  - `relation_code`: `THER_FIRST_01` (First-Line Guideline Pharmacotherapy).
  - `inverse_code`: `THER_FIRST_01_INV`.
  - `directionality_concordance`: `true` ($DR = 0.31 \le 0.67$).
  - `clinical_rationale`: Metformin is the primary guideline-recommended first-line pharmacotherapy for glycemic management in Type 2 Diabetes.

### Exemplar 2: `Measurement -> Condition` (Diagnostic Confirmatory)
- **Concept A**: Measurement of Troponin I (Concept ID: `3013682`, Result: Abnormal High)
- **Concept B**: Acute myocardial infarction (Concept ID: `312327`)
- **Pipeline v57 Metrics**: Stratified Lift = $14.6$, $DR = 1.08$ (Contemporaneous), $p < 10^{-20}$.
- **Stage 1 Assignment**: `CLASS_II` (Diagnostic & Indicative).
- **Stage 2 Assignment**:
  - `relation_code`: `DIAG_CONF_01` (Pathognomonic Confirmatory Lab).
  - `inverse_code`: `DIAG_CONF_01_INV`.
  - `directionality_concordance`: `true` ($0.67 < DR < 1.50$).
  - `clinical_rationale`: Serum cardiac troponin elevation directly confirms myocardial injury defining acute myocardial infarction.

### Exemplar 3: `Condition -> Condition` (Causal Etiology)
- **Concept A**: Streptococcal pharyngitis (Concept ID: `28060`)
- **Concept B**: Acute post-streptococcal glomerulonephritis (Concept ID: `197925`)
- **Pipeline v57 Metrics**: Stratified Lift = $8.40$, $DR = 3.42$ (Forward: Pharyngitis precedes nephritis by 10-21 days), $p < 10^{-10}$.
- **Stage 1 Assignment**: `CLASS_I` (Causal & Etiologic).
- **Stage 2 Assignment**:
  - `relation_code`: `ETIOL_CAUS_01` (Primary Infectious Etiology).
  - `inverse_code`: `ETIOL_CAUS_01_INV`.
  - `directionality_concordance`: `true` ($DR = 3.42 \ge 1.50$).
  - `clinical_rationale`: Immune-mediated post-infectious nephropathy specifically triggered by antecedent Group A Streptococcus throat infection.

### Exemplar 4: `Procedure -> Condition` (Therapeutic Resection)
- **Concept A**: Laparoscopic appendectomy (Concept ID: `4016484`)
- **Concept B**: Acute appendicitis (Concept ID: `197930`)
- **Pipeline v57 Metrics**: Stratified Lift = $28.3$, $DR = 0.52$ (Reverse: Diagnosis triggers surgery), $p < 10^{-25}$.
- **Stage 1 Assignment**: `CLASS_III` (Therapeutic & Interventional).
- **Stage 2 Assignment**:
  - `relation_code`: `THER_SURG_01` (Definitive Curative Organ Resection).
  - `inverse_code`: `THER_SURG_01_INV`.
  - `directionality_concordance`: `true` ($DR = 0.52 \le 0.67$).
  - `clinical_rationale`: Surgical resection of the inflamed appendix is the definitive curative interventional treatment for acute appendicitis.

### Exemplar 5: `Condition -> Condition` (Prognostic Progression)
- **Concept A**: Chronic kidney disease stage 3 (Concept ID: `443611`)
- **Concept B**: End-stage renal disease (Concept ID: `193782`)
- **Pipeline v57 Metrics**: Stratified Lift = $6.21$, $DR = 2.85$ (Forward: CKD3 precedes ESRD by years), $p < 10^{-18}$.
- **Stage 1 Assignment**: `CLASS_IV` (Prognostic & Disease Evolution).
- **Stage 2 Assignment**:
  - `relation_code`: `PROG_PROG_01` (Chronic Disease Progression Stage).
  - `inverse_code`: `PROG_PROG_01_INV`.
  - `directionality_concordance`: `true` ($DR = 2.85 \ge 1.50$).
  - `clinical_rationale`: Stage 3 chronic kidney disease represents an earlier intermediate functional state that chronologically progresses to terminal renal failure.

### Exemplar 6: `Condition -> Condition` (Syndromic Co-Occurrence)
- **Concept A**: Essential hypertension (Concept ID: `320128`)
- **Concept B**: Hypertriglyceridemia (Concept ID: `432867`)
- **Pipeline v57 Metrics**: Stratified Lift = $2.44$, $DR = 1.02$ (Symmetric: Concurrent chronic presentation), $p < 10^{-12}$.
- **Stage 1 Assignment**: `CLASS_V` (Associational & Phenotypic).
- **Stage 2 Assignment**:
  - `relation_code`: `ASSOC_SYND_01` (Metabolic Syndrome Cluster Triad).
  - `inverse_code`: `ASSOC_SYND_01_INV`.
  - `directionality_concordance`: `true` ($0.67 < DR < 1.50$).
  - `clinical_rationale`: Components of the metabolic syndrome cluster frequently co-occur contemporaneously due to shared underlying insulin resistance and visceral adiposity without direct linear causation.

---

## 7. Open-Source Availability & Data Governance

All prompt schemas, evaluation criteria, and exemplar classifications are licensed under the **Apache 2.0 license** and Creative Commons Attribution 4.0 International (**CC-BY-4.0**).
Zero patient-level data, protected health information, or internal hostnames are utilized in this framework.
