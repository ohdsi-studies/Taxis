/* ==============================================================================
TAXIS Concept AB Association Mining Engine (Pipeline v57)
Script: concept_ab_init.sql — ONE-TIME SETUP (runs once, before the batch loop)

ORIGINAL AUTHORSHIP, FULL CREDIT & SCIENTIFIC ATTRIBUTION:
  ALL SQL in this pipeline was conceived, designed, and written by:
    Stephen H. Bandeian, MD, JD
    Principal Investigator, Johns Hopkins University School of Medicine

  Full credit, primary authorship, and intellectual attribution for all SQL code,
  database architectures, 40-batch random partitioning strategies, continuity-corrected
  directionality formulations, and analytical algorithms belong to Dr. Stephen H. Bandeian.

STUDY LEADERSHIP:
  • Stephen H. Bandeian, MD, JD – Principal Investigator & Author of all SQL & Analytic Code
  • J. Marc Overhage, MD, PhD – Co-Principal Investigator, The Overhage Group / Indiana Univ
  • Gowtham Rao, MD, PhD – Investigator, CoReason, Inc. / OHDSI
  • Shaun Grannis, MD, MS – Investigator, Regenstrief Institute / Indiana Univ
==============================================================================

WHAT THIS DOES / WHY
--------------------
The CONCEPT_AB pipeline measures how often pairs of clinical concepts
co-occur in patient records, so that meaningful clinical relationships
can be told apart from incidental "innocent-bystander" co-occurrences.
Because the full patient population is too large to process at once, the
work is split into batches. This init script does the two things that
must happen exactly ONCE, before any batch runs:

  1. Assigns every person in the CDM to a batch (all_persons_batch),
     using a random, evenly-sized partition into @batch_count groups.
     This must be built once and left stable: if it were rebuilt per
     batch, the random assignment would reshuffle and scramble which
     persons belong to which batch.

  2. Creates the empty CUMULATIVE result tables that every batch appends
     into. The batch loop fills these; finalize rolls them up.

       THE STATISTICS
         cab_s10_person_cum      persons, person-days, visits, utilization
         cab_s20_marginal_cum    per-concept counts by src, anchor and interval.
                               The interval_code and person_days_at_risk
                               columns are used only by anchor 4, the chronic
                               onset cohort: its expected value is a rate over
                               person-days at risk rather than a count over a
                               window width, because a person diagnosed shortly
                               before their record ends is at risk for the early
                               bands only. Every other anchor carries
                               interval_code 0 and a null person_days_at_risk.
         cab_s30_cum             pair co-occurrence, keyed by pair type,
                                 anchor and time interval

       UTILIZATION ADJUSTMENT
         cab_s13_strat_cum       person-days by utilization decile
         cab_s23_strat_cum       concept marginals by decile
         cab_s33_strat_cum       pair counts by decile

       DESCRIPTIVE, written only for batch_number <= the profiling limit and
       feeding nothing in cab_s40/cab_s50
         meas_obs_profile_s35_cum    which result fields are populated
         meas_obs_attribute_s36_cum  the attribute ids behind them
         cab_s37_lag_cum             lag decay out to +/- 400 days
         cab_s38_profile_cum         eligibility, visit linkage, intake, span
         cab_s39_pattern_cum         per-concept gap and span histograms

Nothing here is patient-specific or batch-specific — it is pure scaffolding.

PREREQUISITES
-------------
- The OMOP CDM person table must exist in @source_cdm_schema.
- @results_database_schema must be writable.

PARAMETERS
----------
  @source_cdm_schema        -- OMOP CDM (source of the person table)
  @results_database_schema  -- where the cumulative tables are created
  @batch_count              -- number of batches to partition persons into
  @create_index_ddl         -- whether to emit create index statements (default: true)

NOTE. init takes no profiling parameter. The descriptive tables are CREATED
here unconditionally and empty; whether a given batch WRITES to them is decided
in the batch script by @data_profile_batch_limit.
========================================================= */

{DEFAULT @create_index_ddl = true}


-- =====================================================
-- cab_process_log: per-step timestamp log for the batch script.
-- One row is appended at the end of each numbered step in
-- concept_ab_batch.sql (step 0 = batch start). Step duration is the
-- difference between consecutive step_datetime values within a batch.
-- Created once here so the log accumulates across the batch loop.
-- =====================================================
drop table if exists @results_database_schema.cab_process_log;

create table @results_database_schema.cab_process_log (
  batch_number   int           null,
  table_name     varchar(100)  null,
  step           int           null,
  step_datetime  datetime      null
);



drop table if exists @results_database_schema.cab_s10_person_cum;

-- visits_in_batch: distinct visits for the batch's persons, off cab_s01_visit.
-- Needed for same_visit_frac's null -- two unrelated events land on the same
-- visit with probability about 1 / (visits in the window), so without visit
-- density there is no way to say whether an observed same_visit_frac is above
-- chance or below it.
-- person_days_clear_batch: person-days lying at least 90 days inside both
-- observation-period edges, i.e. (period_length - 180) floored at 0. This is
-- the denominator that matches the *_clear event counts in cab_s20/cab_s30,
-- where every event is guaranteed a full +/-@window_days of window inside the
-- period. Lift computed on the clear subset carries no edge truncation.
create table @results_database_schema.cab_s10_person_cum (
  batch_number           int     null,
  persons_in_batch       bigint  null,
  person_days_in_batch   bigint  null,
  person_days_clear_batch bigint null,
  util_sum_batch         bigint  null,
  util_sq_batch          bigint  null,
  visits_in_batch        bigint  null
);


drop table if exists @results_database_schema.cab_s20_marginal_cum;

create table @results_database_schema.cab_s20_marginal_cum (
  batch_number    int     null,
  concept_id      bigint  not null,
  src             int     not null,
  anchor_code     smallint not null,
  interval_code   smallint not null,
  n_obs_batch     bigint  null,
  n_persons_batch bigint  null,
  n_obs_fm_batch  bigint  null,
  n_persons_fm_batch  bigint  null,
  max_per_person  bigint  null,
  n_obs_sq_batch    bigint  null,
  n_obs_clear_batch bigint  null,
  n_util_sum_batch  bigint  null,
  n_persons_fm_incident_batch bigint null,
  person_days_at_risk bigint null
);


-- =====================================================
-- cab_s30_cum: ALL co-occurrence counts, one row shape.
-- Key: pair_type, anchor_code, interval_code, concept_a, concept_b.
-- Direction and same-day are ROWS, not columns, which removes the
-- direction x first-mention cross product of the previous 43-column version.
--
-- anchor_code   1 ALL every A event | 2 TRIGGER trigger_flag = 1 procedures |
--               3 ELIGIBLE A events with >= 365 + @window_days days of
--               follow-up left. Anchor 3 repeats intervals 1-3 so the
--               reference intervals are read off the SAME anchors -- otherwise
--               the ratio is inflated by the eligible fraction.
-- interval_code 1 delta 0 | 2 delta +1..+W | 3 delta -W..-1 |
--               4 delta +182..+182+W | 5 delta +365..+365+W |
--               6 delta +W+1..+2W (trigger only)
--
-- Intervals 4 and 5 are a BASELINE, not a search for late co-occurrence: a
-- within-person expected value that replaces lift's population expected, which
-- assumes a concept is as likely in a healthy person as in a heavy utilizer.
-- =====================================================
drop table if exists @results_database_schema.cab_s30_cum;
create table @results_database_schema.cab_s30_cum (
  batch_number       int      null,
  pair_type          smallint not null,
  anchor_code        smallint not null,
  interval_code      smallint not null,
  concept_a          bigint   not null,
  concept_b          bigint   not null,
  obs                bigint   not null,
  obs_fma            bigint   not null,
  obs_fmb            bigint   not null,
  obs_fmab           bigint   not null,
  obs_fmab_inc       bigint   not null,
  obs_clear          bigint   not null,
  obs_same_visit     bigint   not null,
  obs_sq             bigint   not null,
  pers               bigint   not null,
  pers_fma           bigint   not null,
  pers_fmb           bigint   not null,
  pers_fmab          bigint   not null,
  pers_fmab_inc      bigint   not null,
  pers_same_visit    bigint   not null,
  lag_sum            bigint   not null,
  lag_abs_sum        bigint   not null,
  lag_sq             bigint   not null,
  util_sum           bigint   null,
  util_n             bigint   not null,
  fm_intake_days_a   bigint   null,
  fm_intake_days_b   bigint   null
);







-- =====================================================
-- STRATIFIED COUNT TABLES  (cab_s13 / cab_s23 / cab_s33)
-- The same counts as cab_s10 / cab_s20 / cab_s30, broken out by the person's
-- utilization decile, so finalize can build the expected INSIDE each decile
-- and sum:  E_k = obs_a_k * obs_b_k * win_w / person_days_k.
-- Lift's expected uses one population-average rate per concept, which assumes
-- a concept is as likely in a healthy person as in a heavy utilizer; it is
-- not, so lift is inflated for every pair whether or not it is related.
-- These tables store RAW COUNTS ONLY and commit to no estimator, so finalize
-- can compute Mantel-Haenszel, a stratified odds ratio, direct
-- standardisation or any reweighting, and be rewritten without re-harvesting.
-- =====================================================
drop table if exists @results_database_schema.cab_s13_strat_cum;
create table @results_database_schema.cab_s13_strat_cum (
  batch_number          int     null,
  util_decile           int     not null,
  persons_in_decile     bigint  null,
  person_days_in_decile bigint  null
);

drop table if exists @results_database_schema.cab_s23_strat_cum;
create table @results_database_schema.cab_s23_strat_cum (
  batch_number        int     null,
  concept_id          bigint  not null,
  src                 int     not null,
  util_decile         int     not null,
  n_obs_batch         bigint  null,
  n_persons_batch     bigint  null,
  n_obs_fm_batch      bigint  null,
  n_persons_fm_batch  bigint  null
);

-- cab_s33: ten non-measurement pair types. Rows per pair are
-- min(pers_ab, 10), not 10 -- a pair occurring in six persons spans at most
-- six deciles -- and low-count pairs dominate, so the realistic multiplier
-- is well under ten.
drop table if exists @results_database_schema.cab_s33_strat_cum;
create table @results_database_schema.cab_s33_strat_cum (
  batch_number     int      null,
  pair_type        smallint not null,
  concept_a        bigint   not null,
  concept_b        bigint   not null,
  util_decile      int      not null,
  obs_ab_act       bigint   not null,
  obs_ab_act_fmab  bigint   not null,
  pers_ab          bigint   not null
);


-- =====================================================
-- cab_s39_pattern_cum: how each concept is RECORDED OVER TIME.
--
-- Which lift variant is meaningful for a pair depends on the recording
-- pattern of each concept, and mentions_per_person -- the only persistence
-- measure otherwise available -- cannot separate three of the five patterns:
--
--   punctate   one occurrence per person, ever      mentions/person about 1
--   clustered  several records, ONE clinical event  mentions/person about 3
--   recurrent  several records, SEVERAL events      mentions/person about 3
--   chronic    regular records, one lasting state   mentions/person 8 or more
--   episodic   several events, each several records mentions/person about 6
--
-- Clustered, recurrent and episodic all read about the same on
-- mentions_per_person and need different handling: three films for one ankle
-- injury are one event counted three times, three separate UTIs are three
-- events, and collapsing either to a first mention is right for the first and
-- wrong for the second. What separates them is the GAP between consecutive
-- mentions within a person, which needs event dates and therefore cannot be
-- reconstructed once the staging tables drop.
--
-- Stored as a HISTOGRAM rather than as moments because episodic is bimodal:
-- gaps at 3 days and at 300 days give a mean of 150, which describes nothing
-- that exists. Buckets show the two modes.
--
-- metric  gap   days since the same person's previous mention of the concept
--         span  first to last mention of the concept within one person
-- bucket  the UPPER EDGE in days; 999 is everything beyond the last edge.
--
-- Six staging tables: condition, procedure, device, drug, observation test and
-- measurement test. The two result tables are excluded -- a result key is its
-- test concept plus a value, so its recording TIMING is the test's timing and
-- is already captured at test level.
-- =====================================================
drop table if exists @results_database_schema.cab_s39_pattern_cum;

create table @results_database_schema.cab_s39_pattern_cum (
  batch_number  int          null,
  metric        varchar(6)   not null,
  src           int          not null,
  concept_id    bigint       not null,
  bucket        int          not null,
  n_obs         bigint       null,
  n_persons     bigint       null
);


-- =====================================================
-- DESIGN PROFILING TABLES (cab_s37, cab_s38)
-- Like s35/s36 these feed nothing in the statistics pipeline. They record the
-- IU distributions that the current design choices were made WITHOUT -- the
-- +/-@window_days near window, the 182 and 365 day reference offsets, the
-- >= 365 + @window_days eligibility filter, and fm_early_flag's 30-day cut are
-- all currently guesses. Both are written only for batch_number <= 2, which is
-- a 10% random sample since persons are randomly partitioned.
-- =====================================================
-- cab_s37_lag_cum: lag decay out to +/- 400 days (lag_bucket: delta/10, -999 and 999 are tails)
drop table if exists @results_database_schema.cab_s37_lag_cum;
create table @results_database_schema.cab_s37_lag_cum (
  batch_number  int      null,
  pair_type     smallint not null,
  lag_bucket    int      not null,
  n_events      bigint   null,
  n_pairs       bigint   null
);

-- metric: 'eligible' anchor-3 survival | 'visitlink' visit_occurrence_id
-- coverage | 'intake' days from enrollment to first mention, 30-day buckets |
-- 'obsspan' observed days per person, 180-day buckets | 'nspans' spans per person
drop table if exists @results_database_schema.cab_s38_profile_cum;
create table @results_database_schema.cab_s38_profile_cum (
  batch_number  int          null,
  metric        varchar(20)  not null,
  src           int          not null,
  bucket        int          not null,
  n_records     bigint       null,
  n_persons     bigint       null
);


-- =====================================================
-- meas_obs_profile_s35_cum
-- Adjudication profile: for each test concept, which result-bearing
-- fields are populated. One row per concept x flag pattern, counting
-- records. Descriptive only; NOT part of the cab_s30 pipeline.
--
-- src: 50 = observation, 60 = measurement.
--
-- has_* = 1 only when the column holds usable information: for concept
-- columns that means not null AND not 0 (a 0 is a failed mapping, which
-- for adjudication purposes is the same as absent); for value_as_number
-- and the range bounds it means not null; for value_as_string it means
-- not null and not empty.
--
-- Flags that do not exist in the source table are stored NULL, not 0,
-- so that "column absent from this domain" stays distinguishable from
-- "column present but empty":
--   has_value_string, has_qualifier            -- observation only
--   has_operator, has_range_low, has_range_high -- measurement only
-- =====================================================
drop table if exists @results_database_schema.meas_obs_profile_s35_cum;

create table @results_database_schema.meas_obs_profile_s35_cum (
  src                  int     not null,
  meas_obs_concept_id  bigint  null,
  has_value_concept    int     null,
  has_value_number     int     null,
  has_value_string     int     null,
  has_unit             int     null,
  has_qualifier        int     null,
  has_operator         int     null,
  has_range_low        int     null,
  has_range_high       int     null,
  n_records            bigint  null
);


-- =====================================================
-- meas_obs_attribute_s36_cum
-- Attribute detail behind the s35 flags: for each test concept, the
-- actual concept ids found in the result-modifying columns, with record
-- counts. This is what s35 cannot show -- e.g. has_unit = 1 hides the
-- case of one measurement concept carrying two different units, which
-- silently breaks any threshold logic downstream.
--
-- attribute / attribute_id pairs:
--   'VALUE_CONCEPT'  value_as_concept_id    (both domains)
--   'UNIT'           unit_concept_id        (both domains)
--   'QUALIFIER'      qualifier_concept_id   (observation only)
--   'OPERATOR'       operator_concept_id    (measurement only)
--
-- Null attribute ids are excluded (s35 already counts those via the
-- has_* flags); 0 is retained, since a high-volume 0 means the ETL
-- attempted the mapping and failed, which is a different finding from
-- the column never being populated.
-- =====================================================
drop table if exists @results_database_schema.meas_obs_attribute_s36_cum;

create table @results_database_schema.meas_obs_attribute_s36_cum (
  src                  int          not null,
  meas_obs_concept_id  bigint       null,
  attribute            varchar(15)  null,
  attribute_id         bigint       null,
  n_records            bigint       null
);


-- =====================================================
-- all_persons_batch: one-time partition of ALL persons in the CDM
-- into @batch_count batches. Built ONCE in init (not per-batch),
-- so batch assignments are stable across the batch loop.
--
-- person_id is deduplicated first. The CDM makes it the primary key of the
-- person table, but a duplicate would be carried into every batch and then
-- multiply six of the staging tables through their join to cab_person_attr,
-- which is built one row per batch row rather than one row per person. The
-- dedup must precede the ntile: written as
--   select distinct person_id, ntile(...) over (order by newid())
-- the window function is evaluated first, every row receives its own batch
-- number, and the distinct finds nothing to remove.
-- =====================================================
drop table if exists @results_database_schema.all_persons_batch;

with s1 as (
select
  distinct a.person_id
from @source_cdm_schema.person a
)
select
  a.person_id,
  ntile(@batch_count) over (order by newid()) as batch_number
into @results_database_schema.all_persons_batch
from s1 a
;

{@create_index_ddl} ? {
create index idx_apb_batch on @results_database_schema.all_persons_batch (batch_number);
create index idx_apb_pid on @results_database_schema.all_persons_batch (person_id);
}