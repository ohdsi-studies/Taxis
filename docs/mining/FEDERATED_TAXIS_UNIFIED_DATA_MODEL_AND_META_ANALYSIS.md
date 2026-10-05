# TAXIS Federated Architecture, Unified Data Model (UDM) & Multi-Site Meta-Analysis

## Supplementing the Indiana Network for Patient Care (INPC) with Commercial Claims and International Observational Databases

---

## Executive Summary & Scientific Purpose

The foundational Indiana Network for Patient Care (INPC) Concept AB Mining Engine run—surveying 2,157,525 patients, 11.3 million person-years, and 1.88 billion clinical events—demonstrated the power of database-native association mining across longitudinal healthcare data. However, as an electronic health record (EHR) and regional health information exchange (HIE) network located in the US Midwest, INPC reflects specific clinical recording patterns, local hospital formularies, and regional population characteristics.

To evaluate whether TAXIS can evolve from a single-network benchmark into an authoritative, generalizable multi-site clinical knowledge substrate, this document outlines an architectural proposal for federated ingestion and statistical meta-analysis across multiple independent observational databases. By evaluating INPC alongside commercial claims databases (e.g., Merative MarketScan, Optum Clinformatics, IQVIA PharMetrics) and international primary care registries (e.g., CPRD in the UK, SIDIAP in Spain, Hong Kong Hospital Authority), TAXIS seeks to test whether multi-site federation can reduce local institutional practice artifacts, address sample sparsity for rare conditions, and quantify empirical between-database heterogeneity across diverse healthcare delivery systems.

This document specifies:
1. **The Rationale and Scientific Objectives** of multi-database supplementation.
2. **The TAXIS Unified Data Model (UDM)** proposed relational schema and data dictionary.
3. **The Statistical Meta-Analytic Synthesis Framework** (random-effects pooling, between-site heterogeneity diagnostics $I^2$, and prediction intervals).
4. **The Protocol for Data Refreshes and Calendar Era Harmonization**.
5. **The Implementation Roadmap & Feasibility Gates** for multi-site deployment.

---

## 1. Rationale for Multi-Database Federation

```text
┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                        FEDERATED OBSERVATIONAL DATA DIVERSITY & TAXIS SYNTHESIS                         │
├────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                        │
│   EHR & HIE Networks                  Commercial Claims Databases           International EHRs         │
│   (e.g., INPC, Columbia, Stanford)    (e.g., Merative MarketScan, Optum)    (e.g., CPRD, SIDIAP, HKHA) │
│   • Deep clinical granularity         • Enormous sample size (>150M)        • Cradle-to-grave continuity│
│   • Inpatient vitals & labs           • Adjudicated outpatient pharmacy     • National health systems   │
│   • Unstructured EHR data             • Longitudinal claims continuity      • Non-US prescribing habits│
│                                                                                                        │
└───────────────────┬───────────────────────────────────┬──────────────────────────────────┬─────────────┘
                    │                                   │                                  │
                    ▼                                   ▼                                  ▼
┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                        LOCAL CODE-TO-DATA EXECUTION: PIPELINE v57 (SQL ENGINE)                         │
│   • Executes inside local institutional firewall via DatabaseConnector                                │
│   • Enforces mandatory small-cell suppression (< 5 -> -1)                                              │
│   • Current PackageMiningResults.R export: Diagnostic aggregates + manifest (Results_Mining_<site>.zip)│
│   • [Future Export Contract Required]: Aggregate pair-level counts (cab_s55_pair_all) with suppression │
└───────────────────┬───────────────────────────────────┬──────────────────────────────────┬─────────────┘
                    │                                   │                                  │
                    └───────────────────────────────────┼──────────────────────────────────┘
                                                        ▼
┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                   [PROPOSED ARCHITECTURE] CENTRAL TAXIS UDM & META-ANALYSIS MODULE                     │
│   • Ingests site-level aggregate summaries into standardized relational UDM schema                    │
│   • Computes DerSimonian-Laird / REML random-effects pooled lift and pooled directionality             │
│   • Diagnoses empirical heterogeneity (Cochran's Q, I² statistics, between-site variance τ²)           │
│   • Calculates 95% multi-site confidence intervals and prediction intervals (uncertainty bounds)      │
│   • Synthesizes multi-network Clinical Knowledge Graph substrate                                      │
└────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### 1.1 Complementary Strengths of Target Database Types

| Database Class | Representative Sources | Primary Methodological Strengths | Complementary Value to INPC |
|---|---|---|---|
| **Regional EHR & HIE** | **INPC**, Columbia University, Stanford, Johns Hopkins | Inpatient clinical detail, physiological measurements, laboratory test orders and confirmed results, physician observations. | Serves as the high-granularity clinical baseline for laboratory-measurement and inpatient-procedure associations. |
| **Large-Scale Commercial Claims** | **Merative MarketScan**, **Optum Clinformatics** | Massive population scale (>150M lives), closed-system longitudinal claims adjudication, complete retail pharmacy dispensing records, national employer diversity. | Overcomes EHR prescription capture bias (confirming actual retail drug dispensing); boosts sample size for rare adverse drug reactions (ADRs) and low-prevalence multimorbidities. |
| **Medicare / Geriatric Claims** | **Optum Medicare Advantage**, CMS Medicare 20% Sample | Complete capture of geriatric multimorbidity, polypharmacy, end-stage organ disease, and nursing home utilization in adults $\ge 65$. | Balances commercial claims under-representation of elderly multimorbid populations. |
| **International Single-Payer EHRs** | **CPRD** (UK NHS), **SIDIAP** (Catalonia), **Hong Kong HA** | Cradle-to-grave population-based follow-up, general practice gatekeeping, universal healthcare access, non-US formulary prescribing. | Eliminates US billing and insurance churning artifacts; validates cross-national transportability and biological universality of associations. |

### 1.2 Hypothesized Impact on Clinical Knowledge Substrate Quality

1. **Identification of Institutional and Regional Practice Artifacts**:
   A strong statistical association observed in a single regional database may reflect local institutional clinical protocols (e.g., a specific hospital ordering bundle or regional formulary preference). Evaluating associations across independent heterogeneous systems (INPC, MarketScan, Optum, CPRD) provides an empirical screening mechanism to test whether an observed link is driven by site-specific practice patterns or demonstrates generalizable multi-site transportability.

2. **Remediation of Extreme Data Sparsity**:
   While common chronic diseases (e.g., Type 2 Diabetes, Hypertension) attain millions of occurrences in INPC, rare conditions (e.g., Systemic Lupus Erythematosus, Amyotrophic Lateral Sclerosis) or newly approved orphan drugs exhibit small cell counts ($N_{AB} < 100$). Supplementing with national claims databases expands observational support into tens of thousands of co-occurrences, permitting robust stratification.

3. **Detection of Context-Dependent Clinical Heterogeneity**:
   Multi-site synthesis does not simply force homogenization—it explicitly quantifies between-site variance ($\tau^2$ and $I^2$). For example, if a drug-condition pair shows identical high lift across all databases but exhibits divergent directionality between inpatient EHRs (acute indication) and outpatient claims (chronic maintenance), the meta-analytic framework exposes this distinction rather than masking it.

---

## 2. The TAXIS Unified Data Model (UDM) Proposed Specification

The TAXIS Unified Data Model (UDM) is a proposed standardized relational schema designed to store, harmonize, and synthesize pre-computed site aggregate outputs across heterogeneous OMOP CDM instances.

> **Implementation Status & Missing Export Contract**: The tables below represent a proposed target schema for central multi-site synthesis. At present, the released R export function (`PackageMiningResults.R`) exports six diagnostic tables (`cab_process_log`, `cab_s13_strat_all`, `cab_s37_lag_all`, `cab_s38_profile_all`, `cab_s39_pattern_all`, `cab_s54_grain_guide`) and an execution manifest. Feeding `taxis_udm_pair_summary` requires the future definition, privacy vetting, and release of an aggregate pair-export module that extracts `cab_s55_pair_all` with mandatory small-cell suppression ($< 5 \to -1$), cross-table subtraction protection, and institutional disclosure controls.

All tables in the proposed UDM are strictly aggregate-only. No patient-level records, individual encounter dates, or unsuppressed small cells ($< 5$) are ever admitted into the schema.

### 2.1 Entity-Relationship Overview

```text
┌─────────────────────────────────┐
│     taxis_udm_site_manifest     │
│  (Site metadata & execution IDs)│
└────────────────┬────────────────┘
                 │ 1
                 │
                 ├──────────────────────────────────────┐
                 │ N                                    │ N
┌────────────────▼────────────────┐    ┌────────────────▼────────────────┐
│   taxis_udm_concept_marginal    │    │     taxis_udm_pair_summary      │
│  (Site marginal concept counts) │    │  (Site aggregate pair metrics)  │
└─────────────────────────────────┘    └────────────────┬────────────────┘
                                                        │
                                                        │ Synthesized by Central Meta-Engine
                                                        ▼
                                       ┌─────────────────────────────────┐
                                       │   taxis_udm_synthesized_graph   │
                                       │ (Pooled multi-site associations)│
                                       └─────────────────────────────────┘
```

### 2.2 UDM Table DDL & Data Dictionaries

#### 1. Site Execution Manifest (`taxis_udm_site_manifest`)
Tracks database provenance, CDM specifications, observation periods, and execution audit hashes for every site contribution.

```sql
CREATE TABLE taxis_udm_site_manifest (
    site_id                 VARCHAR(50)     NOT NULL,
    release_id              VARCHAR(50)     NOT NULL,
    site_name               VARCHAR(255)    NOT NULL,
    site_type               VARCHAR(50)     NOT NULL, -- 'EHR', 'Claims', 'Integrated_HIE', 'Registry'
    country_code            VARCHAR(3)      NOT NULL, -- 'USA', 'GBR', 'ESP', etc.
    cdm_version             VARCHAR(20)     NOT NULL, -- 'v5.4', 'v5.3'
    vocabulary_version      VARCHAR(50)     NOT NULL,
    taxis_pipeline_version  VARCHAR(20)     NOT NULL, -- 'v57'
    calendar_start_date     DATE            NOT NULL,
    calendar_end_date       DATE            NOT NULL,
    calendar_era_id         VARCHAR(50)     NOT NULL, -- 'ALL_TIME', 'PRE_COVID', 'POST_COVID', '2015_2019'
    min_washin_days         INT             NOT NULL, -- default 365
    window_days             INT             NOT NULL, -- default 30 or 365
    total_persons           BIGINT          NOT NULL,
    total_person_days       BIGINT          NOT NULL,
    suppression_threshold   INT             NOT NULL DEFAULT 5,
    run_receipt_sha256      VARCHAR(64)     NOT NULL,
    ingestion_timestamp     TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_udm_site_manifest PRIMARY KEY (site_id, release_id, calendar_era_id)
);
```

#### 2. Site Concept Marginals (`taxis_udm_concept_marginal`)
Stores site-specific marginal prevalence and mention counts for each surveyed concept.

```sql
CREATE TABLE taxis_udm_concept_marginal (
    site_id                 VARCHAR(50)     NOT NULL,
    release_id              VARCHAR(50)     NOT NULL,
    calendar_era_id         VARCHAR(50)     NOT NULL,
    concept_id              BIGINT          NOT NULL,
    src                     INT             NOT NULL, -- 10=Condition, 20=Procedure, 40=Drug, 60=MeasTest, etc.
    concept_name            VARCHAR(255)    NOT NULL,
    pers_count              BIGINT          NOT NULL, -- masked to -1 if 1 <= count < 5
    obs_count               BIGINT          NOT NULL, -- masked to -1 if 1 <= count < 5
    mentions_per_person     FLOAT           NULL,
    CONSTRAINT pk_udm_concept_marginal PRIMARY KEY (site_id, release_id, calendar_era_id, concept_id)
);
```

#### 3. Site Pair Association Summary (`taxis_udm_pair_summary`)
Contains bivariate association counts, directional counts, and lift metrics computed at each site.

```sql
CREATE TABLE taxis_udm_pair_summary (
    site_id                 VARCHAR(50)     NOT NULL,
    release_id              VARCHAR(50)     NOT NULL,
    calendar_era_id         VARCHAR(50)     NOT NULL,
    pair_type               INT             NOT NULL, -- 1010, 1040, 2040, etc.
    concept_a               BIGINT          NOT NULL,
    concept_b               BIGINT          NOT NULL,
    obs_all                 BIGINT          NOT NULL, -- masked to -1 if < 5
    obs_same_day            BIGINT          NULL,
    obs_after               BIGINT          NULL,
    obs_before              BIGINT          NULL,
    pers_same_day           BIGINT          NULL,
    pers_after              BIGINT          NULL,
    pers_before             BIGINT          NULL,
    lift_same_day           FLOAT           NULL,
    lift_after              FLOAT           NULL,
    lift_before             FLOAT           NULL,
    lift_after_fmb          FLOAT           NULL, -- incident target lift
    pers_lift_after         FLOAT           NULL,
    dir_ab                  FLOAT           NULL, -- obs_after / (obs_after + obs_before)
    dr_corrected            FLOAT           NULL, -- (obs_after + 0.5) / (obs_before + 0.5)
    lag_mean                FLOAT           NULL,
    lag_sd                  FLOAT           NULL,
    same_visit_frac         FLOAT           NULL,
    util_ratio              FLOAT           NULL,
    obs_ab_exp_mh           FLOAT           NULL, -- CMH decile-stratified expected count
    CONSTRAINT pk_udm_pair_summary PRIMARY KEY (site_id, release_id, calendar_era_id, pair_type, concept_a, concept_b)
);
```

#### 4. Multi-Site Synthesized Knowledge Graph (`taxis_udm_synthesized_graph`)
The central consolidated evidence table containing pooled meta-analytic effect sizes, empirical uncertainty intervals, and between-database heterogeneity diagnostics.

```sql
CREATE TABLE taxis_udm_synthesized_graph (
    pair_type               INT             NOT NULL,
    concept_a               BIGINT          NOT NULL,
    concept_b               BIGINT          NOT NULL,
    concept_name_a          VARCHAR(255)    NOT NULL,
    concept_name_b          VARCHAR(255)    NOT NULL,
    n_contributing_sites    INT             NOT NULL,
    total_obs_all           BIGINT          NOT NULL,
    pooled_lift_after       FLOAT           NOT NULL,
    pooled_lift_ci_lower    FLOAT           NOT NULL,
    pooled_lift_ci_upper    FLOAT           NOT NULL,
    pooled_lift_pi_lower    FLOAT           NOT NULL, -- 95% Prediction Interval lower bound
    pooled_lift_pi_upper    FLOAT           NOT NULL, -- 95% Prediction Interval upper bound
    pooled_dr               FLOAT           NOT NULL, -- Pooled Directionality Ratio
    pooled_dr_ci_lower      FLOAT           NOT NULL,
    pooled_dr_ci_upper      FLOAT           NOT NULL,
    i_squared_lift          FLOAT           NOT NULL, -- Between-site heterogeneity (0.0 to 100.0%)
    tau_squared_lift        FLOAT           NOT NULL, -- Between-site variance
    cochran_q_lift          FLOAT           NOT NULL,
    cochran_p_value         FLOAT           NOT NULL,
    consensus_direction     VARCHAR(50)     NOT NULL, -- 'FORWARD_A_TO_B', 'REVERSE_B_TO_A', 'SYMMETRIC'
    heterogeneity_grade     VARCHAR(20)     NOT NULL, -- 'LOW' (<25%), 'MODERATE' (25-75%), 'HIGH' (>75%)
    clinical_edge_type      VARCHAR(50)     NULL,     -- e.g., 'indication', 'adverse_reaction', 'risk_factor'
    synthesis_timestamp     TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_udm_synthesized PRIMARY KEY (pair_type, concept_a, concept_b)
);
```

---

## 3. Statistical Meta-Analytic Synthesis & Uncertainty Bounds (Proposed Specification)

When pooling observational associations across $K$ distinct health systems ($s = 1, \dots, K$), fixed-effects models are methodologically inappropriate because baseline patient demographics, formulary policies, and clinical practice vary across sites. As part of the proposed central synthesis architecture, TAXIS specifies a **Random-Effects Meta-Analytic Model (DerSimonian-Laird and Restricted Maximum Likelihood, REML)** to estimate the global distribution of association parameters across participating sites.

### 3.1 Random-Effects Pooling for Association Lift ($\text{Lift}$)

Let $Y_s = \ln(\text{Lift}_{\text{after}, s})$ denote the log-transformed lift observed at site $s$. The within-site standard error $\sigma_s$ is derived from the Poisson exposure count $O_{\text{after}, s}$ and marginal counts via the delta method:

$$
\sigma_s = \sqrt{\frac{1}{O_{\text{after}, s}} + \frac{1}{O_{A, s}} + \frac{1}{O_{B, s}}}
$$

Under the random-effects assumption:

$$
Y_s \sim \mathcal{N}(\mu, \sigma_s^2 + \tau^2)
$$

where $\mu$ is the global mean log-lift, and $\tau^2$ is the between-site heterogeneity variance.

#### 1. Estimating Between-Site Variance ($\tau^2$) via DerSimonian-Laird:
Let $w_{0s} = 1 / \sigma_s^2$. The Cochran's $Q$ statistic is:

$$
Q = \sum_{s=1}^K w_{0s} (Y_s - \bar{Y}_0)^2, \quad \text{where } \bar{Y}_0 = \frac{\sum_{s=1}^K w_{0s} Y_s}{\sum_{s=1}^K w_{0s}}
$$

The between-site variance $\tau^2$ is estimated as:

$$
\tau^2 = \max\left(0, \frac{Q - (K - 1)}{\sum_{s=1}^K w_{0s} - \frac{\sum_{s=1}^K w_{0s}^2}{\sum_{s=1}^K w_{0s}}}\right)
$$

#### 2. Random-Effects Weighting and Pooled Effect:
The random-effects weight for site $s$ is:

$$
w_s = \frac{1}{\sigma_s^2 + \tau^2}
$$

The pooled log-lift and pooled lift are:

$$
\hat{\mu} = \frac{\sum_{s=1}^K w_s Y_s}{\sum_{s=1}^K w_s}, \quad \text{Lift}_{\text{pooled}} = \exp(\hat{\mu})
$$

Standard error of the pooled estimate:

$$
\text{SE}(\hat{\mu}) = \frac{1}{\sqrt{\sum_{s=1}^K w_s}}
$$

95% Confidence Interval for the mean global lift:

$$
\text{CI}_{95\%} = \left[ \exp\left(\hat{\mu} - 1.96 \cdot \text{SE}(\hat{\mu})\right), \; \exp\left(\hat{\mu} + 1.96 \cdot \text{SE}(\hat{\mu})\right) \right]
$$

---

### 3.2 Quantifying Between-Database Heterogeneity ($I^2$)

To evaluate whether an association is universally consistent or heavily dependent on database type (e.g., claims vs. EHR), TAXIS computes the Higgins & Thompson $I^2$ statistic:

$$
I^2 = \max\left(0, \frac{Q - (K - 1)}{Q}\right) \times 100\%
$$

#### Heterogeneity Classification & Research Evaluation:
- **Low Heterogeneity ($I^2 < 25\%$)**: Indicates low between-database variation in observed effect sizes across the evaluated cohorts; transportability to unstudied settings remains a hypothesis to evaluate empirically.
- **Moderate Heterogeneity ($25\% \le I^2 \le 75\%$)**: Reflects observed variation in effect magnitude across databases, which may stem from differences in healthcare delivery, coding practices (e.g., inpatient vs. ambulatory claims), or population case-mix.
- **High Heterogeneity ($I^2 > 75\%$)**: Flagged for sensitivity analysis. Indicates substantial database-specific variation, which may arise from local formulary restrictions, reimbursement policies, or divergent coding practices.

---

### 3.3 Uncertainty Quantification: Confidence vs. Prediction Intervals

A standard 95% Confidence Interval reflects only the precision of the *mean* pooled estimate. However, for a clinician or researcher evaluating the potential distribution of effects in a *comparable new healthcare database*, the relevant parameter is the **95% Prediction Interval (PI)**, which incorporates both sampling error and between-site variance $\tau^2$:

$$
\text{PI}_{95\%} = \left[ \exp\left(\hat{\mu} - t_{K-2, 0.975} \sqrt{\tau^2 + \text{SE}(\hat{\mu})^2}\right), \; \exp\left(\hat{\mu} + t_{K-2, 0.975} \sqrt{\tau^2 + \text{SE}(\hat{\mu})^2}\right) \right]
$$

where $t_{K-2, 0.975}$ is the critical value from Student's $t$-distribution with $K-2$ degrees of freedom.

#### Small-Sample Degree-of-Freedom Boundary ($K < 3$):
- Calculation of the prediction interval strictly requires **$K \ge 3$ sites** ($K - 2 \ge 1$ positive degrees of freedom for Student's $t$-distribution).
- For analyses with **$K < 3$ sites** (e.g., a two-site synthesis), degrees of freedom $K - 2 \le 0$ cannot support a valid critical value; the synthesis engine explicitly sets $\text{PI}_{95\%\text{, lower}} = \text{NA}$ and $\text{PI}_{95\%\text{, upper}} = \text{NA}$.
- When $K \ge 3$, if the lower bound of the 95% Prediction Interval remains $> 1.0$, it indicates that the estimated association is expected to remain positive in comparable future populations drawn from the same universe of healthcare settings, subject to the assumptions of the random-effects model (see Cochrane Handbook, Chapter 10, sections 10.10.2–10.10.4).

---

### 3.4 Multi-Site Directionality Synthesis ($DR_{\text{pooled}}$)

Directional counts across sites ($O_{\text{after}, s}$ and $O_{\text{before}, s}$) are synthesized using logit-transformed random-effects pooling or exact binomial-normal hierarchical models.

Let $\theta_s = \ln(DR_{\text{corrected}, s}) = \ln\left(\frac{O_{\text{after}, s} + 0.5}{O_{\text{before}, s} + 0.5}\right)$.

Variance of the log-directionality ratio:

$$
\sigma_{DR, s}^2 = \frac{1}{O_{\text{after}, s} + 0.5} + \frac{1}{O_{\text{before}, s} + 0.5}
$$

Random-effects pooling across sites yields $\hat{\theta}_{\text{pooled}}$ and:

$$
DR_{\text{pooled}} = \exp(\hat{\theta}_{\text{pooled}})
$$

Consensus Directionality Assignment:
- **Consensus Forward ($A \to B$)**: $DR_{\text{pooled}} \ge 1.50$, $p < 0.01$, with lower $95\% \text{ CI} > 1.20$.
- **Consensus Reverse ($B \to A$)**: $DR_{\text{pooled}} \le 0.67$, $p < 0.01$, with upper $95\% \text{ CI} < 0.83$.
- **Consensus Symmetric / Concurrent**: $0.67 < DR_{\text{pooled}} < 1.50$, or non-significant binomial test.

---

## 4. Protocol for Data Refreshes, Temporal Shifts & Calendar Eras

Observational databases are dynamic: sites release semi-annual refreshes, cumulative calendar years are appended, and coding vocabularies change over time. TAXIS enforces a formal protocol to govern data refreshes without corrupting longitudinal consistency.

### 4.1 Release Immutability & Compound Key Versioning

1. **No In-Place Overwrites**: When a site re-runs the pipeline on a newly refreshed CDM, the data is tagged with an incremented `release_id` (e.g., `INPC_2025Q4` $\to$ `INPC_2026Q2`). Prior releases remain archived in the UDM.
2. **Compound Entity Resolution**: All analytical queries join on `(site_id, release_id, calendar_era_id)`. Active knowledge graph builds specify the latest authoritative release per site.

### 4.2 Calendar Era Partitioning (`calendar_era_id`)

Longitudinal healthcare data contains major structural macro-shifts, such as the US transition from ICD-9-CM to ICD-10-CM on October 1, 2015, and the COVID-19 pandemic healthcare disruptions of 2020–2022. To prevent temporal confounding when a site adds new calendar years, the pipeline supports execution across standardized calendar eras:

```text
┌─────────────────┬──────────────────────┬────────────────────────────────────────────────────────┐
│ Era Identifier  │ Calendar Interval    │ Epidemiological & Structural Rationale                 │
├─────────────────┼──────────────────────┼────────────────────────────────────────────────────────┤
│ ERA_PRE_ICD10   │ 2010-01-01 to 2015-09│ Pre-ICD-10 baseline; homogeneous legacy coding.        │
│ ERA_POST_ICD10  │ 2015-10-01 to 2019-12│ Modern ICD-10 baseline prior to pandemic disruption.   │
│ ERA_COVID       │ 2020-01-01 to 2022-12│ Pandemic period; marked shift in acute respiratory     │
│                 │                      │ visits, telehealth utilization, and mortality coding.  │
│ ERA_CONTEMP     │ 2023-01-01 to Present│ Post-pandemic contemporary clinical practice.         │
│ ERA_ALL_TIME    │ Full Longitudinal    │ Complete available historical record (default run).    │
└─────────────────┴──────────────────────┴────────────────────────────────────────────────────────┘
```

### 4.3 Automated Refresh Regression & Stability Testing

Whenever a participating database site submits a refreshed data package, the central TAXIS ingestion suite executes an automated drift validation harness:

1. **Concept Marginal Concordance**: Pearson correlation of log-marginal counts ($\ln(N_A)$) for the top 5,000 concepts must exceed $\rho \ge 0.99$ between consecutive releases.
2. **Bivariate Association Stability**: Rank-order Spearman correlation for the top 20,000 concept pairs must satisfy $\rho \ge 0.98$ for $\text{Lift}_{\text{after}}$ and $DR_{\text{corrected}}$.
3. **Outlier Anomaly Detection**: Any concept pair whose pooled lift shifts by more than $3 \times \tau$ is quarantined and output to an audit report for clinician review before merging into the active graph.

---

## 5. Multi-Site Federation Roadmap & Feasibility Gates

The multi-site federation architecture unfolds across staged milestones, conditioned on empirical engineering feasibility gates:

```text
┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                   TAXIS FEDERATION & UDM ROADMAP                                       │
├────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                        │
│   Phase 1: Indiana Network for Patient Care (INPC) Baseline [COMPLETE]                                 │
│   • 2.16M patient production run, 14.2M observed pairs, 1.88B facts, 18 tables materialized.           │
│   • Verified PostgreSQL runner on local synthetic OMOP fixture; SQL Server runner unverified on R.     │
│                                                                                                        │
│   Phase 2: Partner Site 1-Batch Pilot Verification [CURRENT PHASE]                                     │
│   • Lightweight single-batch verification across partner OHDSI nodes via CodeToRun.R.                  │
│   • Validates database permissions, JDBC connectivity, and receipt generation.                         │
│                                                                                                        │
│   [FEASIBILITY GATE]: Single-Pair 2-Site Synthetic Meta-Analysis Benchmark (Prerequisite to Phase 3)    │
│   • Minimal standalone test: synthesize one ordered pair across two synthetic site records.            │
│   • Explicit input schema, deterministic masked (<5) handling, independently verified reference math.  │
│                                                                                                        │
│   Phase 3: UDM Schema Deployment & Commercial Data Ingestion [PROPOSED FUTURE]                         │
│   • Stand up central UDM PostgreSQL repository (taxis_udm_* schema).                                   │
│   • Define and vet aggregate pair-level export specification (cab_s55_pair_all with <5 suppression).   │
│   • Ingest initial commercial claims datasets (Merative MarketScan, Optum Clinformatics).              │
│                                                                                                        │
│   Phase 4: Federated Meta-Analytic Synthesis Engine [PROPOSED FUTURE]                                  │
│   • Automated synthesis module computing random-effects pooled lift, pooled DR, and prediction bounds. │
│   • Generation of the master multi-network Clinical Knowledge Graph substrate.                         │
│                                                                                                        │
│   Phase 5: Public Knowledge Graph Explorer & Longitudinal Refresh Pipeline [PROPOSED FUTURE]           │
│   • Web-based research portal for exploring pooled associations and site-specific forest plots.        │
│   • Semi-annual automated refresh pipeline with era-based temporal drift tracking.                     │
│                                                                                                        │
└────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### 5.1 Initial Engineering Feasibility Gate (Prerequisite to Phase 3)

Prior to initiating central UDM database deployment or commercial claims ingestion, the project requires an explicit, reproducible engineering proof-of-concept benchmark:
1. **Single Concept Pair Synthesis Demonstration**: Author a standalone test synthesizing one ordered concept pair across two synthetic site records.
2. **Explicit Input Schema**: Standardize the minimal required inputs: site identifier, observed counts ($O_{\text{after}}, O_{\text{before}}, O_{\text{same\_day}}$), marginal counts ($O_A, O_B$), background observation person-days, and derived variance $\sigma_s^2$.
3. **Deterministic Edge-Case Handling**: Verify mathematically correct handling of small-cell suppression (masked counts $< 5 \to -1$, assigning unavailable variance) and empty/zero-count pairs without runtime failure.
4. **Reference Result Comparison**: Assert pooled lift, Cochran's $Q$, $I^2$, and pooled $DR$ against an independently computed hand-calculation.
5. *Boundary Note*: Passing this gate demonstrates synthetic arithmetic and schema validation correctness; it does not assert data transport feasibility, pipeline integration, or clinical validity across real healthcare databases.

---

## 6. Summary of Authoritative Decisions & Governance Alignment

1. **Core Scope & Repository Positioning (`DEC-GR-027`)**:
   TAXIS is fundamentally an association mining study package and federated aggregate dataset generator, not an end-user cohort builder or classifier application. The UDM and meta-analysis engine provide the empirical substrate; downstream clinical tools consume UDM outputs as read-only downstream clients.
2. **Three-Channel Data Distribution Model (`DEC-GR-028`)**:
   - **Channel 1 (Bulk Data Dumps for Researchers)**: Shared via secure academic cloud/SFTP under Data Use Agreements (DUA) and IRB approval where applicable, or open distribution of privacy-safe aggregate datasets where permitted.
   - **Channel 2 (Zero Bulk Data in Git Repository)**: Strict exclusion of bulk data matrices or unsuppressed aggregates from the git repository.
   - **Channel 3 (Public Web Explorer)**: Prospective read-only research portal serving small-cell suppressed aggregates ($< 5 \to -1$) with authenticated database credentials. (Note: Public API and formal privacy certification remain unestablished prospective proposals).
3. **Companion Demonstration Prototypes (`DEC-GR-029`)**:
   Prototypes in `extras/` (`TaxisPhenotypeCreator`, `TaxisPhenotypeEvaluation`, `build_1032.py`) are illustrative demonstrations, not production tools.
4. **Phased Partner Rollout Protocol (`DEC-GR-030`)**:
   Partner sites participate via Phase A (single-batch verification) before advancing to Phase B (40-batch full-cohort production).
5. **Scholarly Human Voice Documentation Standard (`DEC-GR-031`)**:
   Public documentation and study guides are authored in clear, scholarly human prose rather than mechanical phrasing.
6. **Medical & Scientific English Standard (`DEC-GR-032`)**:
   All mathematical derivations, statistical parameters, and cross-site syntheses use rigorous medical informatics and epidemiological vocabulary. Observational events do not "travel together"—they **empirically co-occur** and exhibit **temporal association**.
