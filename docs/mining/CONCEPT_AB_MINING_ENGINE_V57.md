# TAXIS Concept AB Association Mining Engine (Pipeline v57)
## Technical Architecture, Statistical Estimands & Database Specifications

> **Document Type**: Scientific Architecture & Engineering Specification  
> **Target Release**: Wave 5 (`wave/05-concept-ab-mining-engine`)  
> **Source Pipeline**: Indiana Network for Patient Care (INPC) OMOP CDM v5.4 Production Run (2.16M Longitudinal Patients, 11.3M Person-Years)  
> **Authoritative Decisions**:  
> • `DEC-GR-005`: Aggregate-Only Non-PHI Policy (concept-pair matrices remain local behind firewalls)  
> • `DEC-GR-006`: Target Federated CDM Deployments (Claims, EHR, International CDMs)  
> • `DEC-GR-010`: Dual Lift Reporting Architecture (Unadjusted Person Lift vs. Utilization-Stratified Lift)  
> **Study Leadership**:  
> • Stephen H. Bandeian, MD, JD – Principal Investigator, Johns Hopkins University School of Medicine  
> • J. Marc Overhage, MD, PhD – Co-Principal Investigator, The Overhage Group / Indiana University School of Medicine  
> • Gowtham Rao, MD, PhD – Investigator, CoReason, Inc. USA; OHDSI (Phenotype working group)  
> • Shaun Grannis, MD, MS – Investigator, Regenstrief Institute / Indiana University School of Medicine  

---

## 1. Executive Summary & Translational Purpose

Standard clinical vocabularies in observational health informatics (such as SNOMED-CT, RxNorm, and LOINC) structure healthcare concepts through hierarchical taxonomies (*is-a* relationships). However, systematic terminology audits demonstrate that standard vocabularies reflect **only 0.44%** of operational, multi-domain clinical associations encountered in real-world care (such as which laboratory test confirms a diagnosis, or which medication treats a chronic disorder).

The **TAXIS Concept AB Association Mining Engine (Pipeline v57)** was engineered to discover, quantify, and categorize these empirical clinical relationships at enterprise scale. Executed across **2.16 million longitudinal patients** spanning more than **11.3 million person-years of observation** in the Indiana Network for Patient Care (INPC) OMOP Common Data Model (CDM v5.4), the engine mines statistical associations across **6 cross-domain intersections**:
1. `Condition - Drug`
2. `Condition - Measurement`
3. `Condition - Procedure`
4. `Condition - Condition`
5. `Drug - Procedure`
6. `Drug - Drug`

The resulting output—a structured, graded matrix of **1.9 million clinically relevant concept pairs**—provides the empirical foundation for the downstream TAXIS Knowledge Graph, automated Circe phenotype synthesis, candidate negative control generation, and causal confounding reduction.

---

## 2. Statistical Estimands & Epidemiological Counting Rules

Pipeline v57 enforces precise mathematical definitions and boundary conditions to characterize observed co-occurrences and assess whether temporal patterns and stratification suggest substantive clinical associations rather than acute recording artifacts or unadjusted healthcare utilization confounding.

```text
┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                              TAXIS LONGITUDINAL TEMPORAL WINDOW ARCHITECTURE                           │
└────────────────────────────────────────────────────────────────────────────────────────────────────────┘
                    Baseline Observation Wash-In                    Prospective Follow-up Horizon
                    (≥ 365 Days Observation)                        (Incident Follow-up: 1 to 730 Days)
 ─────────────────────────────────────────────────────────────┬──────────────────────────────────────────►
                                                              │
                                                              ▼
                                                     [Concept A: Index Event]
                                                    (First Eligible Presentation)
                                                              │
                               ┌──────────────────────────────┴──────────────────────────────┐
                               ▼                                                             ▼
                    [Same-Day Ties: NA=B]                                         [Directional Precedence]
                    • Co-occurs on Day 0                                          • NA→B: B occurs in [+1, +730] days
                    • Recorded as distinct metric                                   with zero prior B in lookback
                    • EXCLUDED from directional counts                            • NB→A: Reverse precedence
```

### 2.1 Baseline Observation Wash-In & Incident Eligibility
To establish baseline clinical characterization and confirm that index occurrences are newly documented presentations rather than established prevalent conditions:
- **Wash-In Requirement**: A patient must have $\ge 365$ days of continuous observation in `observation_period` prior to the index occurrence of Concept A ($T_{\text{index}} - T_{\text{start}} \ge 365\text{ days}$).
- **Eligible Population Denominator ($N$)**: The global population denominator is strictly restricted to patients meeting the 365-day wash-in requirement ($N = 2,160,000$ in the INPC benchmark run).

### 2.2 Asymmetric Finite-Window Longitudinal Precedence Intervals
Symmetric short windows (e.g., $\pm 30$ days) introduce acute capture bias when applied to chronic progressive illnesses, recording only acute encounters where both concepts happen to be coded together while missing prospective disease progression.

While finite follow-up intervals are sometimes colloquially described as "hazard windows" in exploratory mining, Pipeline v57 computes **distinct-person incident co-occurrence counts across specified prospective time horizons** (without estimating parametric continuous-time hazard rates):
1. **Prospective Follow-Up Horizons**: Evaluates the subsequent incident presentation of Concept B across standard epidemiological intervals following index Concept A:
   - $[+1, +30\text{ days}]$: Immediate peri-diagnostic testing and acute stabilization therapy.
   - $[+1, +90\text{ days}]$: Short-term treatment modification and subacute monitoring.
   - $[+1, +365\text{ days}]$: Annual maintenance management and intermediate complications.
   - $[+1, +730\text{ days}]$: Two-year chronic disease progression and secondary sequelae.
   - $[+1, \text{End of Observation}]$: Complete longitudinal follow-up.
2. **Incident Manifestation Rule (Lookback Cleanliness)**: To measure incident prospective presentation, the calculation of $N_{A \to B}$ strictly requires that Concept B had **zero recorded occurrences** in the patient's record prior to Concept A during the 365-day baseline observation period.

### 2.3 Separation of Same-Day Ties ($N_{A=B}$)
Clinical concepts recorded on the exact same calendar date ($T_A = T_B$, e.g., on the same emergency encounter or problem list) introduce ambiguous temporal precedence:
- Same-day co-occurrences are tallied and reported as a dedicated metric: **$N_{A=B}$** (and same-visit fraction `same_visit_frac`).
- **Strict Boundary Rule**: Same-day ties are **strictly excluded** from directional precedence counts ($N_{A \to B}$ and $N_{B \to A}$). This prevents simultaneous diagnostic billing codes from artificially inflating descriptive temporal precedence counts.

### 2.4 Continuity-Corrected Directionality Ratio ($DR$)
To assess whether Concept A reliably precedes Concept B, the engine computes the continuity-corrected Directionality Ratio:
$$DR = \frac{N_{A \to B} + 0.5}{N_{B \to A} + 0.5}$$

Where:
- $N_{A \to B}$ is the distinct person count where Concept A preceded Concept B ($T_A < T_B$).
- $N_{B \to A}$ is the distinct person count where Concept B preceded Concept A ($T_B < T_A$).
- $+0.5$ is Haldane-Anscombe continuity correction protecting against zero-division in rare event pairs.

**Classification Thresholds & Statistical Tests**:
- **Forward Directed Precedence ($A \rightarrow B$)**: $DR \ge 1.50$ with $N_{A \to B} \ge 10$ and two-sided binomial test $p < 0.01$ under the null hypothesis of equal directional precedence $H_0: P(A \to B) = 0.5$ (e.g., Disease $\rightarrow$ Drug indication; Disease $\rightarrow$ Secondary complication).
- **Reverse Directed Precedence ($B \rightarrow A$)**: $DR \le 0.67$ with $N_{B \to A} \ge 10$ and binomial $p < 0.01$ (e.g., Risk factor $\rightarrow$ Event).
- **Symmetric / Contemporaneous Association**: $0.67 < DR < 1.50$ (e.g., Chronic Comorbidity clustering, Metabolic syndrome components).
- **Indeterminate Precedence**: Pairs failing minimum support thresholds ($N_{A \to B} < 10$ and $N_{B \to A} < 10$) or failing the binomial significance gate are classified as indeterminate rather than directional.

### 2.5 Healthcare Utilization Decile Stratification (`DEC-GR-010`)
A prominent systematic confounder in observational association mining is **healthcare contact density bias**: individuals with severe multimorbidity interact frequently with the healthcare system, generating vast code counts that appear correlated purely due to shared encounter frequency.

Pipeline v57 adjusts for this measured contact density through **utilization-decile stratification**:
1. **Decile Partitioning ($U_1 \dots U_{10}$)**: Every patient in the denominator is assigned to a healthcare utilization decile based on their distinct encounter dates during their baseline observation period.
2. **Decile-Stratified Expected Co-occurrences**:
   $$E_{AB, \text{util}} = \sum_{k=1}^{10} \frac{N_{A, k} \cdot N_{B, k}}{N_k}$$
   Where $N_k$ is the total person count in decile $k$, and $N_{A,k}, N_{B,k}$ are the marginal person counts for Concept A and Concept B within decile $k$.
3. **Utilization-Stratified Lift ($Lift_{\text{util}}$)**:
   $$Lift_{\text{util}} = \frac{O_{AB}}{E_{AB, \text{util}}}$$
   Where $O_{AB}$ is the observed distinct person co-occurrence count.

*Methodological Note*: While utilization stratification attenuates confounding driven by broad contact density, residual within-decile recording patterns and unmeasured health-seeking behavior may persist and require substantive clinical evaluation.

### 2.6 Dual Lift Reporting Architecture
Per Authoritative Decision `DEC-GR-010`, TAXIS reports both lift metrics:
- **Unadjusted Person Lift ($Lift_{\text{unadj}}$)**:
   $$Lift_{\text{unadj}} = \frac{O_{AB} / N}{(N_A / N) \cdot (N_B / N)} = \frac{N \cdot O_{AB}}{N_A \cdot N_B}$$
   Measures raw observational co-occurrence relative to population independence.
- **Utilization-Stratified Lift ($Lift_{\text{util}}$)**: Measures co-occurrence adjusted for baseline encounter volume. Pairs where $Lift_{\text{unadj}} \gg 1.0$ but $Lift_{\text{util}} \approx 1.0$ serve as a diagnostic indicator of substantial utilization confounding.
- **Encounter Event Lift ($Lift_{\text{event}}$)**: Evaluates whether Concept A and Concept B occur together during the same clinical encounter ($E(A \cap B) / [E(A) \cdot E(B)]$), identifying acute episode-specific pairs.

### 2.7 Statistical Filtering & Significance Gating
To qualify for downstream LLM semantic classification and knowledge graph inclusion, candidate concept pairs must satisfy four pre-specified filtering criteria:
1. **Minimum Absolute Patient Support**: $N_{AB} \ge 100$ distinct patients ($N_{AB} \ge 50$ in small partner test runs).
2. **Unadjusted Lift Floor**: $Lift_{\text{unadj}} > 1.20$.
3. **Utilization-Stratified Lift Floor**: $Lift_{\text{util}} > 1.50$.
4. **Contingency Statistical Significance**: Cochran-Mantel-Haenszel (CMH) common odds ratio test with continuity correction, requiring $p < 0.001$.

---

## 3. Cross-Domain Intersections & Concept Standardization

OMOP CDM tables store concepts at varying levels of clinical and granular specificity. Pipeline v57 incorporates standardized vocabulary pre-processing to establish clinical grain alignment across domains:

```text
┌───────────────────────────┬───────────────────────────┬────────────────────────────────────────────────────────┐
│ Domain Intersection       │ OMOP Source Tables        │ Grain Standardization & Surrogate Key Encoding         │
├───────────────────────────┼───────────────────────────┼────────────────────────────────────────────────────────┤
│ Condition - Drug          │ condition_occurrence      │ Condition: Standard SNOMED-CT condition concepts       │
│                           │ drug_exposure             │ Drug: Active ingredient + dose form category           │
│                           │                           │ (ing_form_key via cab_vocab_all_drug_ing_form)         │
├───────────────────────────┼───────────────────────────┼────────────────────────────────────────────────────────┤
│ Condition - Measurement   │ condition_occurrence      │ Condition: Standard SNOMED-CT condition concepts       │
│                           │ measurement               │ Measurement: Packed Test + Categorical Result key      │
│                           │ observation               │ (test_concept_id * 1e9 + result_code)                  │
├───────────────────────────┼───────────────────────────┼────────────────────────────────────────────────────────┤
│ Condition - Procedure     │ condition_occurrence      │ Condition: Standard SNOMED-CT condition concepts       │
│                           │ procedure_occurrence      │ Procedure: Normalized CPT-4 / ICD-10-PCS concepts      │
│                           │                           │ (via cab_vocab_all_procedure)                          │
├───────────────────────────┼───────────────────────────┼────────────────────────────────────────────────────────┤
│ Condition - Condition     │ condition_occurrence      │ Both: Standard SNOMED-CT condition concepts            │
│                           │ condition_occurrence      │ (Annotated via cab_vocab_all_chronic_conditions)       │
├───────────────────────────┼───────────────────────────┼────────────────────────────────────────────────────────┤
│ Drug - Procedure          │ drug_exposure             │ Drug: ing_form_key surrogate concept                   │
│                           │ procedure_occurrence      │ Procedure: Normalized procedural concept               │
├───────────────────────────┼───────────────────────────┼────────────────────────────────────────────────────────┤
│ Drug - Drug               │ drug_exposure             │ Both: ing_form_key active ingredient + dose form       │
│                           │ drug_exposure             │ (Collapses brand and strength variations)              │
└───────────────────────────┴───────────────────────────┴────────────────────────────────────────────────────────┘
```

### 3.1 Drug Ingredient and Dose Form Standardization (`ing_form_key`)
Counting drugs at the clinical drug product level (e.g., individual RxNorm codes for 10mg, 20mg, 40mg tablets across brand and generic names) fragments statistical power across hundreds of sparse concepts.
- **Solution**: The engine maps all RxNorm and NDC codes to an **ingredient + dose-form category** surrogate key (`ing_form_key`) utilizing `cab_vocab_all_drug_ing_form` (947 MB lookup).
- **Example**: All oral formulations of lisinopril collapse to `lisinopril | oral tablet`, preserving therapeutic distinction from injectable or topical forms while consolidating statistical support.

### 3.2 Measurement & Observation Result Packing (`packed_key`)
OMOP CDM stores laboratory test identifiers (`measurement_concept_id`) and results (`value_as_concept_id`, `value_as_number`, `operator_concept_id`) in separate columns. An isolated test concept does not indicate pathology (e.g., ordering an HbA1c is routine; an elevated HbA1c confirms diabetes).
- **Solution**: The engine mints a deterministic 64-bit packed surrogate concept:
  $$\text{Concept ID}_{\text{packed}} = (\text{test\_concept\_id} \times 10^9) + \text{result\_code}$$
- **Result Codes**:
  - `1`: High / Abnormal Positive (above normal reference range or positive finding).
  - `2`: Normal / Negative (within reference range).
  - `3`: Low / Abnormal Negative (below normal reference range).
  - `4`: Value Recorded (quantitative lab present without categorical flag).
  - `0`: Test Performed (no quantitative result or assertion).

---

## 4. Database-Native Batch Execution Architecture

Processing billions of longitudinal record pairs across millions of patients exceeds server RAM capacity if attempted as a single join. Pipeline v57 executes as a **batched, database-native ELT workflow** orchestrated by R using `SqlRender` and `DatabaseConnector`:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                      PHASE 1: concept_ab_init.sql                      │
│   • Randomly partitions eligible persons into N batches (default N=40) │
│   • Materializes person batch assignment: all_persons_batch            │
│   • Creates empty cumulative tables: cab_s10/s20/s30/s13/s23/s33_cum   │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│               PHASE 2: concept_ab_batch.sql (Batch Loop 1..N)          │
│   • Extracts batch slice of patients (person_id IN batch k)            │
│   • Deduplicates domain events (one record per person/concept/date)    │
│   • Flags first-mention events (concept_fm_flag)                       │
│   • Computes marginals (cab_s20) and pairwise co-occurrences (cab_s30) │
│   • Appends batch counts into cumulative tables (_cum)                 │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                   PHASE 3: concept_ab_finalize.sql                     │
│   • Aggregates cumulative tables into global *_all master tables       │
│   • Computes CMH decile-adjusted expected co-occurrences (cab_s33_mh)  │
│   • Calculates Person Lift, Stratified Lift, Event Lift, OR, and DR    │
│   • Materializes final analytical export tables (cab_s55_pair_all)     │
└────────────────────────────────────────────────────────────────────────┘
```

### Phase 1: Pipeline Initialization (`concept_ab_init.sql`)
1. **Verification**: Validates existence of standard OMOP CDM v5.4 tables and the 6 project lookup tables.
2. **Stable Cohort Partitioning**: Partitions the eligible population into $N$ equal-sized, random batches using SQL `NTILE(@batch_count)` keyed on `person_id`. This table (`all_persons_batch`) remains fixed throughout execution to guarantee that patients are processed exactly once.
3. **Cumulative Table Creation**: Creates empty cumulative storage tables (`cab_s10_person_cum`, `cab_s20_marginal_cum`, `cab_s30_cum`, `cab_s13_strat_cum`, `cab_s23_strat_cum`, `cab_s33_strat_cum`).

### Phase 2: Per-Batch Processing Loop (`concept_ab_batch.sql`)
1. **Domain Event Ingestion**: Slices CDM tables for the active batch (`batch_number = @batch_number`) across condition, procedure, drug, device, measurement, and observation tables.
2. **Deduplication & First-Mention Flagging**: Deduplicates multiple occurrences on the same calendar day and flags each patient's very first lifetime occurrence of the concept (`concept_fm_flag`).
3. **Cross-Domain Join**: Joins Concept A (anchor) with Concept B (target) across domain pairs, evaluating observation dates to partition co-occurrences into:
   - Same-day events: $N_{A=B}$.
   - Forward precedence events: $N_{A \to B}$ within $[+1, +30]$, $[+1, +90]$, $[+1, +365]$, $[+1, +730]$ days.
   - Reverse precedence events: $N_{B \to A}$ within $[-730, -1]$ days.
4. **Cumulative Append**: Inserts summarized batch counts into the cumulative `_cum` tables.

### Phase 3: Global Statistical Finalization (`concept_ab_finalize.sql`)
1. **Rollup**: Sums batch-level counts into global master tables (`cab_s10_person_all`, `cab_s20_marginal_all`, `cab_s30_all`).
2. **Decile Expected Calculation**: Aggregates utilization-stratified cell counts across deciles $U_1 \dots U_{10}$ to calculate $E_{AB, \text{util}}$.
3. **Statistical Derivations**: Computes unadjusted person lift, utilization-stratified lift, event lift, odds ratios, directionality ratios, and asymptotic confidence intervals.
4. **Master Table Materialization**: Emits `cab_s55_pair_all` containing the final association metrics for all qualified concept pairs.

---

## 5. Complete Output Data Dictionary (18 Export Tables)

The pipeline produces 18 finalized relational tables in `RESULTS_SCHEMA`, structured into four operational tiers:

### Tier 1: Master Association Statistics
| Table Name | Grain | Primary Columns | Analytical Description |
|---|---|---|---|
| **`cab_s55_pair_all`** | Concept Pair ($A, B$) | `concept_id_a`, `concept_id_b`, `domain_pair`, `person_lift_unadj`, `person_lift_strat`, `event_lift`, `contingency_or`, `directionality_ratio`, `a_before_b`, `b_before_a`, `same_day_count` | Master output table per concept pair, with unadjusted and utilization-stratified lifts, directionality ratios, and temporal counts. |
| **`cab_s50_all`** | Pair $\times$ Window Interval | `concept_id_a`, `concept_id_b`, `interval_code`, `pair_person_count`, `lift_unadj`, `lift_strat` | Unpivoted longitudinal counts across follow-up intervals ($[1, 30]$, $[1, 90]$, $[1, 365]$, $[1, 730]$ days). |
| **`cab_s40_all`** | Pair $\times$ Domain | `concept_id_a`, `concept_id_b`, `pair_events`, `pair_persons`, `expected_persons_unadj` | Intermediate contingency table joining observed pair counts with marginal denominators. |
| **`cab_s30_all`** | Raw Observed Pair | `concept_id_a`, `concept_id_b`, `pair_count`, `a_before_b`, `b_before_a`, `same_day` | Raw aggregated co-occurrence counts across all batches before statistical transformation. |

### Tier 2: Denominators & Marginals
| Table Name | Grain | Primary Columns | Analytical Description |
|---|---|---|---|
| **`cab_s10_person_all`** | Global Population | `total_persons`, `total_person_days`, `total_visits`, `total_util_sum` | Denominator summary across all eligible patients meeting the 365-day wash-in criteria. |
| **`cab_s20_marginal_all`**| Single Concept | `concept_id`, `domain_id`, `marginal_persons`, `marginal_events`, `first_mention_persons` | Total patient-level and event-level prevalence for each individual Concept A and Concept B. |
| **`cab_vocab_all_output`**| Single Concept | `concept_id`, `concept_name`, `domain_id`, `vocabulary_id`, `concept_code` | Human-readable concept metadata, including decoded labels for packed lab and drug keys. |

### Tier 3: Utilization Decile Stratification
| Table Name | Grain | Primary Columns | Analytical Description |
|---|---|---|---|
| **`cab_s13_strat_all`** | Decile ($U_1 \dots U_{10}$) | `util_decile`, `person_count`, `person_days`, `annualized_visit_rate` | Denominator patient counts and person-days within each healthcare utilization decile. |
| **`cab_s23_strat_all`** | Concept $\times$ Decile | `concept_id`, `util_decile`, `marginal_persons_in_decile` | Concept marginal person counts broken down across utilization deciles. |
| **`cab_s33_strat_all`** | Pair $\times$ Decile | `concept_id_a`, `concept_id_b`, `util_decile`, `observed_persons_in_decile` | Observed co-occurrence person counts within each utilization decile (re-poolable). |
| **`cab_s33_mh_all`** | Concept Pair | `concept_id_a`, `concept_id_b`, `expected_persons_strat`, `cmh_odds_ratio` | Cochran-Mantel-Haenszel decile-adjusted expected counts and common odds ratios. |

### Tier 4: Descriptive Profiling & Process Diagnostics
| Table Name | Grain | Primary Columns | Analytical Description |
|---|---|---|---|
| **`cab_s37_lag_all`** | Concept Pair $\times$ Day | `concept_id_a`, `concept_id_b`, `lag_days`, `pair_count_at_lag` | Empirical lag decay distributions ($\pm 400$ days) for auditing temporal window validity. |
| **`cab_s38_profile_all`**| Cohort Subgroup | `subgroup_id`, `eligible_persons`, `visit_linked_fraction` | Data quality audit of visit linkage, observation spans, and record completeness. |
| **`cab_s39_pattern_all`**| Single Concept | `concept_id`, `inter_event_gap_median`, `recording_span_days` | Longitudinal concept recording patterns (recurrent chronic vs. acute isolated). |
| **`meas_obs_profile_s35_all`** | Measurement Test | `test_concept_id`, `has_num_value_frac`, `has_concept_val_frac`, `has_operator_frac` | Profiling of populated measurement fields across OMOP laboratory records. |
| **`meas_obs_attribute_s36_all`**| Measurement Test | `test_concept_id`, `attribute_concept_id`, `record_count` | Categorical result values and qualifier concepts associated with specific lab tests. |
| **`cab_timing_all`** | Pipeline Step | `batch_number`, `step_name`, `elapsed_seconds`, `avg_duration_sec` | Wall-clock execution durations per step and batch for performance auditing and tuning. |
| **`cab_process_log`** | Raw Execution Log | `batch_number`, `table_name`, `step`, `step_datetime` | Timestamped transaction log of every SQL statement executed during the run. |

---

## 6. Data Governance, Security & Network Policies

The Concept AB Mining Engine operates in strict conformity with the **TAXIS Network Data Use Term Sheet** ([`docs/governance/TAXIS_NETWORK_DATA_USE_TERM_SHEET.md`](../governance/TAXIS_NETWORK_DATA_USE_TERM_SHEET.md)):

1. **Local Behind-the-Firewall Execution**: The pipeline executes entirely within the data partner's local database environment. No patient-level records, person IDs, encounter timestamps, or narrative clinical texts ever leave the local network boundary.
2. **Concept Pair Matrix Retention (Authoritative Decision `DEC-GR-005`)**: The granular concept-pair co-occurrence matrix (`cab_s55_pair_all`) remains strictly on the partner's secure local database. It is **not** transmitted across institutions in federated Phase 1 studies.
3. **Aggregate Network Export**: For federated network benchmarking, data partners run the companion `TaxisPhenotypeEvaluation` study package, exporting strictly small-cell suppressed ($<5$) summary counts, Jaccard overlap matrices, and `PheValuator` diagnostic performance metrics: Sensitivity, Specificity, PPV, NPV, F1 Score (`Results_<databaseId>.zip`).
4. **Open-Source Licensing**: The pipeline scripts and SQL architecture are distributed under the **Apache 2.0** open-source license. Study documentation is licensed under **Creative Commons Attribution 4.0 International (CC-BY-4.0)**.

---

## 7. Study Leadership & Academic Citations

If you utilize the Concept AB Mining Engine architecture or association metrics in your research, please cite:

> Bandeian SH, Rao G, Grannis S, Overhage JM. *TAXIS: Building an OMOP-Native Clinical Relationship Layer to Support Reusable OHDSI Analytics*. 2026 OHDSI Global Symposium Collaborator Showcase (Entry #127), New Brunswick, NJ, October 2026.

### Foundational References:
1. **Bandeian SH, Tompkins CP, Davison A.** A Future Health Care Analytic System: Part 1—What the Destination Looks Like & Part 2—Building Blocks and Implementation Roadmap. In: *Healthcare Information Management Systems: Cases, Strategies, and Solutions*. 5th ed. Cham: Springer; 2022.
2. **Rao GA, et al.** OHDSI Phenotype Library Version 3.0: Autonomous Governance and Agentic Clinical Cohort Engineering. *OHDSI Global Symposium 2026 Proceedings*; 2026.
3. **Ostropolets A, et al.** PHOEBE 2.0: selecting the right concept sets for the right patients using lexical, semantic, and data-driven recommendations. *OHDSI Symposium*; 2022. (Available: https://www.ohdsi.org/wp-content/uploads/2022/10/6-Ostropolets_Phoebe2.0-abstract.pdf).
4. **Swerdel JN, et al.** PheValuator: Development and evaluation of a phenotype algorithm evaluator. *J Biomed Inform*. 2019;97:103258.
5. **Shoaibi A, Ostropolets A, Weaver J, Rao G, et al.** Variation in phenotype definitions in observational clinical research: a review of three conditions. *AMIA Annu Symp Proc*. 2024.
6. **Shoaibi A, Ostropolets A, Murphy JD, Rao GA, et al.** Clinical Descriptions as Semantic Anchors: A Best Practice in OHDSI Phenotype Development. *OHDSI Phenotype Development and Evaluation Workgroup Consensus Statement*; 2025.
7. **Rao GA, et al.** Neuro-Symbolic Conceptual Workflows for Phenotyping in Observational Research: The Proposer-Validator Architecture. *OHDSI Phenotype Development and Evaluation Workgroup*; 2026.
