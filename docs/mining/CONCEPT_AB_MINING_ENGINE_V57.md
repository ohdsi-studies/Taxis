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
> • Stephen H. Bandeian, MD, JD – Principal Investigator, Johns Hopkins University School of Medicine (Original SQL & Analytic Code Author)  
> • J. Marc Overhage, MD, PhD – Co-Principal Investigator, The Overhage Group / Indiana University School of Medicine  
> • Gowtham Rao, MD, PhD – Investigator, [CoReason, Inc.](https://www.coreason.ai) USA; OHDSI (Phenotype working group)  
> • Shaun Grannis, MD, MS – Investigator, Regenstrief Institute / Indiana University School of Medicine  
>  
> **Original Scientific & Analytic Authorship**:  
> All SQL scripts (`concept_ab_init.sql`, `concept_ab_batch.sql`, `concept_ab_finalize.sql`), database architectures, 40-batch random partitioning strategies, measurement key packing schemes, continuity-corrected directionality ratios, and original analytic algorithms embodied in Pipeline v57 were conceived, designed, and authored by **Stephen H. Bandeian, MD, JD** (Principal Investigator, Johns Hopkins University School of Medicine).

---

## 1. Executive Summary & Epidemiological Purpose

Standard biomedical terminologies and controlled ontologies (e.g., SNOMED-CT, RxNorm, LOINC) provide hierarchical structures rooted in formal nosology, chemical taxonomy, and laboratory analytes. They delineate taxonomic classification (e.g., classifying type 2 diabetes mellitus as an endocrine disorder or metformin as an oral biguanide). However, these ontologies were not engineered to capture the empirical dynamics of longitudinal healthcare delivery. Controlled vocabularies do not define which diagnostic laboratory assays are routinely ordered to confirm suspected pathology, which pharmacotherapies constitute empirical first-line regimens, or which prodromal signs and symptoms precede definitive diagnostic recording. Empirical audits of longitudinal patient records demonstrate that standard ontologies document relational links for merely 0.44% of concept pairs that frequently co-occur in observational patient care ($N_{AB} \ge 100$), confirming that standard terminologies were engineered for nosology rather than operational care patterns.

The **TAXIS Concept AB Association Mining Engine (Pipeline v57)** discovers and quantifies these empirical clinical relationships directly from longitudinal observational data. Conceived, designed, and authored by Dr. Stephen H. Bandeian, the engine analyzes longitudinal patient records in the OMOP Common Data Model (CDM v5.4) across six cross-domain intersections:
1. `Condition - Drug`
2. `Condition - Measurement`
3. `Condition - Procedure`
4. `Condition - Condition`
5. `Drug - Procedure`
6. `Drug - Drug`

In our production benchmark on the Indiana Network for Patient Care (INPC), the engine analyzed 2.16 million patients across 11.3 million person-years of observation, processing 1.88 billion clinical events to identify 1.9 million graded clinical concept pairs. The primary mission of the TAXIS initiative is engineering, releasing, and maintaining TAXIS as an international OHDSI network study. By executing standardized association mining across federated network partners, TAXIS computes comprehensive summary datasets of concept A–B pairs—quantifying joint co-occurrence counts, temporal sequence directionality, and crude and healthcare utilization-stratified lift metrics—which are disseminated as an open, public scientific resource for the observational research community. In turn, translational researchers can leverage this public resource to support computable phenotyping, negative control discovery, and causal inference.

---

## 2. Formal Definitions, Mathematical Formulations & Statistical Estimands

Statistical discovery in longitudinal observational healthcare databases requires rigorous epidemiological counting rules and clear mathematical definitions to differentiate authentic clinical associations from healthcare utilization confounding (contact density bias), coding collinearity, and surveillance artifacts. 

This section defines the fundamental entities (**Concept A**, **Concept B**, and **Concept AB**), details their longitudinal measurement intervals and occurrence grains, and specifies every mathematical equation implemented in the released OHDSI T-SQL codebase (`inst/sql/sql_server/*.sql`) and Dr. Stephen H. Bandeian's foundational study protocol.

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

---

### 2.1 Foundational Definitions: Concept A, Concept B, and Concept AB

#### Concept A (Anchor / Index Concept)
- **Definition**: The reference or antecedent clinical concept in a candidate clinical pair, representing a patient's index presentation or exposure within an eligible observational horizon.
- **Attributes**:
  - `concept_a`: Standard OMOP Concept ID (or 64-bit packed surrogate measurement key).
  - `concept_name_a`: Standard clinical concept name.
  - `src_a`: Domain code (e.g., `10` = Condition, `20` = Procedure, `30` = Device, `40` = Drug, `60` = Measurement Test, `61` = Measurement Result).
  - `pers_a`: Total distinct patients presenting with Concept A during their eligible observation period.
  - `obs_a_act`: Total lifetime event instances (mentions) of Concept A across all patients.
  - `mentions_per_person_a`: Mean occurrence density ($\text{obs\_a\_act} / \text{pers\_a}$).

#### Concept B (Target / Associated Concept)
- **Definition**: The target or consequent clinical concept evaluated for empirical co-occurrence, sequential lag, and temporal precedence relative to Concept A.
- **Attributes**:
  - `concept_b`: Standard OMOP Concept ID (or packed surrogate key).
  - `concept_name_b`: Standard clinical concept name.
  - `src_b`: Domain code of Concept B.
  - `pers_b`: Total distinct patients presenting with Concept B.
  - `obs_b_act`: Total lifetime event instances of Concept B.
  - `mentions_per_person_b`: Mean occurrence density ($\text{obs\_b\_act} / \text{pers\_b}$).

#### Concept AB (Longitudinal Concept Pair Association)
- **Definition**: The empirical pairwise co-occurrence and temporal association observed between Concept A and Concept B in a patient's longitudinal record within a predefined observational window ($W = \pm 30$ days or $\pm 365$ days).
- **Relational Domain Permutations (`pair_type`)**:
  - Encoded as a 4-digit integer: $\text{pair\_type} = \text{src}_A \times 100 + \text{src}_B$.
  - In directional cross-domain pairs (e.g., `1040` Condition $\to$ Drug, `1020` Condition $\to$ Procedure), Domain A systematically anchors Domain B.
  - In symmetric within-domain pairs (e.g., `1010` Condition $\leftrightarrow$ Condition, `4040` Drug $\leftrightarrow$ Drug), the batch processing engine breaks symmetry by enforcing $\text{concept\_a} < \text{concept\_b}$ to eliminate 50% redundant joins. In finalization (`concept_ab_finalize.sql`), pairs are symmetrically reflected into both orientations $(A, B)$ and $(B, A)$ so that either concept can be queried as Concept A with exact mathematically consistent directional metrics.

#### Longitudinal Temporal Intervals (`interval_code`)
Concept AB events are partitioned into three mutually exclusive temporal intervals based on the elapsed calendar days $\Delta t = t_B - t_A$ between the event date of Concept B ($t_B$) and Concept A ($t_A$):
1. **Interval 1: Same-Day Contemporaneous ($\Delta t = 0$)**:
   - Both concepts documented on the exact same calendar date ($t_A = t_B$).
   - Captured in SQL as `obs_same_day` and `pers_same_day`.
   - Also tracks the same-visit fraction (`same_visit_frac`), recording the proportion sharing an identical `visit_occurrence_id`.
   - **Critical Rule**: Strictly excluded from forward ($N_{A \to B}$) and reverse ($N_{B \to A}$) directional calculations to prevent concurrent billing bundles from distorting temporal precedence.
2. **Interval 2: Forward Precedence / Sequential Target ($+1 \le \Delta t \le +W$)**:
   - Concept B occurs after Concept A within the prospective window $W$ (e.g., 1 to 30 days, or 1 to 365 days).
   - Captured in SQL as `obs_after` and `pers_after` (representing $N_{A \to B}$).
3. **Interval 3: Reverse Precedence / Antecedent Target ($-W \le \Delta t \le -1$)**:
   - Concept B occurs before Concept A within the retrospective window (Concept A follows Concept B).
   - Captured in SQL as `obs_before` and `pers_before` (representing $N_{B \to A}$).

#### Occurrence Granularities (`grain`)
To account for repetitive mentions of chronic conditions versus incident presentations, Pipeline v57 stratifies event counting across four distinct occurrence grains:
- **`all` (All Mentions)**: Evaluates all documented occurrences of Concept A and Concept B without deduplication across dates.
- **`fma` (First Mention A)**: Restricts Concept A to the patient's earliest lifetime occurrence ($t_A = t_{A, \text{first}}$), with all occurrences of B.
- **`fmb` (First Mention B)**: Evaluates all occurrences of Concept A followed by the patient's earliest lifetime occurrence of Concept B ($t_B = t_{B, \text{first}}$). This grain is essential for assessing newly diagnosed acute outcomes or incident adverse drug reactions.
- **`fmab` (First Mention Both)**: Evaluates only the pair of first lifetime occurrences for both Concept A and Concept B.
- **`fmab_inc` (Incident First Mention)**: Restricts `fmab` to patients possessing $\ge 365$ days of prior continuous observation before the first mention.

---

### 2.2 Baseline Denominators & Marginal Background Expectation

Let:
- $N_{\text{total}}$: Total distinct persons in the target population denominator (`total_persons`).
- $T_{\text{total}}$: Total longitudinal person-days of observation (`total_person_days`).
- $N_A, N_B$: Distinct person counts for Concept A and Concept B (`pers_a`, `pers_b`).
- $O_A, O_B$: Total event counts (mentions) for Concept A and Concept B (`obs_a_act`, `obs_b_act`).
- $W$: The half-window parameter in days (e.g., 30 or 365 days).
- $w$: The specific interval width in days ($w = 1$ for same-day; $w = W$ for forward or reverse windows; $w = 2W + 1$ for the complete bilateral window).

#### Person-Level Expected Co-occurrences ($E_{\text{pers}}$)
Under the null hypothesis of statistical independence across patients, the expected number of distinct persons exhibiting co-occurrence within a bilateral window of width $2W + 1$ is derived from joint marginal prevalence:

$$
E_{\text{pers}} = \frac{N_A \cdot N_B}{N_{\text{total}}} \cdot \frac{w}{2W + 1}
$$

*SQL Implementation (`concept_ab_finalize.sql`, lines 423–427)*:
```sql
cast(a.pers_a * 1.0 * a.pers_b * 1.0 * a.win_w / 
  nullif(a.total_persons * 1.0 * (2.0 * @window_days + 1.0), 0.0) as float) as pers_exp
```

#### Event-Level / Poisson Exposure Expected Co-occurrences ($E_{\text{obs}}$)
Under a Poisson process where events occur continuously at background marginal rates $\lambda_A = O_A / T_{\text{total}}$ and $\lambda_B = O_B / T_{\text{total}}$, the expected number of pairwise co-occurrences within an observation interval of $w$ days is:

$$
E_{\text{obs}} = \frac{O_A \cdot O_B \cdot w}{T_{\text{total}}}
$$

*SQL Implementation (`concept_ab_finalize.sql`, lines 406–410)*:
```sql
cast(a.obs_a_act * 1.0 * a.obs_b_act * 1.0 * a.win_w / 
  nullif(a.total_person_days * 1.0, 0.0) as float) as obs_exp
```

---

### 2.3 Healthcare Utilization Confounding & Decile-Stratified Expected ($E_{\text{MH}}$)

A critical vulnerability in real-world EHR mining is **healthcare utilization confounding** (contact density bias). Patients with multimorbid chronic conditions generate frequent ambulatory visits, inpatient admissions, and diagnostic orders. Consequently, unrelated medical codes show massive spurious statistical lift simply because high-utilizer patients are observed more frequently across all domains.

To eliminate contact density bias without discarding multimorbid patients, Pipeline v57 stratifies the entire population into 10 utilization deciles $k \in \{1, \dots, 10\}$ based on each patient's total count of distinct clinical encounter dates:
- $N_k$: Total persons in utilization decile $k$.
- $T_k$: Total person-days of observation in utilization decile $k$ (`person_days_in_decile`).
- $O_{A, k}, O_{B, k}$: Marginal event counts for Concepts A and B within decile $k$.
- $O_{AB, k}$: Observed pairwise co-occurrences in decile $k$.

Within each decile stratum $k$, expected co-occurrences are computed from that decile's internal event rates:

$$
E_k = \frac{O_{A, k} \cdot O_{B, k} \cdot (2W + 1)}{T_k}
$$

Summing across all 10 deciles yields the **Cochran-Mantel-Haenszel (CMH) Decile-Adjusted Expected Count** ($E_{\text{MH}}$):

$$
E_{\text{MH}} = \sum_{k=1}^{10} E_k = \sum_{k=1}^{10} \frac{O_{A, k} \cdot O_{B, k} \cdot (2W + 1)}{T_k}
$$

*SQL Implementation (`cab_s33_mh_all`, lines 1025–1045)*:
```sql
-- expected within each decile, from that decile's own rates
(m1.obs_act * 1.0 * m2.obs_act * 1.0 * (2.0 * @window_days + 1.0) / 
  nullif(base.person_days_in_decile * 1.0, 0.0)) as exp_k
-- sum across deciles
cast(sum(a.exp_k) as float) as obs_ab_exp_mh
```

The mean utilization decile for a concept pair is tracked as:

$$
\bar{D}_{AB} = \frac{\sum_{k=1}^{10} k \cdot O_{AB, k}}{\sum_{k=1}^{10} O_{AB, k}}
$$

Pairs with $\bar{D}_{AB} > 8.0$ are heavily concentrated in extreme healthcare utilizers, prompting stratified adjustment.

---

### 2.4 Lift Metrics & Asymptotic Poisson Confidence Intervals

#### Crude Event Lift ($\text{Lift}_{\text{obs}}$) and Person Lift ($\text{Lift}_{\text{pers}}$)
Lift quantifies the ratio of observed co-occurrences relative to the expected frequency under statistical independence:

$$
\text{Lift}_{\text{obs}} = \frac{O_{AB}}{E_{\text{obs}}}, \quad \text{Lift}_{\text{pers}} = \frac{N_{AB}}{E_{\text{pers}}}
$$

- $\text{Lift} = 1.0$: Observed frequency equals marginal expectation (no statistical association).
- $\text{Lift} > 1.0$: Positive co-occurrence enrichment.
- $\text{Lift} < 1.0$: Negative co-occurrence (inverse or mutually exclusive relationship).

#### Utilization-Stratified Lift ($\text{Lift}_{\text{strat}}$)
Adjusts observed co-occurrence for healthcare contact density using the CMH decile-adjusted expected count:

$$
\text{Lift}_{\text{strat}} = \frac{O_{AB}}{E_{\text{MH}}}
$$

When a pair exhibits $\text{Lift}_{\text{obs}} \gg 1.0$ but $\text{Lift}_{\text{strat}} \approx 1.0$, the apparent correlation is driven entirely by high healthcare contact density rather than biological or clinical association.

#### Interval-Specific Lifts in `cab_s55_pair_all`
The master association table pivots lift across temporal intervals:
- $\text{Lift}_{\text{same\_day}} = O_{\text{same\_day}} / E_{\text{same\_day}}$ (Contemporaneous diagnostic / procedural packaging).
- $\text{Lift}_{\text{after}} = O_{\text{after}} / E_{\text{after}}$ (Prospective longitudinal association $A \to B$).
- $\text{Lift}_{\text{before}} = O_{\text{before}} / E_{\text{before}}$ (Retrospective antecedent association $B \to A$).
- $\text{Lift}_{\text{after, fmb}} = O_{\text{after, fmb}} / E_{\text{after, fmb}}$ (Incident outcome presentation).

#### Exact Asymmetrical Poisson Confidence Intervals (Wilson-Hilferty Transformation)
Because event counts follow a Poisson distribution that is skewed at lower frequencies, standard Gaussian Wald intervals ($O \pm 1.96 \sqrt{O}$) yield severe under-coverage. Pipeline v57 implements the exact **Wilson-Hilferty (1931) cube-root transformation** for Poisson limits, providing robust 95% confidence intervals:

$$
\text{Lift}_{\text{lower}} = \frac{O_{AB} \cdot \left(1 - \frac{1}{9 \cdot O_{AB}} - \frac{1.96}{3 \cdot \sqrt{O_{AB}}}\right)^3}{E_{\text{obs}}}
$$

$$
\text{Lift}_{\text{upper}} = \frac{(O_{AB} + 1) \cdot \left(1 - \frac{1}{9 \cdot (O_{AB} + 1)} + \frac{1.96}{3 \cdot \sqrt{O_{AB} + 1}}\right)^3}{E_{\text{obs}}}
$$

*SQL Implementation (`concept_ab_finalize.sql`, lines 1177–1180)*:
```sql
case when s1.obs > 0 and s1.obs_exp > 0
  then cast(round((s1.obs * power(1.0 - 1.0/(9.0*s1.obs) - 1.96/(3.0*sqrt(s1.obs*1.0)), 3)) / s1.obs_exp, 3) as float)
  else null end as obs_lift_ci_lower,
case when s1.obs >= 0 and s1.obs_exp > 0
  then cast(round(((s1.obs + 1.0) * power(1.0 - 1.0/(9.0*(s1.obs+1.0)) + 1.96/(3.0*sqrt(s1.obs+1.0)), 3)) / s1.obs_exp, 3) as float)
  else null end as obs_lift_ci_upper
```

---

### 2.5 Directionality Metrics: Directional Share (`dir_ab`) vs. Directionality Ratio ($DR$)

To evaluate whether Concept A reliably precedes Concept B or vice versa, the engine evaluates the asymmetry between forward precedence ($O_{\text{after}} = N_{A \to B}$) and reverse precedence ($O_{\text{before}} = N_{B \to A}$).

#### Directional Proportion (`dir_ab` in SQL)
In `inst/sql/sql_server/concept_ab_finalize.sql` (line 1350), the database materializes the directional share:

$$
\text{dir\_ab} = \frac{O_{\text{after}}}{O_{\text{after}} + O_{\text{before}}}
$$

- $\text{dir\_ab} = 1.0$: 100% of non-same-day co-occurrences occur with Concept A preceding Concept B.
- $\text{dir\_ab} = 0.50$: Perfect temporal symmetry ($N_{A \to B} = N_{B \to A}$).
- $\text{dir\_ab} = 0.0$: 100% of non-same-day co-occurrences occur with Concept B preceding Concept A.

#### Continuity-Corrected Directionality Ratio ($DR$)
In the foundational study protocol and analytical design, temporal precedence is expressed as the directional odds ratio:

$$
DR = \frac{N_{A \to B}}{N_{B \to A}} = \frac{O_{\text{after}}}{O_{\text{before}}}
$$

To prevent division by zero in sparse cells and provide Bayesian shrinkage toward symmetry, the protocol specifies a **Haldane-Anscombe continuity correction** (+0.5 added to numerator and denominator):

$$
DR_{\text{corrected}} = \frac{N_{A \to B} + 0.5}{N_{B \to A} + 0.5} = \frac{O_{\text{after}} + 0.5}{O_{\text{before}} + 0.5}
$$

#### Mathematical Equivalence & Translation
The database metric `dir_ab` and the protocol metric $DR$ represent identical underlying empirical evidence through a monotonic logit transformation:

$$
\text{dir\_ab} = \frac{DR}{DR + 1}, \quad DR = \frac{\text{dir\_ab}}{1 - \text{dir\_ab}}
$$

| Relationship Pattern | Empirical Observation | Directional Share (`dir_ab`) | Continuity-Corrected $DR$ | Clinical Interpretation |
|---|---|---|---|---|
| **Forward Precedence ($A \to B$)** | $O_{\text{after}} \gg O_{\text{before}}$ | $\ge 0.60$ | $\ge 1.50$ ($p < 0.01$) | Indication $\to$ Drug, Disease $\to$ Complication |
| **Symmetric / Contemporaneous** | $O_{\text{after}} \approx O_{\text{before}}$ | $0.40 \le \text{dir\_ab} \le 0.60$ | $0.67 < DR < 1.50$ | Chronic Comorbidity, Metabolic Cluster |
| **Reverse Precedence ($B \to A$)** | $O_{\text{after}} \ll O_{\text{before}}$ | $\le 0.40$ | $\le 0.67$ ($p < 0.01$) | Antecedent Risk Factor $\to$ Target Outcome |
| **No Directional Precedence** | $O_{\text{after}} = 0, O_{\text{before}} = 0$ | `NULL` | Undefined / Suppressed | Pure same-day co-occurrence ($\Delta t = 0$) |

---

### 2.6 Contingency Tables & Odds Ratio Formulations

In addition to lift and directionality, Dr. Bandeian's protocol outlines pairwise association testing via 2×2 contingency matrices across the population of $N_{\text{total}}$ persons:

```text
┌─────────────────────────────────┬───────────────────┬───────────────────┬───────────────────┐
│ Contingency Partition           │ Concept B Present │ Concept B Absent  │ Marginal Total    │
├─────────────────────────────────┼───────────────────┼───────────────────┼───────────────────┤
│ Concept A Present               │ NAB               │ NA - NAB          │ NA                │
│ Concept A Absent                │ NB - NAB          │ Ntotal - NA-NB+NAB│ Ntotal - NA       │
├─────────────────────────────────┼───────────────────┼───────────────────┼───────────────────┤
│ Marginal Total                  │ NB                │ Ntotal - NB       │ Ntotal            │
└─────────────────────────────────┴───────────────────┴───────────────────┴───────────────────┘
```

#### Crude Odds Ratio ($OR_{\text{crude}}$)
The ratio of the odds of having Concept B given Concept A compared to the odds of having Concept B in the absence of Concept A:

$$
OR_{\text{crude}} = \frac{N_{AB} \cdot (N_{\text{total}} - N_A - N_B + N_{AB})}{(N_A - N_{AB}) \cdot (N_B - N_{AB})}
$$

#### Haldane-Anscombe Smoothed Odds Ratio ($OR_{\text{Haldane}}$)
Adding +0.5 to each cell ensures numerical stability and eliminates zero-frequency bias:

$$
OR_{\text{Haldane}} = \frac{(N_{AB} + 0.5) \cdot (N_{\text{total}} - N_A - N_B + N_{AB} + 0.5)}{(N_A - N_{AB} + 0.5) \cdot (N_B - N_{AB} + 0.5)}
$$

With standard error of $\ln(OR)$:

$$
\text{SE}(\ln(OR)) = \sqrt{\frac{1}{N_{AB}+0.5} + \frac{1}{N_A - N_{AB}+0.5} + \frac{1}{N_B - N_{AB}+0.5} + \frac{1}{N_{\text{total}} - N_A - N_B + N_{AB}+0.5}}
$$

#### Cochran-Mantel-Haenszel (CMH) Decile-Stratified Common Odds Ratio ($OR_{\text{MH}}$)
To adjust for healthcare utilization confounding across the 10 deciles $k \in \{1, \dots, 10\}$:

$$
OR_{\text{MH}} = \frac{\sum_{k=1}^{10} \frac{N_{AB, k} \cdot (N_k - N_{A,k} - N_{B,k} + N_{AB, k})}{N_k}}{\sum_{k=1}^{10} \frac{(N_{A, k} - N_{AB, k}) \cdot (N_{B, k} - N_{AB, k})}{N_k}}
$$

*Architecture Note*: In the database-native design, the T-SQL pipeline pre-aggregates and materializes the decile-stratified contingency components in table `cab_s33_strat_all` (`pair_type, concept_a, concept_b, util_decile, obs_ab_act, obs_ab_act_fmab, pers_ab`) and computes the stratified expected count in `cab_s33_mh_all`. This allows downstream consumers and federated meta-analytic drivers to compute the exact CMH common odds ratio directly from site aggregate exports without requiring patient-level data access.

---

### 2.7 Statistical Filtering & Candidate Gating Thresholds

To qualify for downstream clinical knowledge graph inclusion and network dissemination, candidate concept pairs must satisfy four pre-specified quality criteria:
1. **Minimum Patient Support**: $N_{AB} \ge 100$ distinct patients in production runs ($N_{AB} \ge 50$ in local site validation runs).
2. **Unadjusted Lift Floor**: $\text{Lift}_{\text{unadj}} > 1.20$.
3. **Utilization-Stratified Lift Floor**: $\text{Lift}_{\text{strat}} > 1.50$.
4. **Contingency Statistical Significance**: Cochran-Mantel-Haenszel (CMH) common odds ratio test with continuity correction requiring $p < 0.001$.
5. **Mandatory Cell Suppression**: Any count $< 5$ is suppressed to $-1$ to strictly guarantee patient privacy under HIPAA and GDPR.

---

### 2.8 The "Bill of Materials" (BOM) Nested Process-of-Care Architecture

Clinical care is not a flat sequence of disconnected billing codes; it is a **nested hierarchy of clinical processes and subprocesses**, directly analogous to a manufacturing **Bill of Materials (BOM)** (e.g., how an aircraft or automobile is assembled from assemblies, subassemblies, and components). To capture this reality, the TAXIS process-of-care architecture organizes care into three hierarchical tiers:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                   LEVEL 1 (L1): PROBLEM CARE EPISODE                   │
│   • Triggered by index recognition of an illness, injury, or risk      │
│   • Spans initial presentation, evaluation, treatment, and follow-up   │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Orchestrates
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                   LEVEL 2 (L2): PROCEDURAL ANCHOR                      │
│   • Principal unit of care per encounter (inpatient or ambulatory)     │
│   • Ranked deterministically via clinical invasiveness (CMS RBCS/BTOS) │
│     (Major Surgery > Inpatient > Emergency > Therapy > Imaging > Lab)  │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Bundles Supporting Care
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                  SUPPORTING SERVICE NESTED HIERARCHY                   │
│   • Pre-Service Suitability & Risk: [-30, 0] days before anchor        │
│   • Intra-Service Support: Anesthesia, perfusion, vein harvest, ECG    │
│   • Post-Service Surveillance: [0, +90] days recovery & complications  │
└────────────────────────────────────────────────────────────────────────┘
```

This BOM framework allows researchers to evaluate whether an entire process of care was completed safely and appropriately, distinguishing principal clinical interventions from peripheral supporting services.

---

### 2.9 Concept Granularity: Reconciling Anchor Concepts and Atomic Codes

A core methodological tension in designing the Concept AB engine was balancing **concept aggregation** against **atomic code specificity**:
* **The Case for "Anchor Concepts"**: Grouping fragmented clinical variations (e.g., rolling 120 minor variants of Type 2 Diabetes into a single anchor concept) is a mathematical necessity to avoid combinatorial explosion and prevent spurious temporal noise.
* **The Case for Atomic Granularity**: Clinical informaticians require granular atomic codes for community trust and clinical fidelity—for example, distinguishing between a mild lateral malleolar ankle fracture (which correlates with a plain radiograph) versus an open trimalleolar fracture (which correlates with pre-operative CT imaging, surgical reduction, and hardware immobilization).
* **The Reconciled Solution**: Pipeline v57 supports **dual processing**. Temporal associations are mined at both the aggregated anchor level (to identify macro clinical pathways) and at the atomic concept level (to preserve clinical nuances). The threat of database combinatorial explosion is controlled by enforcing strict minimum co-occurrence and significance thresholds ($N_{AB} \ge 100$, $\text{Lift}_{\text{strat}} \ge 1.50$), safely pruning noisy micro-variants while preserving high-yield clinical distinctions.

---

### 2.10 Empirical LOINC Measurement ↔ SNOMED Procedure Crosswalking

Standard biomedical vocabularies maintain an architectural separation between orders and results:
* **SNOMED-CT / CPT**: Encodes the **procedure or order**—the clinical *act* of measuring (e.g., ordering a fasting plasma glucose test).
* **LOINC**: Encodes the **discrete result**—the numerical value or analyte level (e.g., blood glucose = 142 mg/dL).

In routine electronic health records, provider orders are rarely coded in SNOMED, and standard terminologies lack an official, granular crosswalk connecting the procedure order to its specific resulting LOINC measurement values. Pipeline v57 resolves this ontology gap empirically: by evaluating longitudinal co-occurrences between measurements and clinical findings within a $\pm 60$-day window, the mining engine discovers which discrete laboratory results and abnormal findings systematically accompany specific disorders and clinical interventions directly from real-world data.

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

### 3.1 Standardizing Medications by Ingredient and Dose Form (`ing_form_key`)
Evaluating medication exposures across observational healthcare databases requires reconciling brand, packaging, and strength variations that otherwise dilute statistical power across sparse RxNorm concepts. Tracking discrete dosages and product variations (e.g., separate codes for 10mg, 20mg, and 40mg tablets of lisinopril) fragments counts into low-frequency cells. Pipeline v57 projects all RxNorm clinical drug, branded drug, and NDC codes to an active ingredient plus clinical dose-form classification (`ing_form_key`) via lookup table `cab_vocab_all_drug_ing_form`. For example, oral solid formulations of lisinopril collapse into a unified clinical entity: `lisinopril | oral tablet`. This harmonization aggregates statistical support across millions of exposures while preserving clinically critical distinctions between oral, parenteral, and topical administration routes.

### 3.2 Packing Diagnostic Tests and Interpreted Results (`packed_key`)
Within the OMOP Common Data Model, diagnostic laboratory assays (`measurement_concept_id`) and quantitative or qualitative outcomes (`value_as_concept_id`, `value_as_number`) reside in separate relational attributes. However, evaluating diagnostic test occurrence in isolation conflates routine screening with confirmed pathological findings (e.g., ordering glycated hemoglobin for routine screening versus documenting a markedly elevated HbA1c confirming diabetes mellitus). To evaluate diagnostic associations with appropriate clinical specificity, the engine couples the measurement test concept with its categorical clinical interpretation into a deterministic 64-bit composite integer key:
$$\text{Concept ID}_{\text{packed}} = (\text{test\_concept\_id} \times 10^9) + \text{result\_code}$$

Categorical interpretations are standardized into five clinical categories:
- **Code 1 (Abnormal High / Positive Finding)**: Exceeds upper reference limit or indicates positive qualitative finding.
- **Code 2 (Normal Reference / Negative Finding)**: Within normal physiological reference interval.
- **Code 3 (Abnormal Low / Negative Finding)**: Below lower reference limit.
- **Code 4 (Numeric Value Recorded)**: Quantitative laboratory measurement recorded without explicit reference range flag.
- **Code 0 (Test Performed)**: Diagnostic assay performed without recorded qualitative or quantitative result.

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

## 5. Empirical Benchmark: Indiana Network for Patient Care (INPC) 2.16M Patient Run

The Concept AB Mining Engine (Pipeline v57) was executed across the **Indiana Network for Patient Care (INPC)** OMOP CDM v5.4 instance at Indiana University / Regenstrief Institute by Dr. Stephen H. Bandeian, MD, JD. The empirical results below document the scale, domain coverage, pair-space density, temporal dynamics, semantic distance, statistical lift distributions, and independent clinician/LLM validation.

### 5.1 Headline Data Universe (Table 1)
The production execution surveyed over 2.15 million longitudinal patients across more than 11.2 million person-years of observation, capturing 1.88 billion clinical fact events.

| Metric Description | Parameter Name | Production INPC Value | Methodological / Translational Context |
|---|---|---|---|
| **Eligible Cohort Size** | `n_persons` | **2,157,525** | Patients meeting baseline wash-in ($\ge 365$ days continuous observation). |
| **Observation Volume** | `person_years` | **11,299,055** | Longitudinal follow-up across primary, secondary, and tertiary care. |
| **Concept Universe** | `n_distinct_concepts` | **95,968** | Standard concepts surveyed across all 8 OMOP clinical domains. |
| **Pair-Type Categories** | `n_pair_type_categories` | **24** | Distinct cross-domain and within-domain pair permutations. |
| **Observed Concept Pairs** | `n_observed_concept_pairs` | **14,233,528** | Pairs with sufficient co-occurrence support ($N_{AB} \ge 5$). |
| **Event-Pair Observations** | `event_pair_observations` | **36,053,079,999** | Total pairwise event co-occurrences within the longitudinal window. |
| **Person-Pair Observations**| `person_pair_observations`| **4,007,091,065** | Total distinct-patient pairwise co-occurrence instances. |
| **Total Domain Fact Events**| `total_events` | **1,882,277,314** | Fact records ingested across conditions, drugs, labs, and procedures. |
| **Screened Candidate Pairs**| `screened_candidates` | **~5,520,000** | High-support pairs ($N_{AB} \ge 100$) prioritized for downstream analysis. |
| **Graded Knowledge Edges** | `graded_edges` | **~1,900,000** | Statistically validated edges qualified for clinical knowledge graph. |

*Historical Benchmark Note*: An earlier exploratory pilot run (documented in `cab_summary_tables.docx`) evaluated 1,035,846 patients and 87,963 concepts yielding 11,705,143 observed pairs. The production INPC run expanded the cohort to 2,157,525 patients, increasing event-pair observations to 36.1 billion while verifying that relative pair-type distributions, sparsity rates, and lift proportions remained stable across cohort scaling.

---

### 5.2 Concept Universe by OMOP Domain (Table 2)
The surveyed concept space spans standard clinical concepts across 8 OMOP domains, utilizing the surrogate key packing architecture for laboratory measurements and observations.

| Domain Code (`src`) | Domain Name (`src_t`) | Distinct Concepts (`n_distinct_concepts`) | Persons with Concept (`n_persons_with_concept`) | Event Volume (`n_events`) | Domain Representation & Standardization Grain |
|---|---|---|---|---|---|
| **10** | `condition` | 12,766 | 31,876,797 | 81,207,522 | Standard SNOMED-CT clinical condition concepts |
| **20** | `procedure` | 7,385 | 8,483,084 | 15,854,387 | Standard CPT-4, HCPCS, and ICD-10-PCS concepts |
| **30** | `device` | 20 | 139,167 | 453,915 | Implantable and diagnostic medical devices |
| **40** | `drug` | 3,280 | 11,653,170 | 48,301,645 | Active ingredient + dose form category (`ing_form_key`) |
| **50** | `obs test` | 1,587 | 8,944,058 | 56,188,358 | Observation test concepts (LOINC / SNOMED) |
| **51** | `obs result` | 39,195 | 42,030,298 | 103,114,586 | Packed observation test + result surrogate keys |
| **60** | `meas test` | 8,872 | 143,285,037 | 785,143,433 | Laboratory measurement test concepts (LOINC) |
| **61** | `meas result` | 22,886 | 173,219,636 | 792,013,468 | Packed laboratory test + result surrogate keys |
| **9999** | **ALL DOMAINS** | **95,968** | **419,631,247** | **1,882,277,314** | **Census across all 8 OMOP fact domains** |

---

### 5.3 Observed Concept Pairs by Pair-Type (Table 3)
The 14,233,528 observed pairs span 24 distinct pair-type permutations, backed by 36.1 billion event-pair co-occurrences and 4.01 billion person-pair observations.

| Pair Code (`pair_type`) | Domain Intersection (`pair_type_name`) | Observed Pairs (`n_observed`) | Event-Pair Observations | Person-Pair Observations | Distinct A Concepts | Distinct B Concepts |
|---|---|---|---|---|---|---|
| **1010** | `condition \| condition` | 879,487 | 537,558,118 | 77,784,598 | 9,236 | 9,663 |
| **1020** | `condition \| procedure` | 472,011 | 179,918,275 | 26,971,621 | 8,202 | 4,852 |
| **1030** | `condition \| device` | 7,050 | 5,493,696 | 839,049 | 4,945 | 15 |
| **1040** | `condition \| drug` | 602,514 | 224,572,220 | 29,244,597 | 8,674 | 2,526 |
| **1050** | `condition \| obs test` | 196,544 | 752,768,329 | 71,188,679 | 10,071 | 1,009 |
| **1051** | `condition \| obs result` | 2,560,881 | 1,312,633,711 | 192,046,712 | 9,819 | 25,887 |
| **1060** | `condition \| meas test` | 2,074,833 | 9,107,507,658 | 1,198,929,734 | 9,968 | 6,568 |
| **1061** | `condition \| meas result`| 3,171,474 | 8,972,264,188 | 1,277,553,812 | 9,966 | 13,385 |
| **2020** | `procedure \| procedure` | 97,796 | 87,865,165 | 17,753,087 | 3,641 | 3,793 |
| **2030** | `procedure \| device` | 3,196 | 3,383,840 | 837,070 | 2,328 | 14 |
| **2040** | `procedure \| drug` | 180,898 | 57,172,315 | 8,596,651 | 4,005 | 2,289 |
| **2050** | `procedure \| obs test` | 45,767 | 76,965,133 | 13,189,140 | 4,886 | 744 |
| **2060** | `procedure \| meas test` | 569,954 | 1,527,268,779 | 241,651,442 | 4,798 | 4,609 |
| **3030** | `device \| device` | 11 | 15,131 | 3,766 | 10 | 2 |
| **3040** | `device \| drug` | 2,259 | 2,376,631 | 493,944 | 12 | 1,512 |
| **3050** | `device \| obs test` | 509 | 1,579,432 | 225,928 | 15 | 346 |
| **3051** | `device \| obs result` | 5,855 | 2,000,577 | 388,604 | 15 | 4,928 |
| **3060** | `device \| meas test` | 3,286 | 21,010,680 | 3,779,328 | 15 | 1,376 |
| **3061** | `device \| meas result` | 5,264 | 20,473,579 | 3,958,348 | 15 | 2,394 |
| **4040** | `drug \| drug` | 334,509 | 737,927,554 | 43,008,373 | 2,421 | 2,504 |
| **4050** | `drug \| obs test` | 50,542 | 155,773,512 | 16,262,827 | 2,545 | 849 |
| **4051** | `drug \| obs result` | 919,631 | 252,515,284 | 31,373,676 | 2,487 | 20,528 |
| **4060** | `drug \| meas test` | 798,821 | 6,008,462,818 | 362,759,487 | 2,554 | 5,507 |
| **4061** | `drug \| meas result` | 1,250,436 | 6,005,573,374 | 388,250,592 | 2,554 | 10,688 |
| **9999** | **ALL PAIR TYPES** | **14,233,528** | **36,053,079,999** | **4,007,091,065** | **17,703** | **64,596** |

---

### 5.4 Theoretical Pair Space vs. Observed Coverage & Sparsity (Table 4)
Comparing observed concept pairs to the theoretical maximum combinatorial space demonstrates the extreme empirical sparsity of observational health data. Across all domains, only **0.9%** of theoretically possible concept pairs ever co-occur in patient care.

| Pair Code | Domain Pair Name | Concept Universe A | Concept Universe B | Theoretically Possible Pairs | Empirically Observed Pairs | % Observed (Sparsity Rate) |
|---|---|---|---|---|---|---|
| **1010** | `condition \| condition` | 12,766 | 12,766 | 81,478,995 | 879,487 | **1.1%** |
| **1020** | `condition \| procedure` | 12,766 | 7,385 | 94,276,910 | 472,011 | **0.5%** |
| **1030** | `condition \| device` | 12,766 | 20 | 255,320 | 7,050 | **2.8%** |
| **1040** | `condition \| drug` | 12,766 | 3,280 | 41,872,480 | 602,514 | **1.4%** |
| **1050** | `condition \| obs test` | 12,766 | 1,587 | 20,259,642 | 196,544 | **1.0%** |
| **1051** | `condition \| obs result`| 12,766 | 39,195 | 500,363,370 | 2,560,881 | **0.5%** |
| **1060** | `condition \| meas test` | 12,766 | 8,872 | 113,259,952 | 2,074,833 | **1.8%** |
| **1061** | `condition \| meas result`| 12,766 | 22,886 | 292,162,676 | 3,171,474 | **1.1%** |
| **2020** | `procedure \| procedure` | 7,385 | 7,385 | 27,265,420 | 97,796 | **0.4%** |
| **2030** | `procedure \| device` | 7,385 | 20 | 147,700 | 3,196 | **2.2%** |
| **2040** | `procedure \| drug` | 7,385 | 3,280 | 24,222,800 | 180,898 | **0.7%** |
| **2050** | `procedure \| obs test` | 7,385 | 1,587 | 11,719,995 | 45,767 | **0.4%** |
| **2060** | `procedure \| meas test` | 7,385 | 8,872 | 65,519,720 | 569,954 | **0.9%** |
| **3030** | `device \| device` | 20 | 20 | 190 | 11 | **5.8%** |
| **3040** | `device \| drug` | 20 | 3,280 | 65,600 | 2,259 | **3.4%** |
| **3050** | `device \| obs test` | 20 | 1,587 | 31,740 | 509 | **1.6%** |
| **3051** | `device \| obs result` | 20 | 39,195 | 783,900 | 5,855 | **0.7%** |
| **3060** | `device \| meas test` | 20 | 8,872 | 177,440 | 3,286 | **1.9%** |
| **3061** | `device \| meas result` | 20 | 22,886 | 457,720 | 5,264 | **1.2%** |
| **4040** | `drug \| drug` | 3,280 | 3,280 | 5,377,560 | 334,509 | **6.2%** |
| **4050** | `drug \| obs test` | 3,280 | 1,587 | 5,205,360 | 50,542 | **1.0%** |
| **4051** | `drug \| obs result` | 3,280 | 39,195 | 128,559,600 | 919,631 | **0.7%** |
| **4060** | `drug \| meas test` | 3,280 | 8,872 | 29,100,160 | 798,821 | **2.7%** |
| **4061** | `drug \| meas result` | 3,280 | 22,886 | 75,066,080 | 1,250,436 | **1.7%** |
| **9999** | **ALL PAIR TYPES** | **Combinatorial Space** | — | **1,517,630,330** | **14,233,528** | **0.9%** |

*Methodological Context*: Under the documented support filtering threshold ($N_{AB} \ge 5$ distinct persons required for statistical evaluation in the benchmark tables; batch filter `pair_total > @cab_min_ab_obs`), **0.9%** of theoretically possible concept pairs are retained as observed candidates. This establishes that minimum observed support alone filters out 99.1% of the theoretical combinatorial space prior to higher-order lift gating or LLM adjudication.

---

### 5.5 Longitudinal Timing & Directionality Dynamics (Table 5)
The temporal distribution of co-occurring event pairs partitions across calendar dates into **`% same day`** (10.3%), **`% A before B`** (42.7%), and **`% B before A`** (47.0%), which together partition 100.0% of pairwise event co-occurrences by calendar date. In parallel, **`% same visit`** (27.5%) measures encounter-level linkage using `visit_occurrence_id`: because inpatient hospitalizations, observation stays, and emergency-to-inpatient transfers span multiple calendar dates, events occurring on different days of the same hospital admission can exhibit directional precedence ($A \to B$ or $B \to A$) while simultaneously sharing an identical overarching visit identifier.

| Pair Code | Domain Pair Name | Observed Concept Pairs | Event-Pair Observations | % Same Visit | % Same Day | % A before B ($A \to B$) | % B before A ($B \to A$) | Dominant Clinical Directionality |
|---|---|---|---|---|---|---|---|---|
| **1010** | `condition \| condition` | 879,487 | 537,558,118 | 16.7% | 26.9% | 36.9% | 36.3% | Symmetric comorbidity clustering |
| **1020** | `condition \| procedure` | 472,011 | 179,918,275 | 13.9% | 14.8% | 40.1% | 45.0% | Mixed (diagnostic vs therapeutic proc) |
| **1030** | `condition \| device` | 7,050 | 5,493,696 | 11.4% | 12.5% | 44.2% | 43.4% | Balanced chronic maintenance |
| **1040** | `condition \| drug` | 602,514 | 224,572,220 | 15.3% | 4.8% | 42.9% | 52.3% | Prevalent prescription capture ($B \to A$) |
| **1050** | `condition \| obs test` | 196,544 | 752,768,329 | 12.7% | 25.9% | 36.9% | 37.2% | Symmetric encounter testing |
| **1051** | `condition \| obs result`| 2,560,881 | 1,312,633,711 | 18.4% | 31.5% | 34.4% | 34.1% | Strong contemporaneous recording |
| **1060** | `condition \| meas test` | 2,074,833 | 9,107,507,658 | 20.1% | 11.7% | 40.7% | 47.6% | Routine monitoring precedence |
| **1061** | `condition \| meas result`| 3,171,474 | 8,972,264,188 | 20.1% | 11.6% | 40.8% | 47.6% | Pre-diagnostic lab abnormality |
| **2020** | `procedure \| procedure` | 97,796 | 87,865,165 | 28.7% | 28.5% | 36.0% | 35.5% | Intra-procedural bundles |
| **2030** | `procedure \| device` | 3,196 | 3,383,840 | 14.6% | 13.4% | 43.4% | 43.2% | Device implantation events |
| **2040** | `procedure \| drug` | 180,898 | 57,172,315 | 20.1% | 7.4% | 52.8% | 39.8% | Post-procedure pharmacology ($A \to B$) |
| **2050** | `procedure \| obs test` | 45,767 | 76,965,133 | 12.8% | 18.2% | 41.7% | 40.1% | Peri-operative evaluation |
| **2060** | `procedure \| meas test` | 569,954 | 1,527,268,779 | 22.2% | 14.5% | 47.8% | 37.7% | Post-op surveillance labs ($A \to B$) |
| **3030** | `device \| device` | 11 | 15,131 | 26.0% | 25.9% | 36.2% | 37.9% | Dual-device co-placement |
| **3040** | `device \| drug` | 2,259 | 2,376,631 | 5.9% | 6.9% | 47.2% | 45.9% | Chronic therapy with device |
| **3050** | `device \| obs test` | 509 | 1,579,432 | 6.4% | 11.1% | 44.4% | 44.6% | Device interrogation tests |
| **3051** | `device \| obs result` | 5,855 | 2,000,577 | 5.7% | 9.2% | 45.6% | 45.1% | Device status telemetry |
| **3060** | `device \| meas test` | 3,286 | 21,010,680 | 0.8% | 6.1% | 46.7% | 47.2% | Long-term organ monitoring |
| **3061** | `device \| meas result` | 5,264 | 20,473,579 | 0.8% | 6.0% | 46.8% | 47.2% | Physiologic impact of device |
| **4040** | `drug \| drug` | 334,509 | 737,927,554 | 52.4% | 8.7% | 44.9% | 46.4% | High same-visit co-prescribing |
| **4050** | `drug \| obs test` | 50,542 | 155,773,512 | 4.5% | 4.4% | 46.6% | 48.9% | Clinical assessment timing |
| **4051** | `drug \| obs result` | 919,631 | 252,515,284 | 17.6% | 4.3% | 53.2% | 42.5% | Drug monitoring finding ($A \to B$) |
| **4060** | `drug \| meas test` | 798,821 | 6,008,462,818 | 41.0% | 3.9% | 46.3% | 49.8% | Routine therapeutic lab check |
| **4061** | `drug \| meas result` | 1,250,436 | 6,005,573,374 | 41.9% | 3.9% | 46.2% | 49.9% | Lab monitoring response |
| **9999** | **ALL PAIR TYPES** | **14,233,528** | **36,053,079,999** | **27.5%** | **10.3%** | **42.7%** | **47.0%** | **Global Longitudinal Distribution** |

---

### 5.6 Semantic Similarity via SNOMED LCA Distance (Table 6)
For pairs where both concepts reside within the SNOMED-CT ontology, the Lowest Common Ancestor (LCA) graph distance provides an orthogonal semantic measure of hierarchy proximity (lower LCA distance indicates closer ontologic relationship).

| Pair Code | Domain Pair Name | % Pairs LCA $\le 2$ | % Pairs LCA $\le 4$ | % Pairs LCA $\le 6$ | % Pairs LCA $> 6$ | Ontologic Proximity Interpretation |
|---|---|---|---|---|---|---|
| **1010** | `condition \| condition` | 8.3% | 18.3% | 49.5% | 50.5% | High share of sibling / close-genus disease pairs |
| **1050** | `condition \| obs test` | 0.8% | 5.3% | 31.2% | 68.8% | Cross-hierarchy clinical linkage |
| **2020** | `procedure \| procedure` | 8.1% | 34.2% | 62.7% | 37.3% | Strong procedural clustering in anatomical domains |
| **2050** | `procedure \| obs test` | 6.0% | 33.4% | 77.8% | 22.2% | Close evaluation-to-intervention semantic ties |
| **2060** | `procedure \| meas test` | 0.1% | 5.2% | 21.3% | 78.7% | Distinct ontologic branches bridged by care practice |
| **9999** | **ALL IN-SCOPE PAIRS** | **7.4%** | **18.0%** | **47.5%** | **52.5%** | **Ontologic Baseline for SNOMED-to-SNOMED Pairs** |

*Methodological Significance*: 52.5% of co-occurring SNOMED concept pairs have an LCA distance $>6$, confirming that real-world clinical relationships cut across distant branches of medical vocabularies rather than clustering only among hierarchical taxonomic siblings.

---

### 5.7 Person-Level Statistical Lift Distribution (Table 7)
Statistical lift quantifies co-occurrence strength relative to population expectation. The table below documents the percentage of observed concept pairs exceeding progressive lift thresholds ($Lift \ge 1$: at or above chance; $Lift \ge 2$: double chance; $Lift \ge 5$: strong association).

| Pair Code | Domain Pair Name | % Pairs $Lift \ge 1.0$ | % Pairs $Lift \ge 2.0$ | % Pairs $Lift \ge 3.0$ | % Pairs $Lift \ge 5.0$ | Association Concentration Profile |
|---|---|---|---|---|---|---|
| **1010** | `condition \| condition` | 61.5% | 35.3% | 21.6% | 13.2% | Heavy comorbidity enrichment |
| **1020** | `condition \| procedure` | 54.3% | 25.8% | 17.1% | 12.3% | Broad diagnostic-therapeutic clustering |
| **1030** | `condition \| device` | 40.7% | 10.0% | 6.2% | 3.0% | Narrow specialized device indications |
| **1040** | `condition \| drug` | 38.1% | 20.1% | 13.6% | 7.4% | Concentrated therapeutic indications |
| **1050** | `condition \| obs test` | 55.0% | 3.5% | 2.2% | 1.5% | Widespread baseline clinical observation |
| **1051** | `condition \| obs result`| 62.5% | 39.2% | 28.0% | 20.2% | Specific clinical findings matching diagnosis |
| **1060** | `condition \| meas test` | 51.1% | 5.5% | 2.4% | 0.8% | Ubiquitous routine screening panels |
| **1061** | `condition \| meas result`| 48.7% | 8.7% | 3.8% | 1.1% | Specific pathological biomarker elevations |
| **2020** | `procedure \| procedure` | 93.1% | 85.9% | 76.2% | 68.8% | Highly clustered multi-component procedures |
| **2030** | `procedure \| device` | 93.9% | 81.0% | 59.8% | 37.5% | Direct procedural device deployment |
| **2040** | `procedure \| drug` | 47.6% | 31.4% | 22.0% | 15.9% | Peri-procedural medications |
| **2050** | `procedure \| obs test` | 48.7% | 8.5% | 2.4% | 1.2% | Pre-op and post-op nursing assessments |
| **2060** | `procedure \| meas test` | 52.5% | 12.6% | 6.0% | 2.6% | Peri-operative lab surveillance |
| **3030** | `device \| device` | 81.0% | 81.0% | 62.2% | 57.1% | Multi-lead / dual-chamber device assemblies |
| **3040** | `device \| drug` | 67.5% | 29.0% | 16.4% | 15.3% | Specialized pharmacotherapy for device users |
| **3050** | `device \| obs test` | 8.4% | 6.8% | 6.4% | 2.3% | Specific device telemetry evaluations |
| **3051** | `device \| obs result` | 16.3% | 8.8% | 5.0% | 2.6% | Telemetry interrogation findings |
| **3060** | `device \| meas test` | 4.1% | 3.2% | 2.6% | 1.6% | Routine organ system labs |
| **3061** | `device \| meas result` | 4.8% | 4.1% | 3.1% | 1.8% | Organ dysfunction lab flags |
| **4040** | `drug \| drug` | 91.2% | 71.6% | 49.1% | 31.8% | High polypharmacy & regimen co-prescription |
| **4050** | `drug \| obs test` | 11.6% | 3.4% | 1.4% | 1.3% | Specialized drug monitoring surveys |
| **4051** | `drug \| obs result` | 37.9% | 24.0% | 19.6% | 13.3% | Medication administration records & responses |
| **4060** | `drug \| meas test` | 27.9% | 10.2% | 7.1% | 5.0% | Routine safety monitoring labs |
| **4061** | `drug \| meas result` | 27.9% | 13.5% | 10.6% | 7.1% | Therapeutic drug level / electrolyte checks |
| **9999** | **ALL PAIR TYPES** | **47.1%** | **11.9%** | **7.1%** | **4.1%** | **Population-Wide Association Selectivity** |

---

### 5.8 External Clinical Validation: ClinVec / ClinGraph Benchmark
To confirm that empirical statistical lift prioritizes genuine clinical relationships rather than statistical noise, the candidate pairs were validated against the published **ClinGraph / ClinVec** clinical benchmark (2,970 published pairs, fully reconciled to standard OMOP SNOMED concepts).

#### Exhibit 1: Multi-Modal Concurrence (Published Flag vs. LLM vs. Clinician Ratings)
The benchmark compares three independent evaluative opinions across 2,970 pairs: (1) the published ClinVec binary related/unrelated classification, (2) zero-shot LLM classification, and (3) expert clinician 1–5 ratings.

| Classification Cross-Tabulation | LLM: Related | LLM: Not Related | ClinVec Total |
|---|---|---|---|
| **ClinVec: Related** | **876** *(Clinician Avg: **3.65**)*<br>Concurrence: Both call Related | **623** *(Clinician Avg: **2.46**)*<br>Divergence: ClinVec Yes, LLM No | **1,499** |
| **ClinVec: Not Related** | **343** *(Clinician Avg: **2.22**)*<br>Divergence: ClinVec No, LLM Yes | **1,128** *(Clinician Avg: **1.36**)*<br>Concurrence: Both call Not Related | **1,471** |
| **LLM Total** | **1,219** | **1,751** | **2,970** |

*Core Concurrence Finding*: The ClinVec published flag and the independent LLM concur on **2,004 of 2,970 pairs (67.5%)**. Clinician ratings provide an external adjudication anchor: when both agree related, clinicians confirm with high marks (mean **3.65 / 5.0**); when both agree unrelated, clinicians reject decisively (mean **1.36 / 5.0**). When they diverge, clinician ratings sit precisely in the intermediate boundary (mean 2.46 and 2.22), proving that divergent pairs represent subtle intermediate clinical associations rather than classification errors.

#### Exhibit 2: Statistical Lift as an Enrichment Filter (Monotonic Precision Gradient)
Evaluating ClinVec benchmark pairs across observational co-occurrence tiers demonstrates that statistical lift acts as a powerful precision enrichment filter:

| Evidence Level in INPC Observational Data | Benchmark Pairs Evaluated | ClinVec-Related Share (%) | LLM-Related Share (%) | Clinician 1–5 Average Rating |
|---|---|---|---|---|
| **All Benchmark Pairs** | 2,970 | 50.5% | 41.0% | 2.36 |
| **Unobserved in IU Data** (Zero co-occurrence) | 2,405 | 47.9% | 38.3% | 2.26 |
| **Observed Co-occurring** (Any observed co-occurrence) | 565 | 61.1% | 55.6% | 2.80 |
| **Co-occurring with Person Lift $\ge 1.0$** | 222 | **82.9%** | **73.0%** | **3.53** |
| **Co-occurring with Person Lift $\ge 2.0$** | 141 | **92.2%** | **78.7%** | **3.88** |

*Validation Conclusion*: Observational statistical lift provides an exceptionally strong monotonic enrichment gradient: the ClinVec-related share rises from **47.9%** for unobserved pairs to **61.1%** for raw co-occurrence, surging to **82.9%** at $Lift \ge 1.0$ and **92.2%** at $Lift \ge 2.0$, while clinician validation ratings climb in parallel from **2.26** to **3.88 / 5.0**.

---

## 6. Concordance & Consistency Audit: OHDSI T-SQL vs. Bandeian Empirical Write-Up

A structured architectural crosswalk was conducted comparing the released OHDSI T-SQL codebase (`inst/sql/sql_server/*.sql` and `docs/mining/sql/*.sql`) with Dr. Stephen H. Bandeian's authoritative write-ups (`TAXIS_Supporting_Appendix_INPC 2M 4 Jun 2026.pdf`, `cab_summary_tables.docx`, and the 2025 OHDSI Symposium paper). The comparison confirms structural, schema, and parametric concordance across core specifications, while identifying the exact functional locations for downstream transformations:

```text
┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                        OHDSI T-SQL ENGINE vs. EMPIRICAL BENCHMARK CONCORDANCE CROSSWALK                │
└────────────────────────────────────────────────────────────────────────────────────────────────────────┘
  Architectural Feature    OHDSI T-SQL Implementation                 Bandeian Empirical Write-Up     Status
 ──────────────────────   ────────────────────────────────────────── ─────────────────────────────   ────────
  1. Domain IDs (src)      10=Cond, 20=Proc, 30=Dev, 40=Drug,         Table 2: 10, 20, 30, 40, 50,    Concordant
                           50=ObsTest, 51=ObsRes, 60=MeasTest,        51, 60, 61.                     (Exact)
                           61=MeasRes, 11=ChronicCond                                                         
                                                                                                              
  2. Pair-Type Formula     a.src * 100 + b.src                        Table 3–7: 1010 to 4061         Concordant
                           (e.g., 1010, 1040, 1061, 2040, 4040)       (All 24 integer pair codes)     (Exact)
                                                                                                              
  3. Key Packing Logic     concept_id = test * 1e9 + result_code      Lab/Obs result packing scheme   Concordant
                           (Integer band 60000000..60099999)          (Packed surrogate keys)         (Exact)
                                                                                                              
  4. Temporal Intervals    Interval 1: delta 0 (same day)             Table 5: % same visit,          Concordant
                           Interval 2: delta +1..+W (B after A)       % same day, % A before B,       (Exact)
                           Interval 3: delta -W..-1 (B before A)      % B before A                                    
                                                                                                              
  5. Directionality Math   dir_ab = obs_after / (obs_after+obs_before) DR = (N_A->B+0.5)/(N_B->A+0.5) Concordant
                           in cab_s55_pair_all; transformed to DR     (Post-processing / unverified)  (Mapped)
                                                                                                              
  6. Lift Estimands        pers_lift = pers / pers_exp                Table 7: Person-level lift      Concordant
                           obs_lift = obs / obs_exp                   distributions (>=1, 2, 3, 5)    (Exact)
                           Stratified: cab_s33_mh_all (E_util)        Decile-adjusted expected                        
                                                                                                              
  7. Output Table Set      All 18 canonical tables materialized:      Complete 18 export tables       Concordant
                           cab_s10, s20, s30, s40, s50, s55, s13,     profiled and documented         (Exact)
                           s23, s33, s33_mh, vocab, lag, timing...                                                    
```

### Detailed Concordance Verification Points:

1. **Domain Codes & Source Standardization**:
   - `concept_ab_batch.sql` (lines 1680–4400) assigns explicit domain codes: Condition (`src = 10`), Procedure (`src = 20`), Device (`src = 30`), Drug (`src = 40`), Observation Test (`src = 50`), Observation Result (`src = 51`), Measurement Test (`src = 60`), and Measurement Result (`src = 61`).
   - Table 2 in Dr. Bandeian's Supporting Appendix lists these exact 8 domain codes, with identical concept distributions and event volume totals.

2. **Cross-Domain Pair Permutations (`pair_type`)**:
   - Both the SQL engine (`concept_ab_batch.sql`, `concept_ab_finalize.sql`) and the empirical report derive pair types through `pair_type = a.src * 100 + b.src`.
   - All 24 cross-domain combinations in the SQL join loop correspond identically to the 24 rows in Tables 3, 4, 5, and 7.

3. **Laboratory Measurement Result Key Packing**:
   - `concept_ab_batch.sql` (lines 50–56) and `cab_vocab_all_output` in `concept_ab_finalize.sql` (lines 525–664) mint and unpack deterministic 64-bit surrogate keys via $\text{Concept ID}_{\text{packed}} = (\text{test\_concept\_id} \times 10^9) + \text{result\_code}$.
   - The synthetic integer range (`60000000..60099999`) and standard flag assignments (`46237210` for no result, `36309857` for unusable, `test_concept_id` for assertion) operate identically in code and documentation.

4. **Temporal Ordering & Precedence Horizons**:
   - `concept_ab_batch.sql` and `concept_ab_finalize.sql` parameterize co-occurrences into:
     - `interval_code 1`: Same-day co-occurrence ($\Delta t = 0$).
     - `interval_code 2`: Concept B occurs after Concept A ($\Delta t \in [+1, +W]$).
     - `interval_code 3`: Concept B occurs before Concept A ($\Delta t \in [-W, -1]$).
     - `same_visit_frac`: Fraction of co-occurrences sharing identical `visit_occurrence_id`.
   - Table 5 in Dr. Bandeian's Supporting Appendix mirrors these exact definitions, reporting `% same visit` (27.5%), `% same day` (10.3%), `% A before B` (42.7%), and `% B before A` (47.0%).

5. **Directionality Ratio ($DR$) vs. Directional Share (`dir_ab`)**:
   - In `inst/sql/sql_server/concept_ab_finalize.sql` (line 1350), the SQL engine computes the raw directional proportion:
     $$\text{dir\_ab} = \frac{\text{obs\_after}}{\text{obs\_after} + \text{obs\_before}}$$
   - In Dr. Bandeian's analytical write-up, the continuity-corrected Directionality Ratio is calculated:
     $$DR = \frac{N_{A \to B} + 0.5}{N_{B \to A} + 0.5} = \frac{\text{obs\_after} + 0.5}{\text{obs\_before} + 0.5}$$
   - These formulations are monotonically equivalent: $DR = \frac{\text{dir\_ab}}{1 - \text{dir\_ab}}$ (in the asymptotic limit without smoothing) and $DR_{\text{corrected}} = \frac{\text{obs\_after} + 0.5}{\text{obs\_before} + 0.5}$. The SQL engine materializes `dir_ab` as the unadjusted database column in `cab_s55_pair_all`, while application of the Haldane-Anscombe continuity correction is formalized in production post-processing routines (`sanitizeConceptPairRows()` in `classify_pairs.R` and `sanitize_pair_record()` in `classify_pairs.py`).

6. **Healthcare Utilization Decile Stratification & Odds Ratios**:
   - The SQL scripts `concept_ab_init.sql` (lines 205–250) and `concept_ab_finalize.sql` (lines 913–1054) implement utilization decile tables `cab_s13_strat_all`, `cab_s23_strat_all`, `cab_s33_strat_all`, and `cab_s33_mh_all`.
   - Expected cell counts are formed inside each decile before summing ($E_{AB, \text{util}} = \sum_{k=1}^{10} \frac{N_{A,k} \cdot N_{B,k} \cdot (2W+1)}{\text{person\_days}_k}$), mitigating contact-density bias as specified in Authoritative Decision `DEC-GR-010`.
   - Furthermore, `cab_s33_strat_all` materializes the cell-level contingency components per decile (`obs_ab_act, obs_ab_act_fmab, pers_ab`), providing the exact stratified contingency substrate required for Cochran-Mantel-Haenszel common odds ratio ($OR_{\text{MH}}$) computation.

7. **Harmonization of Pilot (1.04M) vs. Production (2.16M) Benchmark Runs**:
   - The repository documentation explicitly distinguishes Dr. Bandeian's exploratory pilot run (`cab_summary_tables.docx`, $N = 1,035,846$; 5.42M person-years; 87,963 concepts; 11,705,143 observed pairs) from the finalized production benchmark run (`TAXIS_Supporting_Appendix_INPC 2M 4 Jun 2026.pdf`, $N = 2,157,525$; 11,299,055 person-years; 95,968 concepts; 14,233,528 observed pairs).
   - Both runs share the Pipeline v57 architectural design and parameter conventions, while historical server execution binary hashes and runtime environment configurations remain unverified historical artifacts.

8. **Proof-of-Concept Downstream Demonstrations**:
   - The mined empirical pairs ($N = 14,233,528$) and continuity-corrected directionality ratios ($DR$) provide the foundational empirical substrate for community research.
   - While our primary focus is releasing and maintaining TAXIS and conducting the network study to create a public concept-pair resource, we include a crude proof of concept demonstrating how this empirical foundation can inform downstream tools. Specifically, we illustrate how empirical associations can map into a 6-bucket clinical element architecture (primary anchor, symptoms, confirmatory labs, indicated interventions, complications, and exclusionary mimics) to help structure Circe cohort definitions. Full demonstration details: see [`docs/phenotyping/PHENOTYPE_PHEBRUARY_2026_TAXIS_INTEGRATION.md`](../phenotyping/PHENOTYPE_PHEBRUARY_2026_TAXIS_INTEGRATION.md).

9. **Mitigating Semicolon Null Pointer Exceptions in JDBC Drivers**: In the released T-SQL batch script (`concept_ab_batch.sql`), standalone semicolons follow explanatory comments to satisfy SQL Server common table expression (CTE) syntax conventions. When `SqlRender` translates these scripts for PostgreSQL, standard JDBC drivers and `DatabaseConnector` can trigger a `NullPointerException` when attempting to dispatch an empty statement delimited by consecutive semicolons. Our R execution runners resolve this driver behavior by invoking `SqlRender::splitSql()` and filtering zero-length statement fragments prior to database execution. This ensures seamless cross-dialect execution across PostgreSQL environments without altering any line of the released SQL files, preserving 100% bit-for-bit SHA-256 identity between `inst/sql/sql_server/*.sql` and `docs/mining/sql/*.sql`.

10. **Native Verification on PostgreSQL**: The full three-phase pipeline (`concept_ab_init.sql`, `concept_ab_batch.sql`, `concept_ab_finalize.sql`) was verified natively against PostgreSQL 16 using standard OHDSI HADES packages (`SqlRender` 1.19.7 and `DatabaseConnector` 8.0.0). The test executed all 250 batch statements and 58 finalization statements without error, materializing all 43 output tables in `work_cab_test` and discovering 9,118 candidate concept pairs in `cab_s55_pair_all`.

    Pipeline outputs were verified using automated test suites in `extras/test_pipeline_v57_postgres_execution.py`. Beyond asserting table row counts, the test harness independently derives expected counts directly from raw CDM fact co-occurrences:
    - **Acute bronchitis $\leftrightarrow$ acetaminophen**: 8,228 total co-occurrences (8,102 same day, 92 after, 34 before). The directionality ratio is $DR = 2.68$, confirming that acetaminophen exposure follows the bronchitis diagnosis.
    - **Otitis media $\leftrightarrow$ acetaminophen**: 1,415 total co-occurrences (1,359 same day, 31 after, 25 before) with a symmetric ratio ($DR = 1.24$).
    - **Suture open wound $\leftrightarrow$ acetaminophen**: 1,062 total co-occurrences (1,035 same day, 12 after, 15 before).

    The synthetic test CDM fixture contains 2,694 persons, 1,037 visits, 1,477 observations, and 0 device records (`cdm.device_exposure = 0`), defining an explicit synthetic fixture coverage boundary. Every execution emits an audited execution receipt (`extras/pipeline_v57_run_receipt.json`) recording dynamic SHA-256 SQL file digests, UTC ISO-8601 timestamps, and database run identifiers. Furthermore, fail-closed error handling was confirmed via a controlled failure test, verifying that database errors produce a non-zero exit code (1) and record a `FAILED` execution receipt.

---

## 7. Complete Output Data Dictionary (18 Export Tables)

The pipeline produces 18 finalized relational tables in `RESULTS_SCHEMA`, structured into four operational tiers:

### Tier 1: Master Association Statistics
| Table Name | Grain | Primary Columns | Analytical Description |
|---|---|---|---|
| **`cab_s55_pair_all`** | Concept Pair ($A, B$) | `pair_type`, `concept_a`, `concept_b`, `concept_name_a`, `concept_name_b`, `pattern_a`, `pattern_b`, `grain_a`, `grain_b`, `lift_to_read`, `obs_all`, `obs_same_day`, `obs_after`, `obs_before`, `pers_same_day`, `pers_after`, `pers_before`, `lift_same_day`, `lift_after`, `lift_before`, `pers_lift_after`, `lag_mean`, `lag_sd`, `same_visit_frac`, `dir_ab`, `util_ratio`, `deff` | Master output table per concept pair, with unadjusted and utilization-stratified lifts, directionality ratios, and temporal counts. |
| **`cab_s50_all`** | Pair $\times$ Window Interval | `pair_type`, `anchor_code`, `interval_code`, `concept_a`, `concept_b`, `win_w`, `obs`, `pers`, `obs_lift`, `pers_lift`, `same_visit_frac`, `lag_mean`, `lag_sd`, `util_ratio` | Unpivoted longitudinal counts across follow-up intervals ($[1, 30]$, $[1, 90]$, $[1, 365]$, $[1, 730]$ days). |
| **`cab_s40_all`** | Pair $\times$ Domain | `pair_type`, `anchor_code`, `interval_code`, `concept_a`, `concept_b`, `obs`, `pers`, `obs_exp`, `pers_exp`, `total_persons`, `total_person_days` | Intermediate contingency table joining observed pair counts with marginal denominators. |
| **`cab_s30_all`** | Raw Observed Pair | `pair_type`, `anchor_code`, `interval_code`, `concept_a`, `concept_b`, `obs`, `pers`, `obs_fma`, `obs_fmb`, `obs_fmab`, `lag_sum`, `util_sum` | Raw aggregated co-occurrence counts across all batches before statistical transformation. |

### Tier 2: Denominators & Marginals
| Table Name | Grain | Primary Columns | Analytical Description |
|---|---|---|---|
| **`cab_s10_person_all`** | Global Population | `total_persons`, `total_person_days`, `total_person_days_clear`, `total_util_sum`, `total_util_sq`, `total_visits` | Denominator summary across all eligible patients meeting the 365-day wash-in criteria. |
| **`cab_s20_marginal_all`**| Single Concept | `concept_id`, `src`, `anchor_code`, `interval_code`, `obs_act`, `pers_act`, `obs_fm_act`, `pers_fm_act`, `max_per_person` | Total patient-level and event-level prevalence for each individual Concept A and Concept B. |
| **`cab_vocab_all_output`**| Single Concept | `concept_id`, `concept_name`, `concept_domain`, `concept_vocab`, `test_concept_id`, `result_concept_id`, `result_shape` | Human-readable concept metadata, including decoded labels for packed lab and drug keys. |

### Tier 3: Utilization Decile Stratification
| Table Name | Grain | Primary Columns | Analytical Description |
|---|---|---|---|
| **`cab_s13_strat_all`** | Decile ($U_1 \dots U_{10}$) | `util_decile`, `persons_in_decile`, `person_days_in_decile` | Denominator patient counts and person-days within each healthcare utilization decile. |
| **`cab_s23_strat_all`** | Concept $\times$ Decile | `concept_id`, `src`, `util_decile`, `obs_act`, `pers_act`, `obs_fm_act`, `pers_fm_act` | Concept marginal person counts broken down across utilization deciles. |
| **`cab_s33_strat_all`** | Pair $\times$ Decile | `pair_type`, `concept_a`, `concept_b`, `util_decile`, `obs_ab_act`, `obs_ab_act_fmab`, `pers_ab` | Observed co-occurrence person counts within each utilization decile (re-poolable). |
| **`cab_s33_mh_all`** | Concept Pair | `pair_type`, `concept_a`, `concept_b`, `obs_ab_act_mh`, `obs_ab_exp_mh`, `obs_ab_act_fmab_mh`, `obs_ab_exp_fmab_mh`, `mean_decile` | Cochran-Mantel-Haenszel decile-adjusted expected counts and common odds ratios. |

### Tier 4: Descriptive Profiling & Process Diagnostics
| Table Name | Grain | Primary Columns | Analytical Description |
|---|---|---|---|
| **`cab_s37_lag_all`** | Concept Pair $\times$ Day | `pair_type`, `lag_bucket`, `lag_days_approx`, `n_events`, `n_pairs` | Empirical lag decay distributions ($\pm 400$ days) for auditing temporal window validity. |
| **`cab_s38_profile_all`**| Cohort Subgroup | `metric`, `src`, `bucket`, `n_records`, `n_persons` | Data quality audit of visit linkage, observation spans, and record completeness. |
| **`cab_s39_pattern_all`**| Single Concept | `metric`, `src`, `concept_id`, `bucket`, `n_obs`, `n_persons` | Longitudinal concept recording patterns (recurrent chronic vs. acute isolated). |
| **`cab_s54_grain_guide`** | Single Concept | `concept_id`, `src`, `obs_act`, `pers_act`, `mentions_per_person`, `pattern`, `grain`, `rationale` | Recording pattern classification (punctate, clustered, chronic, recurrent, episodic) and recommended mention grain. |
| **`meas_obs_profile_s35_all`** | Measurement Test | `src`, `meas_obs_concept_id`, `has_value_concept`, `has_value_number`, `has_value_string`, `n_records` | Profiling of populated measurement fields across OMOP laboratory records. |
| **`meas_obs_attribute_s36_all`**| Measurement Test | `src`, `meas_obs_concept_id`, `attribute`, `attribute_id`, `n_records` | Categorical result values and qualifier concepts associated with specific lab tests. |
| **`cab_timing_all`** | Pipeline Step | `report_section`, `scope`, `batch_number`, `step`, `table_name`, `seconds`, `max_seconds`, `batches_seen` | Wall-clock execution durations per step and batch for performance auditing and tuning. |
| **`cab_process_log`** | Raw Execution Log | `batch_number`, `table_name`, `step`, `step_datetime` | Timestamped transaction log of every SQL statement executed during the run. |

---

## 8. Data Governance, Security & Network Policies

The Concept AB Mining Engine operates in strict conformity with the **TAXIS Network Data Use Term Sheet** ([`docs/governance/TAXIS_NETWORK_DATA_USE_TERM_SHEET.md`](../governance/TAXIS_NETWORK_DATA_USE_TERM_SHEET.md)):

1. **Local Behind-the-Firewall Execution**: The pipeline executes entirely within the data partner's local database environment. No patient-level records, person IDs, encounter timestamps, or narrative clinical texts ever leave the local network boundary.
2. **Concept Pair Matrix Retention (Authoritative Decision `DEC-GR-005`)**: The granular concept-pair co-occurrence matrix (`cab_s55_pair_all`) remains strictly on the partner's secure local database. It is **not** transmitted across institutions in federated Phase 1 studies.
3. **Aggregate Network Export**: For federated network benchmarking, data partners run the companion `TaxisPhenotypeEvaluation` study package, exporting strictly small-cell suppressed ($<5$) summary counts, Jaccard overlap matrices, and `PheValuator` diagnostic performance metrics: Sensitivity, Specificity, PPV, NPV, F1 Score (`Results_<databaseId>.zip`).
4. **Open-Source Licensing**: The pipeline scripts and SQL architecture are distributed under the **Apache 2.0** open-source license. Study documentation is licensed under **Creative Commons Attribution 4.0 International (CC-BY-4.0)**.

---

## 9. Study Leadership & Academic Citations

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
