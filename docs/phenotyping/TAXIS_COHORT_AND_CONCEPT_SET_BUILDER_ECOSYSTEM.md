# TAXIS in the OHDSI Phenotype & Concept Set Engineering Ecosystem
## Universal Empirical Foundation for Agentic, Programmatic, and Classical Cohort Construction

> **Document Type**: Downstream Application Blueprint & Illustrative Integration Concepts  
> **Operational Boundary Notice (`DEC-GR-027`, `DEC-GR-029`)**: This document explores prospective downstream tool integrations and conceptual architecture patterns that consume aggregate concept-pair tables produced by TAXIS. It is **NOT** part of the core OHDSI network study SQL execution on partner CDMs (`extras/CodeToRun.R`). External tools (e.g., OHDSI Keeper, ATLAS, Capr) are independent open-source projects; TAXIS supplies aggregate empirical data, not clinical adjudication guarantees.  
> **Authorship & Study Leadership**: Stephen H. Bandeian, MD, JD (Principal Investigator & Original SQL Engine Author); J. Marc Overhage, MD, PhD (Co-Principal Investigator); Gowtham Rao, MD, PhD; Shaun Grannis, MD, MS  
> **Applicable Decisions**: `DEC-GR-027`, `DEC-GR-028`, `DEC-GR-029`, `DEC-GR-030`, `DEC-GR-031`, `DEC-GR-032`  

---

## 1. Executive Summary & Foundational Affirmation

### 1.1. Foundational Affirmation
**Yes, TAXIS (Targeted Association and eXpression Mining for Identifying Phenotypes) can be utilized by any agentic or non-agentic cohort or concept set builder across the international observational health research community.**

TAXIS is architecturally decoupled from any single authoring tool or graphical interface. As codified in Dr. Gowtham Rao's authoritative decisions (`DEC-GR-027` and `DEC-GR-028`), TAXIS is not an end-user cohort authoring tool itself; rather, it constitutes the **empirical evidence layer**—the high-throughput computational association mining engine and standardized network data resource—that supplies pre-computed, longitudinal concept-to-concept co-occurrences, continuity-corrected Directionality Ratios ($DR$), Mantel-Haenszel Stratified Lifts ($\text{Lift}_{\text{strat}}$), and empirical lag decay distributions across real-world patient populations.

Because TAXIS produces standardized, cell-suppressed ($\text{count} < 5 \to -1$), multi-domain association matrices, any downstream system—whether a traditional graphical user interface, an R domain-specific language (DSL), an autonomous multi-agent framework, or a specialized Large Language Model (LLM) concept set generator—can integrate TAXIS as an empirical oracle.

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                DOWNSTREAM PHENOTYPE & CONCEPT SET BUILDERS                                      │
├──────────────────────────────────────────────────────┬──────────────────────────────────────────────────────────┤
│           AGENTIC & LLM-POWERED SYSTEMS              │         NON-AGENTIC & PROGRAMMATIC SYSTEMS               │
│                                                      │                                                          │
│  • OHDSI Pythia (ATLAS 3.0 AI Assistant)             │  • OHDSI Capr (R Domain-Specific Language)               │
│  • Phenelope (LLM Concept Set Generator)             │  • OHDSI ATLAS 3.0 (TrexSQL / DuckDB Cache)              │
│  • FastOMOP (Multi-Agent RWE Framework)              │  • OHDSI ATLAS 2.x (Classical Circe-be / WebAPI)         │
│  • OHDSI KEEPER (Dual-Hybrid LLM Case Adjudication)  │  • PHOEBE (Concept Set Recommendation Engine)            │
│  • OHDSI Study Agent (End-to-End Study Assistant)    │  • Aphrodite (Anchor-Based Machine Learning)             │
│  • Autonomous LLM-Capr Coding Agents                 │  • PheValuator & CohortDiagnostics (HADES)               │
└──────────────────────────────────────────▲───────────┴──────────────────────────▲───────────────────────────────┘
                                           │                                      │
                                           │ Universal Interoperability Surfaces  │
                                           │ (FastMCP / REST API / Parquet DuckDB)│
                                           │                                      │
┌──────────────────────────────────────────┴──────────────────────────────────────┴───────────────────────────────┐
│                                   TAXIS EMPIRICAL EVIDENCE FOUNDATION LAYER                                     │
│                                                                                                                 │
│   ┌───────────────────────────────┐  ┌──────────────────────────────┐  ┌─────────────────────────────────────┐  │
│   │   High-Throughput Mining      │  │  Longitudinal Grain & Lag    │  │   Stratified Lift Engine            │  │
│   │   (Pipeline v57 Partitioning) │  │  (cab_s37_lag / cab_s54)     │  │   (Mantel-Haenszel Utilization Dec) │  │
│   │                               │  │                              │  │                                     │  │
│   │   • 2.16M Patient Enterprise  │  │  • [-400, +400] Day Temporal │  │   • Eliminates Utilization Density  │  │
│   │     Benchmark Proof           │  │    Decay Distributions       │  │     Confounding                     │  │
│   │   • O(1) Candidate Validation │  │  • First Mention vs. All     │  │   • Continuity-Corrected            │  │
│   │   • Zero-Prevalence Pruning   │  │    Mentions Stability        │  │     Directionality Ratio (DR)       │  │
│   └───────────────────────────────┘  └──────────────────────────────┘  └─────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. The Systematic Challenges of Modern Cohort Construction

Whether authored by a human clinical informatician or an autonomous LLM agent, cohort definitions and clinical concept sets in observational research suffer from three chronic failure modes:

### 2.1. The Ontological vs. Empirical Semantic Divergence
Standard biomedical vocabularies (SNOMED-CT, RxNorm, LOINC) are formal ontologies that describe **taxonomic relationships** ("what clinical entities are"). Similarly, Large Language Models describe **textual semantic associations** ("how medical concepts are described in biomedical literature").

Neither ontology nor linguistic semantics reflect **real-world healthcare operations** ("which clinical events actually co-occur, in what temporal order, and under what reimbursement or clinical documentation incentives across longitudinal electronic health records"). For illustrative purposes:
- An ontology defines *Acute Bronchitis* as a lower respiratory tract infection, but does not quantify that outpatient encounters are frequently accompanied by supportive pharmacotherapy (e.g., antipyretics or analgesics) within 35 days, whereas invasive bronchoscopy is rarely performed.
- Similarly, an LLM prompted to generate diagnostic criteria for *Type 2 Diabetes Mellitus* may recommend *C-peptide laboratory testing* based on textbook descriptions; however, in routine primary care databases, C-peptide testing is performed in only a small minority of patients, creating severe cohort attrition if mandated as an uncalibrated inclusion criterion.

### 2.2. The LLM Hallucination and Zero-Prevalence Trap
When generative AI agents (e.g., Pythia, Phenelope, FastOMOP, or standalone GPT-4o/Claude agents) synthesize concept sets, they exhibit two vulnerabilities:
1. **Linguistic Plausibility Hallucination**: The agent selects valid OMOP concepts whose descriptions textually align with a disease vignette, but which have zero observed patient occurrences ($N = 0$) in the target database (e.g., selecting experimental or retired investigational drug codes).
2. **Failure to Detect Billing Artifacts**: The agent proposes inclusion criteria based on rule-out diagnostic codes (e.g., using a single outpatient encounter code for *Unstable Angina* where the patient underwent diagnostic workup that ruled out myocardial ischemia).

### 2.3. The Destructive Attrition of Intuitive Exclusions
Human investigators and LLM agents routinely propose intuitive exclusion rules (e.g., excluding patients with *Asthma* when phenotyping *Chronic Obstructive Pulmonary Disease*, or excluding *Type 1 Diabetes* from *Type 2 Diabetes*). In real-world data, diagnostic overlap, provisional coding, and historic diagnostic reclassification result in 30% to 70% of true cases possessing at least one isolated historical exclusion code. Without empirical co-occurrence matrices, builders introduce **destructive attrition**, invalidating study power and introducing severe selection bias.

---

## 3. Comprehensive Enumeration of OHDSI Cohort & Concept Set Builders

The OHDSI community has generated substantial tooling innovation across both deterministic software engineering and generative AI. Below is the systematic classification of these systems and their architectural integration points with TAXIS:

### 3.1. Detailed System Catalog

```
┌────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                              TAXIS INTEGRATION COMPATIBILITY MATRIX ACROSS OHDSI BUILDERS                              │
├────────────────────┬──────────────────┬─────────────────┬──────────────────────────┬───────────────────────────────────┤
│ System / Tool      │ Community Group  │ Paradigm        │ Primary Mechanism        │ TAXIS Empirical Role              │
├────────────────────┼──────────────────┼─────────────────┼──────────────────────────┼───────────────────────────────────┤
│ OHDSI Pythia       │ ATLAS 3.0 / AI   │ Agentic (Chat)  │ Eve-layout/ClojureScript │ Grounding tool: suggests codes,   │
│                    │ Workgroup        │                 │ via pythiaBridge.ts      │ windows, and checks attrition     │
├────────────────────┼──────────────────┼─────────────────┼──────────────────────────┼───────────────────────────────────┤
│ Phenelope          │ Phenotype        │ Agentic (LLM)   │ R package for LLM        │ Candidate ranking, zero-count     │
│                    │ Workgroup (2026) │                 │ concept set curation     │ pruning, lift-based refinement    │
├────────────────────┼──────────────────┼─────────────────┼──────────────────────────┼───────────────────────────────────┤
│ FastOMOP           │ OHDSI AI /       │ Multi-Agent     │ Orchestrated agent teams │ Empirical knowledge oracle and    │
│                    │ Open-Source 2026 │ Architecture    │ with safety guardrails   │ deterministic validation boundary │
├────────────────────┼──────────────────┼─────────────────┼──────────────────────────┼───────────────────────────────────┤
│ OHDSI KEEPER       │ Phenotype        │ Hybrid LLM      │ Dual-hybrid LLM chart    │ Feeds empirical feature sets for  │
│ (v2.2.0)           │ Adjudication     │ Adjudication    │ review (Ollama/Cloud)    │ de-identified patient timelines   │
├────────────────────┼──────────────────┼─────────────────┼──────────────────────────┼───────────────────────────────────┤
│ OHDSI Study Agent  │ Generative AI    │ Agentic         │ End-to-end study design  │ Supplies verified cohort criteria │
│                    │ Workgroup        │ (Workflow)      │ & Strategus JSON author  │ and negative control candidates   │
├────────────────────┼──────────────────┼─────────────────┼──────────────────────────┼───────────────────────────────────┤
│ Autonomous         │ Open-Source /    │ Agentic         │ LLM code synthesis       │ Recommends concept IDs and        │
│ LLM-Capr Agents    │ MCP Ecosystem    │ (Code Gen)      │ generating Capr scripts  │ temporal windows for Capr DSL     │
├────────────────────┼──────────────────┼─────────────────┼──────────────────────────┼───────────────────────────────────┤
│ OHDSI Capr         │ HADES Workgroup  │ Non-Agentic     │ Programmatic R DSL       │ Provides empirical concept sets   │
│                    │                  │ (Code DSL)      │ serializing Circe JSON   │ and data-driven attrition limits  │
├────────────────────┼──────────────────┼─────────────────┼──────────────────────────┼───────────────────────────────────┤
│ OHDSI ATLAS 3.0    │ ATLAS Arch Group │ Non-Agentic     │ Single-SPA Vue 3 app     │ TrexSQL DuckDB cache: O(1) checks │
│                    │ (Next-Gen)       │ (Web GUI)       │ with TrexSQL DuckDB      │ and descendant pruning            │
├────────────────────┼──────────────────┼─────────────────┼──────────────────────────┼───────────────────────────────────┤
│ OHDSI ATLAS 2.x    │ WebAPI / ATLAS   │ Non-Agentic     │ Classical web workbench  │ Supplies pre-compiled Circe JSON  │
│                    │ (Classical)      │ (Web GUI)       │ querying CDM via SQL     │ concept sets and cohort templates │
├────────────────────┼──────────────────┼─────────────────┼──────────────────────────┼───────────────────────────────────┤
│ PHOEBE             │ Vocabulary /     │ Non-Agentic     │ Vocabulary hierarchy &   │ Calibrates co-occurrence scores   │
│                    │ Phenotype WG     │ (Graph Search)  │ database co-occurrence   │ with Mantel-Haenszel lift & DR    │
├────────────────────┼──────────────────┼─────────────────┼──────────────────────────┼───────────────────────────────────┤
│ Aphrodite          │ Stanford /       │ Non-Agentic     │ Machine learning         │ Identifies high-specificity       │
│                    │ OHDSI Machine L. │ (ML / Anchor)   │ (Anchor Learning / PU)   │ anchor concepts and reduced space │
├────────────────────┼──────────────────┼─────────────────┼──────────────────────────┼───────────────────────────────────┤
│ PheValuator &      │ HADES Workgroup  │ Non-Agentic     │ Diagnostic prediction    │ Provides empirical reference sets │
│ CohortDiagnostics  │                  │ (Diagnostic)    │ modeling & characteriz.  │ for operating characteristic eval │
└────────────────────┴──────────────────┴─────────────────┴──────────────────────────┴───────────────────────────────────┘
```

---

## 4. Deep-Dive Integration Blueprints

### 4.1. Paradigm 1: Agentic LLM Cohort & Concept Set Builders (Pythia, Phenelope, FastOMOP, Study Agent)

#### 4.1.1. The Empirical Grounding Loop
Large Language Models excel at semantic synthesis but lack access to database state. TAXIS serves as an empirical tool provider using standard tool-calling specifications (such as Model Context Protocol or OpenAI JSON schemas).

```
   ┌────────────────────────────────────────────────────────────────────────────────────────┐
   │                                   LLM AGENT CONTEXT                                    │
   │                                                                                        │
   │   User Prompt: "Author a high-specificity cohort for Incident Acute Myocardial        │
   │                 Infarction (AMI) including acute therapies and diagnostic biomarkers." │
   └───────────────────────────────────────────┬────────────────────────────────────────────┘
                                               │
                                               ▼
   ┌────────────────────────────────────────────────────────────────────────────────────────┐
   │ 1. LLM Proposes Clinical Intent & Initial Seed Concepts                                │
   │    • Seed Condition: Acute Myocardial Infarction (OMOP Concept ID 4329847)             │
   └───────────────────────────────────────────┬────────────────────────────────────────────┘
                                               │ Tool Call: taxis_recommend_associations
                                               ▼
   ┌────────────────────────────────────────────────────────────────────────────────────────┐
   │ 2. TAXIS Empirical Query Execution (via FastMCP / REST API)                            │
   │    • Reads pre-computed table: work_cab_test.cab_s55_pair_all                          │
   │    • Computes Directionality Ratio (DR) and Mantel-Haenszel Stratified Lift            │
   │                                                                                        │
   │    Returned Evidence:                                                                  │
   │    - Aspirin / Oral (Drug):              Lift=4121.2, DR=0.37 (Confirmed Treatment)    │
   │    - Percutaneous Coronary Intervention: Lift=1894.5, DR=0.42 (Confirmed Treatment)    │
   │    - Serum Troponin I Measurement:       Lift=945.1,  DR=0.91 (Diagnostic Biomarker)  │
   │    - Unstable Angina (Condition):        Lift=88.4,   DR=2.68 (Prior Risk Factor)      │
   └───────────────────────────────────────────┬────────────────────────────────────────────┘
                                               │
                                               ▼
   ┌────────────────────────────────────────────────────────────────────────────────────────┐
   │ 3. LLM Maps Concepts to Deterministic Circe Criteria Slots                             │
   │    • Primary Entry Event: Condition Occurrence of Concept 4329847                      │
   │    • Inclusion Rule 1 (Biomarker): Measurement of Troponin within [-1, +1] days        │
   │    • Inclusion Rule 2 (Therapy): Drug Exposure of Aspirin within [0, +7] days          │
   │    • Risk Stratification: Unstable Angina partitioned to Baseline History [-365, -1]  │
   └────────────────────────────────────────────────────────────────────────────────────────┘
```

#### 4.1.2. Tool Specification for Agentic Frameworks (FastMCP Schema)
Any agent framework (Pythia in ClojureScript, Phenelope in R, FastOMOP in Python, or generic LangChain/AutoGen orchestrators) can declare the following standard tool contract:

```json
{
  "name": "taxis_query_concept_associations",
  "description": "Queries the TAXIS empirical association knowledge graph for clinical concepts that statistically co-occur with a specified index concept in real-world patient care. Returns patient counts, Mantel-Haenszel Stratified Lift, continuity-corrected Directionality Ratio (DR), and temporal lag distributions.",
  "parameters": {
    "type": "object",
    "properties": {
      "concept_id": {
        "type": "integer",
        "description": "The standard OMOP Concept ID of the index clinical entity."
      },
      "target_domain": {
        "type": "string",
        "enum": ["Condition", "Drug", "Procedure", "Measurement", "Observation"],
        "description": "Optional filter restricting association results to a specific clinical domain."
      },
      "clinical_role": {
        "type": "string",
        "enum": ["confirmatory_diagnostic", "first_line_therapy", "concurrent_manifestation", "prior_risk_factor"],
        "description": "Filter by temporal directionality: 'confirmatory_diagnostic' or 'first_line_therapy' (DR < 0.8), 'concurrent_manifestation' (0.8 <= DR <= 1.2), or 'prior_risk_factor' (DR > 1.2)."
      },
      "min_stratified_lift": {
        "type": "number",
        "default": 1.5,
        "description": "Minimum Mantel-Haenszel Stratified Lift threshold."
      },
      "limit": {
        "type": "integer",
        "default": 15,
        "description": "Maximum number of ranked concept pairs to return."
      }
    },
    "required": ["concept_id"]
  }
}
```

---

### 4.2. Paradigm 2: Programmatic R DSLs (OHDSI Capr & Strategus Studies)

**Capr (Cohort Definition API in R)** allows epidemiologists and automated R scripts to define cohorts programmatically without touching a web browser. Capr scripts compile deterministically into Circe JSON expressions via `Capr::toCohortJson()`.

#### 4.2.1. Programmatic Synthesis with Capr
By wrapping TAXIS query functions, an R workflow can automatically generate robust Capr cohorts where concept sets, inclusion criteria, and temporal windows are derived from empirical evidence:

```r
library(Capr)
library(DatabaseConnector)

# Function: Build an Empirically Grounded Incident Cohort using TAXIS and Capr
buildTaxisGroundedCohort <- function(conn, taxisSchema, indexConceptId, cohortName) {
  
  # Step 1: Query TAXIS for the index concept marginals and primary domain
  indexSql <- sprintf(
    "SELECT concept_name, domain_id FROM %s.cab_vocab_all_output WHERE concept_id = %d;",
    taxisSchema, indexConceptId
  )
  indexMeta <- querySql(conn, indexSql)
  
  # Step 2: Query TAXIS for top confirmed first-line pharmacotherapies (DR < 0.8, Lift >= 2.0)
  drugSql <- sprintf(
    "SELECT b_concept_id, b_concept_name, stratified_lift, directionality_ratio 
     FROM %s.cab_s55_pair_all 
     WHERE a_concept_id = %d 
       AND b_domain_id = 'Drug' 
       AND directionality_ratio < 0.80 
       AND stratified_lift >= 2.0 
     ORDER BY obs_all DESC LIMIT 5;",
    taxisSchema, indexConceptId
  )
  drugPairs <- querySql(conn, drugSql)
  
  # Step 3: Query TAXIS for empirical lag window (capturing 90% of observed density)
  lagSql <- sprintf(
    "SELECT min_day, max_day 
     FROM %s.cab_s37_lag_all 
     WHERE a_concept_id = %d 
       AND b_concept_id = %d 
       AND cumulative_density_fraction >= 0.90 
     LIMIT 1;",
    taxisSchema, indexConceptId, drugPairs$B_CONCEPT_ID[1]
  )
  lagWindow <- querySql(conn, lagSql)
  startDay <- if (nrow(lagWindow) > 0) lagWindow$MIN_DAY[1] else 0
  endDay   <- if (nrow(lagWindow) > 0) lagWindow$MAX_DAY[1] else 30
  
  # Step 4: Construct Capr Concept Sets programmatically
  indexCs <- cs(indexConceptId, name = as.character(indexMeta$CONCEPT_NAME[1]))
  treatmentCs <- cs(drugPairs$B_CONCEPT_ID, name = paste(indexMeta$CONCEPT_NAME[1], "First-Line Therapies"))
  
  # Step 5: Compose Deterministic Capr Cohort Definition
  cohortDef <- cohort(
    entry = entry(
      conditionOccurrence(indexCs),
      observationWindow = continuousObservation(priorDays = 365, postDays = 0),
      primaryCriteriaLimit = "First"
    ),
    attrition = attrition(
      "Empirical Confirmatory Pharmacotherapy" = withAll(
        atLeast(1, drugExposure(treatmentCs), duringCohort(start = startDay, end = endDay))
      )
    ),
    exit = exit(
      endOfContinuousObservation()
    )
  )
  
  return(cohortDef)
}
```

---

### 4.3. Paradigm 3: Modern Web Applications & Query Acceleration (ATLAS 3.0 & TrexSQL DuckDB)

**ATLAS 3.0** introduces a modern Single-SPA architecture coupled with **TrexSQL**, an embedded DuckDB analytical query engine that caches CDM summaries for instant cohort exploration.

#### 4.3.1. $O(1)$ Short-Circuiting and Inactive Concept Pruning
When an investigator edits an inclusion rule in ATLAS 3.0, TrexSQL typically runs expensive aggregate joins across the CDM. Integrating TAXIS pre-computed tables into TrexSQL's DuckDB cache introduces two major optimizations:

1. **Dead-End Cohort Short-Circuiting ($<1$ ms)**:
   - When an inclusion rule mandates the co-occurrence of Concept A and Concept B within interval $W$, TrexSQL inspects `taxis_concept_pairs` in DuckDB.
   - If either concept has a verified marginal count of zero ($N(A) = 0$ or $N(B) = 0$), or if the joint marginal is certified zero in the CDM, TrexSQL immediately returns `count: 0` without executing a distributed SQL scan across the primary database.
2. **Concept Set Descendant Pruning**:
   - Standard concept set expansion via `concept_ancestor` frequently introduces dozens or hundreds of obsolete descendant concept IDs that have zero patient records in the local CDM.
   - TrexSQL filters concept sets against `cab_s20_marginal_all`, pruning zero-count codes before query compilation. This reduces SQL `IN (...)` clause sizes by 60% to 80%, substantially diminishing database parsing and execution latency.

```sql
-- Ingestion of TAXIS Parquet Exports directly into ATLAS v3 TrexSQL DuckDB Cache
CREATE TABLE trex_taxis_marginals AS 
SELECT concept_id, domain_id, person_count, total_events 
FROM read_parquet('/var/atlas3/cache/taxis/cab_s20_marginal_all.parquet');

CREATE TABLE trex_taxis_pairs AS 
SELECT a_concept_id, b_concept_id, obs_all, same_day, after_a, before_a, 
       lift_after, directionality_ratio 
FROM read_parquet('/var/atlas3/cache/taxis/cab_s55_pair_all.parquet');
```

---

### 4.4. Paradigm 4: Clinical Case Adjudication & Diagnostic Evaluation (OHDSI KEEPER & PheValuator)

#### 4.4.1. Conceptual Downstream Application: Empirical Grounding for Case Review (e.g., OHDSI KEEPER)
**OHDSI KEEPER** (v2.2.0, developed by Anna Ostropolets & Martijn Schuemie) supports clinical case validation by extracting de-identified patient timelines centered on an index event (Day 0) for human and LLM-assisted case adjudication (via local sovereign models or cloud providers).

However, as first identified by **Dr. Gowtham Rao** on the OHDSI Forums in October 2023 (*"Case Adjudication with the help of LLM"*), KEEPER historically faced a primary human bottleneck: **The Expert-in-the-Loop Filter**. In standard KEEPER workflows, human clinical informaticians had to hand-craft exclusion rules to remove hundreds of irrelevant, co-occurring concept IDs from the patient timeline (e.g., removing unrelated encounters for "ear pain" or "sore throat" when evaluating suspected cases of Rheumatoid Arthritis). Without this manual curation, LLMs became overwhelmed by non-informative noise, increasing prompt token costs, inducing cognitive distraction, and triggering hallucinations.

In a prospective downstream integration, aggregate association metrics from TAXIS could serve as an objective empirical reference to assist clinical case review tools:

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│              CONCEPTUAL DOWNSTREAM WORKFLOW: AGGREGATE EVIDENCE IN CLINICAL TIMELINE REVIEW                     │
├─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                                 │
│   1. Patient EHR Timeline Extraction around Index Date (Day 0)                                                  │
│      • De-identified patient encounter occurrences (Condition, Drug, Measurement, Procedure, Observation)       │
│                                                                                                                 │
│   2. Empirical Aggregate Context Overlay (Downstream Exploration)                                               │
│      • Queries pre-computed aggregate marginals (cab_s20) and association summaries (cab_s55)                   │
│      • Highlights concepts with observed empirical co-occurrence as supporting context for review              │
│                                                                                                                 │
│   3. Descriptive Temporal Grouping                                                                              │
│      • Organizes concepts into chronological panels based on observed temporal sequence:                        │
│        - Predominantly Preceding Concepts (observed primarily prior to index date)                              │
│        - Contemporaneous Concepts (observed on or near index date)                                              │
│        - Predominantly Following Concepts (observed primarily after index date)                                 │
│                                                                                                                 │
│   4. Clinical Adjudicator Review (Human Expert or Audited Local Model)                                         │
│      • Presents chronologically structured timeline to adjudicators for clinical evaluation                     │
│      • Requires independent site-level governance, clinical adjudication, and validation against reference cases│
│                                                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

1. **Empirical Pre-Filtering as Hypothesis Context**: By querying TAXIS aggregate joint marginals and stratified lift, an adjudication pipeline could prioritize concepts with demonstrated empirical co-occurrence ($N \ge 5$, $\text{Lift}_{\text{strat}} \ge 1.50$) to assist clinical reviewers. Importantly, absence from a filtered pair table or low lift does not certify clinical irrelevance (e.g., rare manifestations or atypical presentations); candidate lists must serve as supporting context rather than rigid exclusion filters.
2. **Temporal Structuring of Candidate Events**:
   - In observational data, candidate concepts exhibit differing temporal patterns relative to the index condition. For example, hepatotoxic medications (e.g., acetaminophen overdose) typically precede acute liver injury records, whereas antidotes (e.g., N-acetylcysteine) typically follow.
   - Rather than assuming an LLM can infer clinical roles from raw concept lists, downstream tools can use TAXIS temporal metrics ($DR$, $\text{obs\_after}$, $\text{obs\_before}$) to arrange candidate concepts chronologically (pre-index vs. post-index), providing organized timeline structure for human or model evaluation. Observational temporal ordering does not prove clinical causality or mechanisms, but provides descriptive sequence.
3. **Governance and Evaluation Requirements for Prospective Integrations**:
   - Any future patient-dossier-to-cloud workflow requires its own verified data-handling and de-identification contract compliant with institutional review and partner data use agreements; aggregate suppression in TAXIS output archives does not establish a patient-level cloud transmission contract.
   - Any claim of improved adjudication accuracy or efficiency requires rigorous empirical evaluation against independently labeled clinical reference cases.
---

## 5. Comparative Evaluation: Cohort Builders With vs. Without TAXIS

The following matrix summarizes the technical and methodological contrast across all authoring environments when operating with versus without the TAXIS empirical foundation:

| Evaluation Dimension | Without TAXIS (Current Baseline) | With TAXIS Empirical Foundation |
|---|---|---|
| **Concept Selection** | Lexical string matching and ontological tree traversal; vulnerable to selecting retired, experimental, or zero-prevalence codes. | Data-driven selection ranked by empirical database prevalence ($N \ge 5$) and Mantel-Haenszel Stratified Lift ($\text{Lift}_{\text{strat}}$). |
| **Inclusion vs. Exclusion Logic** | Subjective clinician or LLM intuition; high risk of confusing diagnostic rule-out testing with true disease presence. | Descriptive temporal ordering: Continuity-corrected Directionality Ratio ($DR$) characterizes whether Concept A was recorded predominantly before ($DR \gg 1$) or after ($DR \ll 1$) Concept B in observational records. |
| **Temporal Window Specification** | Arbitrary standard intervals (e.g., fixed $\pm 30$ or $\pm 365$ days) chosen without justification. | Empirical lag decay distributions (`cab_s37_lag_all`) establish precise 90% observed clinical density bounds across $[-400, +400]$ days. |
| **Attrition Behavior** | Uncontrolled post-hoc attrition; blanket exclusion rules eliminate 30% to 70% of valid patients during database instantiation. | Pre-flight attrition boundaries: Rule-out exclusion candidates capped at $\le 10\%$ co-occurrence to protect study sample size and power. |
| **LLM Agent Reliability** | Selection of clinically plausible but unobserved or retired codes; ungrounded synthesis of zero-prevalence concept sets. | Empirical grounding: Agent tools query TAXIS empirical summaries, anchoring concept suggestions in observed database counts and identifying zero-prevalence codes. |
| **Database Execution Overhead** | Expensive full-table scans across hundreds of millions of CDM rows for every candidate inclusion rule trial. | $O(1)$ query short-circuiting in analytical caches (TrexSQL / DuckDB) and 60–80% reduction in SQL `IN (...)` clause sizes. |
| **Phenotype Portability** | Algorithms optimized on one hospital's coding patterns fail unpredictably when executed across an international network. | Standardized network-wide mining metrics ensure reproducible, multi-site validated phenotypic definitions. |

---

## 6. Standardized TAXIS Interoperability Interfaces

To enable friction-free integration across all existing and future OHDSI builders, TAXIS provides three standardized distribution surfaces:

### 6.1. Channel 1: High-Performance Parquet / DuckDB File Dumps (Bulk Ingestion)
- Mined summary tables (`cab_s10` through `cab_s55`) exported as columnar Apache Parquet files.
- Small-cell suppression enforced ($<5 \to -1$).
- Ingestible directly into DuckDB, Apache Arrow, Polars, or SQLite for local $O(1)$ tool querying.

### 6.2. Channel 2: Model Context Protocol (FastMCP) Service (Agentic Integration)
- Lightweight FastMCP server (Python/R) exposing tool functions (`taxis_query_concept_associations`, `taxis_get_lag_distribution`, `taxis_prune_concept_set`).
- Plug-and-play compatibility with Anthropic Claude Desktop, Cursor, Pythia, AutoGen, and LangChain agents.

### 6.3. Channel 3: OHDSI WebAPI & Plumber REST Endpoints (Web Application Integration)
- Standardized RESTful endpoints integrated into OHDSI WebAPI or standalone Plumber services:
  - `GET /taxis/associations/{conceptId}?domain={domain}&minLift={lift}`
  - `GET /taxis/directionality/{conceptId1}/{conceptId2}`
  - `GET /taxis/lag/{conceptId1}/{conceptId2}?coverage=0.90`
  - `POST /taxis/prune` (accepts concept set JSON; returns pruned concept set excluding zero-marginal codes).

---

## 7. Compliance, Governance, and Attribution

All implementations, integrations, and tool adapters utilizing TAXIS must comply with the established study governance:

1. **Authorship Attribution**: Stephen H. Bandeian, MD, JD (Principal Investigator & original SQL engine author); J. Marc Overhage, MD, PhD (Co-Principal Investigator); Gowtham Rao, MD, PhD; Shaun Grannis, MD, MS.
2. **Core Positioning (`DEC-GR-027`)**: TAXIS is the empirical association mining engine and network study package, not an end-user cohort authoring tool. Downstream applications are consumer tools built upon the TAXIS foundation.
3. **Repository Cleanliness (`DEC-GR-028`)**: Zero raw patient data or database dumps in GitHub repositories. All network data products distributed via secured bulk downloads or live web explorers.
4. **Data Privacy**: Mandatory aggregate-only summaries with strict small-cell suppression ($<5 \to -1$).
5. **Scholarly & Scientific English (`DEC-GR-032`)**: All documentation, tool descriptions, and agent prompt interfaces must maintain publication-grade medical, epidemiological, and scientific English.

---
