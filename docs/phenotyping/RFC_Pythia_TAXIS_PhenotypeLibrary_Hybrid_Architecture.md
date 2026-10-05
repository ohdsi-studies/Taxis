# OHDSI Technical RFC: RFC-OHDSI-2026-01
# Unified Hybrid Phenotyping Architecture: Resolving the Pythia Cold-Start Dilemma through Empirical Association Mining and Closed-Loop Phenotype Library Synchronization

> **RFC Status**: Proposed Technical Specification & Community Blueprint  
> **Version**: 1.0.0 (Release Candidate)  
> **Target Repositories**:  
> • [OHDSI/Atlas3](https://github.com/OHDSI/Atlas3.git)  
> • [OHDSI/Pythia](https://github.com/OHDSI/Pythia.git)  
> • [OHDSI/PhenotypeLibrary](https://github.com/OHDSI/PhenotypeLibrary.git)  
> • [ohdsi-studies/Taxis](https://github.com/ohdsi-studies/Taxis.git)  
> **Working Groups**: Phenotype Development & Evaluation, Open-Source Analytics Development, HADES  
> **Study Leadership**:  
> • Stephen H. Bandeian, MD, JD – Principal Investigator, [Johns Hopkins University School of Medicine](https://www.hopkinsmedicine.org)  
> • J. Marc Overhage, MD, PhD – Co-Principal Investigator, The Overhage Group / [Indiana University School of Medicine](https://medicine.iu.edu)  
> • Gowtham Rao, MD, PhD – Investigator, [CoReason, Inc.](https://www.coreason.ai) USA; OHDSI (Phenotype Development & Evaluation Workgroup)  
> • Shaun Grannis, MD, MS – Investigator, [Regenstrief Institute](https://www.regenstrief.org) / [Indiana University School of Medicine](https://medicine.iu.edu)  

---

## 1. Executive Summary & Problem Formulation

In observational health research, creating computable, valid, and portable phenotype algorithms is the foundation of clinical evidence generation. The OHDSI community has made foundational strides through two complementary pillars:
1. **The OHDSI Phenotype Library (`OHDSI/PhenotypeLibrary`)**: A curated, peer-reviewed repository of ~1,100 human-adjudicated cohort definitions expressed in OHDSI Circe JSON format.
2. **Atlas v3.0 & Pythia (`OHDSI/Atlas3`, `OHDSI/Pythia`)**: A modern conversational phenotyping assistant authored in ClojureScript and TypeScript, translating investigator intent into interactive card proposals.

However, an audit of Pythia's active codebase reveals two critical structural limitations that hamper phenotype authoring in practice:

### 1.1. The "Cold-Start" Defect in Pythia
In Pythia's core pattern aggregation engine ([`pythia.tools.phenotype-patterns`](file:///C:/files/git/github/ohdsi/Pythia/agent/src/pythia/tools/phenotype_patterns.cljs#L95-L96)), when an investigator requests a phenotype for a condition that lacks a pre-existing entry in the Phenotype Library, the tool produces the following fallback directive:

```clojure
;; C:\files\git\github\ohdsi\Pythia\agent\src\pythia\tools\phenotype_patterns.cljs:95-96
(when (zero? (or total 0))
  "No library definitions matched this condition — design from clinical reasoning and say that the library had nothing to anchor on.")
```

When this occurs, the conversational agent falls back entirely to ungrounded LLM internal recall. This "cold-start" failure leads to:
- **Hallucinated or Non-Standard Concept Sets**: The LLM suggests clinical concepts that do not exist or are non-standard in the OMOP Vocabulary.
- **Uncalibrated Temporal Windows**: Arbitrary lookback and observation windows (e.g., guessing 30-day vs. 365-day washouts) without empirical data on disease recording dynamics.
- **Arbitrary Directionality**: Incorrectly ordering tests, medications, and diagnoses relative to the index event.

### 1.2. The Guesswork Exclusion & Catastrophic Attrition Trap
Even when a library phenotype exists ("warm start"), Pythia relies on English-language regular expressions over concept set names ([`phenotype_patterns.cljs:38-48`](file:///C:/files/git/github/ohdsi/Pythia/agent/src/pythia/tools/phenotype_patterns.cljs#L38-L48)) to infer whether a concept is an exclusion:

```clojure
(def ^:private exclusion-name-re
  #"(?i)\b(exclud\w*|exclusion\w*|without|no prior|no history|prior|previous|competing|rule out|contraindicat\w*)\b")
```

Because Pythia has **zero empirical co-occurrence data**, it cannot estimate the real-world impact of an exclusion rule. When clinicians intuitively suggest excluding competing differential diagnoses (e.g., excluding Type 1 Diabetes from Type 2 Diabetes, or Asthma from COPD), they are unaware that real-world EHR and claims CDMs exhibit substantial diagnostic cross-coding and rule-out testing. 

In authoring experience, lifetime exclusions of common differential mimics often cause **destructive cohort attrition** (illustratively estimated at 25% to 70% of candidate patients in authoring practice). Under current Atlas v3 workflows, this attrition is typically discovered only *post-hoc* after costly SQL database execution via `summarise_attrition`.

---

## 2. The Solution: The Unified Hybrid Phenotyping Architecture

**TAXIS (Temporal Association eXploration for Clinical Inference Studies)** provides the missing **Empirical Association Layer**. Mined across 2.16 million longitudinal patients (Pipeline v57) and structured into an evidence-graded Clinical Knowledge Graph (v6.0; 112 relation codes), TAXIS enables a seamless, 4-tier hybrid workflow:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│               UNIFIED HYBRID PHENOTYPING ARCHITECTURE: 4-TIER WATERFALL                │
└────────────────────────────────────────────────────────────────────────────────────────┘

                 Investigator Prompt in Atlas v3 / Pythia:
                 "Author a cohort definition for Condition X"
                                     │
                                     ▼
     ┌───────────────────────────────────────────────────────────────┐
     │ TIER 1: Phenotype Library Retrieval (Lexical & Concept Match) │
     │ • Query OHDSI/PhenotypeLibrary via pythia.phenotype-sources   │
     │ • Match standard OMOP concept and clinical synonyms           │
     └───────────────────────────────┬───────────────────────────────┘
                                     │
                    ┌────────────────┴────────────────┐
                    │                                 │
            Cohort Match Found                No Cohort Match
             [WARM START]                      [COLD START]
                    │                                 │
                    ▼                                 ▼
     ┌──────────────────────────────┐  ┌──────────────────────────────┐
     │ TIER 2: TAXIS Empirical      │  │ TIER 3: TAXIS Autonomous     │
     │         Warm-Start Audit     │  │         Cold-Start Synthesizer│
     │ • Audit candidate exclusions │  │ • Query 11-edge clinical KG  │
     │   against 10% Rule-Out Cap   │  │ • Confirmatory labs (Lift>=3)│
     │ • Check Directionality (DR)  │  │ • First-line Rx (DR >= 1.50) │
     │ • Calibrate observation grain│  │ • Empirical grain guide      │
     │   using cab_s54_grain_guide  │  │ • Low-overlap screen (<5%)   │
     └──────────────┬───────────────┘  └──────────────┬───────────────┘
                    │                                 │
                    └────────────────┬────────────────┘
                                     ▼
     ┌───────────────────────────────────────────────────────────────┐
     │ TIER 4: Continuous Upstream Contribution Loop                 │
     │ • Package into HADES TaxisPhenotypeEvaluation format          │
     │ • Execute multi-site CohortDiagnostics & PheValuator          │
     │ • Format accepted definitions as candidate Pull Requests      │
     │   directly to OHDSI/PhenotypeLibrary                          │
     └───────────────────────────────────────────────────────────────┘
```

---

## 3. Mathematical & Algorithmic Foundations

The hybrid architecture operationalizes four mathematical algorithms sourced from TAXIS:

### 3.1. Healthcare Utilization-Stratified Lift (Mantel-Haenszel)
In observational health data, medically complex patients generate voluminous codes across all domains. Crude co-occurrence metrics severely confound true clinical affinity with general healthcare utilization density.

TAXIS computes **Stratified Lift** across 10 empirical healthcare utilization deciles:

$$\text{Lift}_{\text{strat}}(A, B) = \frac{\sum_{k=1}^{10} w_k \cdot \text{Obs}_k(A, B)}{\sum_{k=1}^{10} w_k \cdot \text{Exp}_k(A, B)}$$

- **Application in Pythia**: When proposing confirmatory criteria for an anchor condition, Pythia queries TAXIS to filter out incidental, high-utilization co-occurrences (e.g., routine metabolic panels, essential hypertension) and surfaces clinical criteria with strong empirical co-occurrence signal ($\text{Lift}_{\text{strat}} \ge 3.0$) for investigator review.

### 3.2. Continuity-Corrected Directionality Ratio ($DR$)
To prevent temporal missequencing (e.g., requiring a second-line therapy in a baseline lookback window), TAXIS computes the non-synchronous **Directionality Ratio ($DR$)**:

$$DR(A \rightarrow B) = \frac{\text{Pairs}(A \text{ before } B) + 0.5}{\text{Pairs}(B \text{ before } A) + 0.5}$$

- **$DR \ge 1.50$ (Empirical Temporal Succession)**: Concept B reliably follows Concept A. Pythia uses this as a candidate ranking signal for post-index inclusion windows ($[0, +30\text{d}]$ or $[0, +365\text{d}]$) for potential first-line therapies (`THER_DRUG_FIRSTLINE`) and downstream complications (`PROG_COMPLICATION`).
- **$0.67 < DR < 1.50$ (Empirical Temporal Symmetry)**: Concept pairs exhibit balanced before/after ordering. 
- **$DR \le 0.67$ (Empirical Precursor / Predisposition)**: Concept B reliably precedes Concept A. Pythia uses this as a signal for pre-index baseline exclusions or etiology criteria (`ETIOL_PREDISPOSE`).

> **Methodological Boundary**: $DR$ is calculated strictly from non-synchronous sequences ($A$ before $B$ vs. $B$ before $A$). It does not capture same-calendar-day events. Same-day clinical concurrency is measured separately by concurrent co-occurrence ($A \cap B$ on index date). Furthermore, temporal precedence represents an empirical observational sequence reflecting real-world clinical recording behavior, rather than definitive proof of biological causality or guideline-indicated therapy.

### 3.3. Pre-Execution 10% Anchor Patient Rule-Out Cap (`DEC-GR-005` / `DEC-GR-017`)
To prevent destructive exclusion attrition, TAXIS pre-calculates the unadjusted marginal proportion of anchor patients who carry each differential diagnosis mimic:

$$\text{Marginal Overlap Fraction} = \frac{\text{Persons}(A \cap B)}{\text{Persons}(A)}$$

- **Low Marginal Overlap ($< 5\%$)**: Low marginal attrition risk. Serves as an authoring screen for candidate review; does not guarantee clinical sensitivity, protect against clinical subgroup loss, or bound cumulative attrition.
- **Moderate Marginal Overlap ($5\% - 10\%$)**: Flagged as moderate marginal overlap for investigator adjudication.
- **High Attrition Risk ($> 10\%$)**: When marginal overlap exceeds 10%, Pythia intercepts the proposal and alerts the investigator **before cohort instantiation**:
  > *"Warning (Illustrative): In observational data, candidate mimics may exhibit substantial overlap (e.g., an illustrative ~28% cross-recording between related diabetes concepts). Adding a blanket lifetime exclusion will reduce cohort size substantially. Consider restricting the exclusion to insulin monotherapy without oral antidiabetics, or limiting the exclusion window to index day."*

> **Methodological Boundary**: Marginal overlap is an unadjusted pairwise heuristic rather than a sensitivity guarantee. When an investigator specifies multiple exclusion criteria, the cumulative attrition is determined by the *union* of those exclusions, which may compound (e.g., two disjoint 7% exclusions can remove 14% of the cohort). Cohort-specific joint-exclusion assessment remains necessary before interpreting attrition. The 10% cap serves solely as an automated authoring screen to alert investigators to high-risk exclusions before database instantiation; generated draft cohorts remain subject to expert clinician review.

### 3.4. Longitudinal Pattern Signatures & The Grain Guide (`cab_s54_grain_guide`)
Sourced directly from `concept_ab_finalize.sql:842-874`, TAXIS classifies clinical concepts into empirical longitudinal signatures, eliminating window guesswork:

| Pattern Signature | Empirical SQL Classification Rules | Recommended Grain | Illustrative Modeling Options for Investigator Review |
| :--- | :--- | :---: | :--- |
| **`punctate`** | `mentions_per_person < 1.05` | **All Mentions** | Acute one-time event (e.g., accidental injury). Minimal or no washout option. |
| **`clustered`** | `median_gap_bucket <= 14` days | **First Mention** | Acute episode with flurry of care (e.g., Acute MI, Pneumonia). Candidate 30d episode collapse. |
| **`chronic`** | `mentions_per_person >= 8.0` and `median_gap_bucket <= 90` days | **First Mention** | Indefinite disease course (e.g., T2DM, COPD, CKD). Prior observation required; enter on first. |
| **`recurrent`** | `median_gap_bucket >= 90` days | **All Mentions** | Distinct episodic recurrence (e.g., Major Depressive Episode, Gout). Candidate 90d-180d washout. |
| **`episodic`** | `frac_gaps_tight >= 0.25` and `frac_gaps_long >= 0.25` | **Both / Dual** | Complex cycle (e.g., Multiple Sclerosis, Relapsing Remitting). Model onset and episodes separately. |
| **`mixed`** | Other distributed recurrence patterns | **Both / Dual** | Heterogeneous recording pattern. Require investigator adjudication. |
| **`unknown`** | `n_gaps is null or n_gaps = 0` | **Both / Dual** | Insufficient gap data. Default to user-specified protocol. |

> **SQL CASE Precedence**: Sourced directly from `concept_ab_finalize.sql:842-850`, patterns are classified in strict sequential order:
> 1. `unknown`: `n_gaps is null or n_gaps = 0`
> 2. `punctate`: `mentions_per_person < 1.05`
> 3. `episodic`: `frac_gaps_tight >= 0.25 and frac_gaps_long >= 0.25`
> 4. `chronic`: `mentions_per_person >= 8.0 and median_gap_bucket <= 90`
> 5. `clustered`: `median_gap_bucket <= 14`
> 6. `recurrent`: `median_gap_bucket >= 90`
> 7. `mixed`: all remaining cases
>
> *Note*: Episode windows and washout periods presented above are illustrative candidate options and require independent clinical and protocol justification. The primary entry setting adheres to First-entry by default (`DEC-GR-007`).

---

## 4. Technical Architecture & Proposed Agent Tool Contracts

To define this architecture for future implementation in Pythia (`@ohdsi/pythia-agent`), we define four proposed tool interface specifications (pending compiler and runtime integration):

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        PROPOSED PYTHIA AGENT TOOL ECOSYSTEM                            │
├────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                        │
│   EXISTING TOOLS (Warm-Start)              NEW TAXIS TOOLS (Audit & Cold-Start)        │
│   ┌─────────────────────────────┐          ┌───────────────────────────────────────┐   │
│   │ search_phenotypes           │          │ taxis_recommend_associations         │   │
│   │ • Matches PhenotypeLibrary  │          │ • Queries 112 relation codes from KG  │   │
│   └─────────────────────────────┘          └───────────────────────────────────────┘   │
│   ┌─────────────────────────────┐          ┌───────────────────────────────────────┐   │
│   │ get_reference_phenotype     │          │ taxis_audit_exclusion_attrition       │   │
│   │ • Fetches Circe JSON body   │          │ • Checks 10% Anchor Patient Cap       │   │
│   └─────────────────────────────┘          └───────────────────────────────────────┘   │
│   ┌─────────────────────────────┐          ┌───────────────────────────────────────┐   │
│   │ phenotype_patterns          │ ◄──────► │ taxis_synthesize_coldstart            │   │
│   │ • Aggregates library sets   │ Fallback │ • Generates proposed Circe JSON when  │   │
│   └─────────────────────────────┘ Dispatch │   Phenotype Library has zero matches  │   │
│                                            └───────────────────────────────────────┘   │
│                                            ┌───────────────────────────────────────┐   │
│                                            │ taxis_get_grain_guide                 │   │
│                                            │ • Provides empirical pattern & grain  │   │
│                                            └───────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

### 4.1. Tool 1: `taxis_synthesize_coldstart` (Proposed Cold-Start Resolution)
When `phenotype_patterns` detects zero matches in `OHDSI/PhenotypeLibrary`, it dispatches to `taxis_synthesize_coldstart`:

#### Proposed ClojureScript Interface Specification (`agent/src/pythia/tools/taxis_synthesize_coldstart.cljs`):
```clojure
(ns pythia.tools.taxis-synthesize-coldstart
  "Synthesizes a proposed 4-slot OHDSI Circe JSON cohort definition for conditions
   lacking a template in the OHDSI Phenotype Library (Cold-Start Resolution).
   Generated cohorts are proposed drafts requiring investigator review."
  (:require [clojure.string :as str]
            [pythia.http :as http]))

(def schema
  {:type "object"
   :properties
   {:conceptId {:type "number"
                :description "Standard OMOP Concept ID of the target clinical condition."}
    :targetName {:type "string"
                 :description "Human-readable label of the target phenotype."}}
   :required ["conceptId"]})

(defn call [{:keys [conceptId targetName]}]
  (-> (http/post-json "/api/taxis/v1/synthesize"
                      {:conceptId conceptId
                       :targetName (or targetName (str "Concept-" conceptId))
                       :minLift 3.0
                       :maxExclusionOverlap 0.05 ;; Authoring threshold for low marginal overlap screening (<5%); does not guarantee sensitivity
                       :defaultGrain "first"})
      (.then (fn [response]
               {:content [{:type "text"
                           :text (js/JSON.stringify (clj->js response))}]}))))
```

#### JSON Schema & Synthetic Demonstration Fixture:
```json
{
  "anchorConceptId": 46271022,
  "anchorConceptName": "Chronic kidney disease stage 3b",
  "status": "COLD_START_SYNTHESIZED",
  "provenance": "TAXIS Knowledge Graph v6.0 (Pipeline v57, 2.16M patients)",
  "circeCohort": {
    "ConceptSets": [
      {
        "id": 0,
        "name": "CKD Stage 3b",
        "expression": { "items": [{ "concept": { "CONCEPT_ID": 46271022 }, "includeDescendants": true }] }
      },
      {
        "id": 1,
        "name": "Serum Creatinine / eGFR < 45",
        "expression": { "items": [{ "concept": { "CONCEPT_ID": 3016723 }, "includeDescendants": true }] }
      }
    ],
    "PrimaryCriteria": {
      "CriteriaList": [
        {
          "ConditionOccurrence": {
            "CodesetId": 0,
            "First": true
          }
        }
      ],
      "ObservationWindow": { "PriorDays": 365, "PostDays": 0 },
      "PrimaryCriteriaLimit": { "Type": "First" }
    },
    "InclusionRules": [
      {
        "name": "Confirmatory Laboratory eGFR",
        "expression": {
          "Type": "ALL",
          "CriteriaList": [
            {
              "Criteria": {
                "Measurement": {
                  "CodesetId": 1,
                  "ValueAsNumber": { "Op": "lt", "Value": 45.0 }
                }
              },
              "StartWindow": { "Start": { "Days": 30, "Coeff": -1 }, "End": { "Days": 30, "Coeff": 1 } },
              "Occurrence": { "Type": 2, "Count": 1 }
            }
          ]
        }
      }
    ]
  },
  "empiricalRationale": "Proposed draft synthesized using 4-slot deterministic compiler: primary index event on First mention (grain: chronic, DEC-GR-007 baseline default), confirmed by eGFR measurement (<45 mL/min/1.73m2, Lift=6.4, DR=1.12), with candidate exclusions pre-screened for low marginal overlap (<5%) subject to clinician protocol review."
}
```

### 4.2. Tool 2: `taxis_audit_exclusion_attrition` (Proposed Warm-Start Optimization)
When Pythia retrieves an existing Phenotype Library cohort (e.g. COPD #1263 or T2DM #1032), it passes candidate exclusions to this tool:

#### Proposed ClojureScript Interface Specification (`agent/src/pythia/tools/taxis_audit_exclusion_attrition.cljs`):
```clojure
(ns pythia.tools.taxis-audit-exclusion-attrition
  "Audits candidate exclusion criteria against empirical co-occurrence distributions
   using the TAXIS 10% Anchor Patient Rule-Out Cap to prevent destructive cohort attrition."
  (:require [pythia.http :as http]))

(def schema
  {:type "object"
   :properties
   {:anchorConceptId {:type "number"
                      :description "Standard OMOP Concept ID of the primary cohort entry event."}
    :candidateExclusionConceptId {:type "number"
                                  :description "Standard OMOP Concept ID of the proposed exclusion condition."}}
   :required ["anchorConceptId", "candidateExclusionConceptId"]})

(defn call [{:keys [anchorConceptId candidateExclusionConceptId]}]
  (-> (http/post-json "/api/taxis/v1/audit-exclusion"
                      {:anchorConceptId anchorConceptId
                       :candidateExclusionConceptId candidateExclusionConceptId})
      (.then (fn [response]
               {:content [{:type "text"
                           :text (js/JSON.stringify (clj->js response))}]}))))
```

#### JSON Schema & Synthetic Return Payload:
```json
{
  "anchorConceptId": 255573,
  "anchorConceptName": "Chronic obstructive pulmonary disease",
  "candidateExclusionConceptId": 317009,
  "candidateExclusionConceptName": "Asthma",
  "marginalOverlapPercent": 24.8,
  "capExceeded": true,
  "capThresholdPercent": 10.0,
  "attritionRiskLevel": "CRITICAL_ATTRITION_WARNING",
  "recommendedAction": "DO_NOT_EXCLUDE_LIFETIME",
  "mitigationAdvice": "Excluding asthma across all historical records eliminates 24.8% of valid COPD patients due to diagnostic testing, symptom overlap, or asthma-COPD overlap syndrome (ACOS). Restrict exclusion to acute childhood asthma (<18 years old) or index-day only."
}
```

### 4.3. Dynamic Fallback Wiring in `phenotype_patterns.cljs`

To seamlessly connect the Phenotype Library with TAXIS, [`phenotype_patterns.cljs`](file:///C:/files/git/github/ohdsi/Pythia/agent/src/pythia/tools/phenotype_patterns.cljs) is enhanced to dispatch to TAXIS when `total` definitions is zero:

```clojure
;; Proposed enhancement to pythia.tools.phenotype-patterns/interpretation
(defn interpretation
  "Reading of the aggregate the agent should act on. Dispatches to TAXIS when library is empty."
  [s]
  (let [limits (:entry-event-limit s)
        first-limit (some #(when (= "First" (:value %)) (:count %)) limits)
        total (:definitions-considered s)]
    (str/join
     " "
     (remove
      nil?
      [(when (zero? (or total 0))
         (str "No library definitions matched this condition in OHDSI Phenotype Library. "
              "DISPATCHING TO TAXIS: Call `taxis_synthesize_coldstart` to retrieve empirical "
              "criteria from the 2.16M patient knowledge graph rather than guessing."))
       (when (seq (:explicitly-excluded s))
         (str "The explicitly-excluded list shows what accepted library definitions rule out. "
              "BEFORE PROPOSING: Call `taxis_audit_exclusion_attrition` for each candidate exclusion "
              "to ensure it does not exceed the 10% anchor patient attrition cap."))
       (when (and first-limit total (> first-limit (/ total 2)))
         "Most accepted library definitions enter on FIRST qualifying event. Maintain First-entry by default (DEC-GR-007).")]))))
```

---

## 5. Site-Local Data Governance & Security Perimeter (`DEC-GR-005`, `DEC-GR-013`)

To guarantee privacy preservation, eliminate sensitivity barriers with institutional data partners (e.g. healthcare systems, insurers), and ensure compliance with healthcare data regulations:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                   SITE-LOCAL DATA GOVERNANCE & PERIMETER BOUNDARIES                     │
├────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                        │
│   INSTITUTIONAL PARTNER SECURE ZONE (Behind Hospital / Payer Firewall)                 │
│   ┌────────────────────────────────────────────────────────────────────────────────┐   │
│   │  Local OMOP Common Data Model (CDM v5.3 / v5.4)                                │   │
│   │  • Patient-level clinical records, visits, observations                        │   │
│   └───────────────────────────────────────┬────────────────────────────────────────┘   │
│                                           │                                            │
│                                           ▼                                            │
│   ┌────────────────────────────────────────────────────────────────────────────────┐   │
│   │  TAXIS Concept AB Mining Engine (Pipeline v57)                                 │   │
│   │  • Populated concept-pair co-occurrences (cab_s55_pair_all) [SITE-LOCAL ONLY]  │   │
│   │  • Raw transition matrices & non-aggregated pair counts [SITE-LOCAL ONLY]      │   │
│   └───────────────────────────────────────┬────────────────────────────────────────┘   │
│                                           │                                            │
│                                           ▼                                            │
│   ┌────────────────────────────────────────────────────────────────────────────────┐   │
│   │  TAXIS Site-Local Microservice & Suppression Gateway                           │   │
│   │  • Small-cell suppression threshold: minCellCount >= 5 (mandatory floor)       │   │
│   │  • Cross-table histogram subtraction protection (closing 1/19/20 leak attack)  │   │
│   │  • Companion masking: joint suppression of counts, totals, and derived ratios  │   │
│   └───────────────────────────────────────┬────────────────────────────────────────┘   │
│                                           │                                            │
│ ══════════════════════════════════════════╪═══════════════════════════════════════════ │
│   FIREWALL BOUNDARY                       │ EXPORT ALLOWLIST ONLY (<5 suppressed)      │
│   ZERO PATIENT IDENTIFIERS OR PAIR COUNTS │                                            │
│ ══════════════════════════════════════════╪═══════════════════════════════════════════ │
│                                           │                                            │
│   CLIENT / EXTERNAL ZONE                  ▼                                            │
│   ┌────────────────────────────────────────────────────────────────────────────────┐   │
│   │  ATLAS v3.0 / Pythia Agent Client (@ohdsi/pythia-agent)                        │   │
│   │  • Ingests aggregate relation codes, stratified lift, and directionality       │   │
│   │  • Prompts cloud LLM endpoints with aggregate clinical concepts only           │   │
│   └────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                        │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

1. **Site-Local Isolation of Pair Matrices**: Populated concept-pair matrices (`cab_s55_pair_all`), granular co-occurrences, and local patient identifiers **must remain site-local behind institutional firewalls at all times**. They are never packaged into public distributable libraries or transmitted off-premises.
2. **Code-Only Distributable Artifacts**: Distributable packages (such as `@ohdsi/atlas-plugin-taxis` or containerized service engines) are strictly code-only. They execute against local data behind the partner's firewall.
3. **Aggregate-Only Outbound Perimeter**: When Pythia interacts with remote LLM endpoints (e.g. cloud-hosted models), the communication boundary transmits strictly aggregate, small-cell suppressed descriptive metadata ($< 5$). Zero patient identifiers, granular cell counts, or pairwise occurrence matrices may cross the outbound perimeter.

---

## 6. Closing the Loop: Proposed Automated Phenotype Library Contribution Engine

A proposed design framework to transform newly synthesized, benchmarked phenotypes into peer-reviewed community assets (unexecuted design specification awaiting CI implementation):

```text
┌────────────────────────┐      ┌────────────────────────┐      ┌────────────────────────┐
│ 1. Cold-Start Synthesis│ ───► │ 2. Multi-CDM Benchmark │ ───► │ 3. Candidate Library PR│
│ • TaxisPhenotypeCreator│      │ • TaxisPhenotypeEval   │      │ • Circe JSON in inst/  │
│ • Generates Circe JSON │      │ • CohortDiagnostics    │      │ • Diagnostics ZIP      │
│ • Standard slots       │      │ • PheValuator Metrics  │      │ • OHDSI Workgroup Form │
└────────────────────────┘      └────────────────────────┘      └────────────────────────┘
```

1. **Automated Submission Packaging (Proposed Specification)**:
   - The evaluation package (`TaxisPhenotypeEvaluation`) instantiates the synthesized cohort across multiple partner CDMs upon investigator initiation.
   - It executes `CohortDiagnostics` and `PheValuator` to generate empirical diagnostic performance characteristics (Sensitivity, Specificity, PPV, NPV, F1 Score).
2. **Standardized Candidate PR Generation (Proposed Design)**:
   - A proposed automation script formats the Circe JSON into `inst/cohorts/<new_id>.json`.
   - Compiles the diagnostic evidence into `inst/cohortDiagnostics/` and populates the OHDSI Phenotype Development & Evaluation Workgroup clinical description markdown template.
   - Submits a candidate Pull Request to `OHDSI/PhenotypeLibrary` for human workgroup peer review.
3. **Virtuous Cycle**:
   - Once evaluated and merged by human workgroup peers, the new phenotype becomes part of `phenotype-library/cohorts-index.edn`.
   - On the next release, Pythia accesses it directly as a **Tier 1 Warm-Start baseline**, expanding community knowledge while eliminating future cold starts for that condition.

---

## 7. Design Target Hypotheses & Proposed Evaluation Framework

> **Evaluation Scope & Status**: The performance metrics below represent **projected design target hypotheses** for upcoming multi-site observational evaluation; they do not represent completed prospective trial outcomes. Illustrative tool-payload values in Section 4 are synthetic demonstration fixtures. Conventional baseline figures represent illustrative operational assumptions based on qualitative authoring experience rather than measured multi-CDM benchmark trials. Formal validation requires multi-CDM execution against institutional data partners.

| Phenotyping Dimension | Conventional Authoring (Illustrative Baseline Assumptions Awaiting Partner Measurement) | Atlas v3 + TAXIS Hybrid Integration (Design Target) | Hypothesized Rationale |
| :--- | :--- | :--- | :--- |
| **Phenotype Cold-Start Coverage** | **Fails on ~60%** of conditions not in Phenotype Library v3.37. | **< 2% failure target**: Expands coverage across standard concepts with empirical graph associations. | Empirically grounded graph relationships eliminate dependence on static library JSONs. |
| **Exclusion Attrition Failures** | **~35% of novel cohorts** suffer $\ge 90\%$ catastrophic patient loss after initial generation. | **< 3% attrition target**: Pre-execution 10% rule-out cap alerts users to high-attrition exclusions. | Intercepts high-risk exclusions before database instantiation. |
| **Concordance with Clinical Adjudication** | Variable (0.65 – 0.82 F1-score depending on prompt complexity). | **0.90 – 0.95 F1 target** across benchmark conditions (COPD, CKD, T2DM, Obesity, Hyperkalemia). | Highly calibrated clinical specificity and sensitivity. |
| **Authoring Iteration Cycle** | 4 – 8 trial-and-error generation runs per validated cohort. | **1 – 2 runs target**: Recommended criteria, windows, and exclusions configured on the first turn. | Substantial acceleration in study cohort delivery. |

---

## 8. Implementation Roadmap

### Phase 1: Prototype Site-Local REST Gateway (Q4 2026)
- Package TAXIS 40-batch query logic (`cab_s54_grain_guide`, `cab_s37_lag_all`, `cab_s55_pair_all`) into a site-local Python/FastAPI container residing behind the local database firewall.
- Expose site-local endpoints: `/api/v1/synthesize`, `/api/v1/audit-exclusion`, `/api/v1/recommend`, and `/api/v1/grain` with strict small-cell suppression ($< 5$).

### Phase 2: Dynamic Browser Tool Mount in Atlas v3 (Q1 2027)
- Author `@ohdsi/atlas-plugin-taxis` for Atlas v3 SPA.
- Register browser tools into `window.__pythiaClientTools` for zero-friction client-side integration connecting strictly to the site-local API.

### Phase 3: Upstream Pythia Tool & Prompt Contribution (Q2 2027)
- Submit Pull Request to `OHDSI/Pythia` introducing:
  - `agent/src/pythia/tools/taxis_synthesize_coldstart.cljs`
  - `agent/src/pythia/tools/taxis_audit_exclusion_attrition.cljs`
  - Fallback dispatch enhancement in `agent/src/pythia/tools/phenotype_patterns.cljs`.
- Add test suites in `agent/test/pythia/tools/taxis_tools_test.cljs` and evals in `plugin/evals/`.

### Phase 4: Phenotype Library Continuous Integration Pipeline (Q3 2027)
- Ship automated PR exporter in `TaxisPhenotypeEvaluation` generating candidate Phenotype Library submissions complete with `CohortDiagnostics` and `PheValuator` validation packages.

---

## 9. Conclusion

By unifying the curated gold standards of the **OHDSI Phenotype Library**, the conversational flexibility of **Atlas v3 / Pythia**, and the empirical rigor of **TAXIS**, the observational health informatics community gains a self-expanding, robust, and mathematically grounded phenotyping engine. Researchers can author valid cohorts in minutes—resolving cold-start gaps through empirical graph synthesis while safeguarding against destructive exclusion attrition.
