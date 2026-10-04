/* ==============================================================================
TAXIS Concept AB Association Mining Engine (Pipeline v57)
Script: concept_ab_finalize.sql (SqlRender) — ROLLUP & STATISTICAL FINALIZATION

ORIGINAL AUTHORSHIP, FULL CREDIT & SCIENTIFIC ATTRIBUTION:
  ALL SQL in this pipeline was conceived, designed, and written by:
    Stephen H. Bandeian, MD, JD
    Principal Investigator, Johns Hopkins University School of Medicine

  Full credit, primary authorship, and intellectual attribution for all SQL code,
  database architectures, rollup procedures, healthcare utilization decile
  stratification, continuity-corrected directionality formulations, and
  underlying analytic algorithms belong to Dr. Stephen H. Bandeian.

STUDY LEADERSHIP:
  • Stephen H. Bandeian, MD, JD – Principal Investigator & Author of all SQL & Analytic Code
  • J. Marc Overhage, MD, PhD – Co-Principal Investigator, The Overhage Group / Indiana Univ
  • Gowtham Rao, MD, PhD – Investigator, CoReason, Inc. / OHDSI
  • Shaun Grannis, MD, MS – Investigator, Regenstrief Institute / Indiana Univ
==============================================================================

WHAT THIS DOES / WHY
--------------------
   Runs ONCE after all batches. Rolls the per-batch cumulative tables
   (cab_s10/s20/s30/s13/s23/s33/s35/s36/s37/s38/s39_cum) up into _all tables,
   then computes the
   association statistics: for every concept pair, how much more (or
   less) often the two co-occur than chance predicts (LIFT), used to
   separate genuine clinical relationships from incidental co-occurrence.
 
   Before s50 it builds cab_vocab_all_output, a name/domain/vocab lookup for
   every concept in cab_s20_marginal_all (plain concepts, and the packed
   meas/obs test-result keys decoded to a test: result label). s50 then joins
   it twice to label concept_a / concept_b (concept_name_a, concept_name_b).
 
   Finally builds cab_timing_all, a rollup of cab_process_log (run timing
   by batch and averaged across batches) for export/inspection.
 
   All _all output tables this step builds are exported as CSVs and returned
   (see README step 6). All 16 are exported; the list below is grouped by what
   each is for rather than by build order.

     THE STATISTICS
       cab_s55_pair_all      one row per pair, anchor 1, intervals pivoted, with
                             the recording-pattern guidance attached. Start here.
       cab_s50_all           one row per pair per anchor per interval -- the same
                             numbers unpivoted, for looking things up.
       cab_s40_all           counts joined to marginals, with the expected values
       cab_s30_all           raw pair counts

     DENOMINATORS AND LOOK-UPS
       cab_s10_person_all    persons, person-days, visits, utilization moments
       cab_s20_marginal_all  per-concept counts by src and anchor
       cab_vocab_all_output  name, domain and vocab for every concept id

     UTILIZATION ADJUSTMENT
       cab_s13_strat_all     persons and person-days by utilization decile
       cab_s23_strat_all     concept marginals by decile
       cab_s33_strat_all     pair counts by decile -- re-poolable, deciles sum
                             into quintiles or any other grouping without a re-run
       cab_s33_mh_all        the decile-adjusted expected, one row per pair

     DATA CHARACTERISATION (from the profiling batches only)
       cab_s39_pattern_all   gap and span histograms per concept
       cab_s54_grain_guide   the recording pattern each concept implies, and
                             which mention grain to read for it
       cab_s37_lag_all       lag decay, for checking the window widths
       cab_s38_profile_all   eligibility, visit linkage, intake and span
       meas_obs_profile_s35_all    which result fields are populated
       meas_obs_attribute_s36_all  the actual attribute ids behind them

     RUN TIMING
       cab_timing_all        rolled up from cab_process_log -- plus the log itself
 
   Statistics at two levels: EVENT (rate-based expected using the
   +/-@window_days-day window) and PERSON (prevalence-based expected).
   Both ALL-MENTION and FIRST-MENTION (fm) grains are carried through,
   so lift can be assessed with or without collapsing repeating concepts
   to their first occurrence. fm grains: fma (first-A), fmb (first-B),
   fmab (both-first).
 
   Same-type pairs (1010/2020/3030) are mirrored at s40 by swapping raw
   counts/marginals (fma<->fmb, a_before_b<->b_before_a; fmab unchanged)
   so each symmetric pair appears in both orientations; all lift/CI math
   in s50 then runs once per orientation.
 
   Params:
     @results_database_schema   -- schema holding the cumulative + _all tables
     @window_days               -- +/- day window for co-occurrence
     @cab_min_concept_obs       -- min per-concept event count to keep a pair
     @cab_min_conditional_prob  -- min conditional probability (union gate)
     @create_index_ddl          -- whether to emit create index statements
     @drop_cum_tables           -- whether to drop the per-batch cum tables once
                                   the _all tables are built. They are working
                                   tables and nothing downstream reads them, but
                                   dropping is irreversible: rebuilding means
                                   rerunning every batch. Leave off unless space
                                   is the binding constraint.
     @max_batch_number          -- roll up only batches 1 through this. Normally
                                   the number of batches that actually completed.
                                   A run stopped part way leaves a PARTIAL batch
                                   in the cum tables, and including it would mix
                                   partial pair counts with complete marginals
                                   and person-days for the same persons, so every
                                   ratio involving that batch would be wrong in a
                                   way nothing downstream could detect.
*/

{DEFAULT @create_index_ddl = true}


-- =========================
-- finalize (PIT)
-- =========================

drop table if exists @results_database_schema.cab_s10_person_all;

select
  sum(persons_in_batch) as total_persons,
  sum(person_days_in_batch) as total_person_days,
  sum(person_days_clear_batch) as total_person_days_clear,
  sum(util_sum_batch) as total_util_sum,
  sum(util_sq_batch) as total_util_sq,
  sum(visits_in_batch) as total_visits
into @results_database_schema.cab_s10_person_all
from @results_database_schema.cab_s10_person_cum
where batch_number <= @max_batch_number
;

drop table if exists @results_database_schema.cab_s20_marginal_all;

select
  concept_id,
  src,
  anchor_code,
  interval_code,
  sum(n_obs_batch) as obs_act,
  sum(n_persons_batch) as pers_act,
  sum(n_obs_fm_batch) as obs_fm_act,
  sum(n_persons_fm_batch) as pers_fm_act,
  max(max_per_person) as max_per_person,
  sum(n_obs_sq_batch) as obs_sq_act,
  sum(n_obs_clear_batch) as obs_clear_act,
  sum(n_util_sum_batch) as util_sum_act,
  sum(n_persons_fm_incident_batch) as pers_fm_incident_act,
  sum(person_days_at_risk) as person_days_at_risk
into @results_database_schema.cab_s20_marginal_all
from @results_database_schema.cab_s20_marginal_cum
where batch_number <= @max_batch_number
group by concept_id, src, anchor_code, interval_code
;

{@create_index_ddl} ? {
  create index ix_cab20_all on @results_database_schema.cab_s20_marginal_all (concept_id, src, anchor_code, interval_code);
}

-- ============================================================
-- cab_s30_all: sum the per-batch counts. The key is unchanged --
-- pair_type, anchor_code, interval_code, concept_a, concept_b -- so this is a
-- straight rollup with no reshaping.
-- fm_intake_days_* take the MINIMUM rather than a sum: they are a distance
-- from enrollment to a first mention, and the earliest is the meaningful one.
-- ============================================================
drop table if exists @results_database_schema.meas_obs_profile_s35_all;

select
  a.src,
  a.meas_obs_concept_id,
  a.has_value_concept,
  a.has_value_number,
  a.has_value_string,
  a.has_unit,
  a.has_qualifier,
  a.has_operator,
  a.has_range_low,
  a.has_range_high,
  sum(a.n_records) as n_records
into @results_database_schema.meas_obs_profile_s35_all
from @results_database_schema.meas_obs_profile_s35_cum a
group by
  a.src,
  a.meas_obs_concept_id,
  a.has_value_concept,
  a.has_value_number,
  a.has_value_string,
  a.has_unit,
  a.has_qualifier,
  a.has_operator,
  a.has_range_low,
  a.has_range_high
;

{@create_index_ddl} ? {
  create index ix_meas_obs_profile_s35_all on @results_database_schema.meas_obs_profile_s35_all (src, meas_obs_concept_id);
}


-- meas_obs_attribute_s36_all
-- Roll up the per-batch attribute detail across all batches. Descriptive
-- only; independent of the cab_s40/s50 statistics pipeline.
drop table if exists @results_database_schema.meas_obs_attribute_s36_all;

select
  a.src,
  a.meas_obs_concept_id,
  a.attribute,
  a.attribute_id,
  sum(a.n_records) as n_records
into @results_database_schema.meas_obs_attribute_s36_all
from @results_database_schema.meas_obs_attribute_s36_cum a
group by
  a.src,
  a.meas_obs_concept_id,
  a.attribute,
  a.attribute_id
;

{@create_index_ddl} ? {
  create index ix_meas_obs_attribute_s36_all on @results_database_schema.meas_obs_attribute_s36_all (src, meas_obs_concept_id, attribute, attribute_id);
}


-- ============================================================
drop table if exists @results_database_schema.cab_s30_all;

select
  pair_type,
  anchor_code,
  interval_code,
  concept_a,
  concept_b,
  sum(obs) as obs,
  sum(obs_fma) as obs_fma,
  sum(obs_fmb) as obs_fmb,
  sum(obs_fmab) as obs_fmab,
  sum(obs_fmab_inc) as obs_fmab_inc,
  sum(obs_clear) as obs_clear,
  sum(obs_same_visit) as obs_same_visit,
  sum(obs_sq) as obs_sq,
  sum(pers) as pers,
  sum(pers_fma) as pers_fma,
  sum(pers_fmb) as pers_fmb,
  sum(pers_fmab) as pers_fmab,
  sum(pers_fmab_inc) as pers_fmab_inc,
  sum(pers_same_visit) as pers_same_visit,
  sum(lag_sum) as lag_sum,
  sum(lag_abs_sum) as lag_abs_sum,
  sum(lag_sq) as lag_sq,
  sum(util_sum) as util_sum,
  sum(util_n) as util_n,
  min(fm_intake_days_a) as fm_intake_days_a,
  min(fm_intake_days_b) as fm_intake_days_b
into @results_database_schema.cab_s30_all
from @results_database_schema.cab_s30_cum
where batch_number <= @max_batch_number
group by
  pair_type,
  anchor_code,
  interval_code,
  concept_a,
  concept_b
;

{@create_index_ddl} ? {
  create index ix_cab3_all on @results_database_schema.cab_s30_all (pair_type, anchor_code, concept_a, concept_b);
  update statistics @results_database_schema.cab_s30_all;
}



-- ============================================================
-- OPTIONAL: drop the cum tables no longer needed  (part 1 of 2)
--
-- Emitted only when @drop_cum_tables is true. These five have been rolled into
-- their _all counterparts and nothing below reads them again.
--
-- cab_s30_cum is the reason this block is HERE rather than at the end. On dense
-- data it is by far the largest table in the schema, and the next thing built
-- is cab_s40_all, the second largest -- roughly twice cab_s30_all in bytes,
-- since it carries both concepts' marginals joined onto every row. Freeing
-- cab_s30_cum first is the difference between finalize completing and running
-- out of space part way through cab_s40_all.
--
-- IRREVERSIBLE. Rebuilding these means rerunning every batch.
-- ============================================================
{@drop_cum_tables} ? {
  drop table if exists @results_database_schema.cab_s30_cum;
  drop table if exists @results_database_schema.cab_s20_marginal_cum;
  drop table if exists @results_database_schema.cab_s10_person_cum;
  drop table if exists @results_database_schema.meas_obs_attribute_s36_cum;
  drop table if exists @results_database_schema.meas_obs_profile_s35_cum;
}


-- ============================================================
-- cab_s40_all  -  counts joined to their marginals, with expected values
--
-- WIN_W is the number of day-offsets each interval admits, and is the exposure
-- width in every event expected below:
--   interval 1  delta 0                        1 day
--   interval 2  delta +1..+W                   @window_days
--   interval 3  delta -W..-1                   @window_days
--   interval 4  delta +182..+182+W             @window_days + 1
--   interval 5  delta +365..+365+W             @window_days + 1
--   interval 6  delta +W+1..+2W                @window_days
-- Intervals 1 + 2 pool to @window_days + 1, which matches intervals 4 and 5
-- exactly, so the near/reference ratio needs no width correction.
--
-- MARGINALS ARE JOINED ON anchor_code as well as concept and src. Anchor 2
-- uses the trigger-restricted procedure marginal and anchor 4 the chronic
-- at-risk rows, so each numerator sits over a denominator counted the same way.
--
-- The join also pins interval_code, because the marginal table carries one row
-- per interval for anchor 4. Anchors 1 and 2 match interval_code 0; anchor 4
-- matches its own interval. Without that predicate every anchor-1 row would
-- multiply against the ten anchor-4 interval rows -- silently, with no error,
-- just inflated counts.
--
-- The PERSON expected is width-scaled by win_w / (2*@window_days + 1). Under
-- independence the chance a person has at least one B in a window of width w
-- is approximately linear in w for anything but very common concepts, so a
-- 1-day interval and a 35-day interval cannot share one expected. This is an
-- approximation and is documented as such; the event expected is exact.
-- ============================================================
drop table if exists @results_database_schema.cab_s40_all;

with base as (
select
  total_persons,
  total_person_days,
  total_person_days_clear,
  total_util_sum,
  total_util_sq
from @results_database_schema.cab_s10_person_all
), joined as (
select
  s3.pair_type,
  s3.anchor_code,
  s3.interval_code,
  cast(s3.pair_type / 100 as int) as src_a,
  s3.pair_type % 100              as src_b,
  s3.concept_a,
  s3.concept_b,
  case
    when s3.interval_code in (1, 10) then 1.0
    else @window_days * 1.0
  end as win_w,
  s3.obs,
  s3.obs_fma,
  s3.obs_fmb,
  s3.obs_fmab,
  s3.obs_fmab_inc,
  s3.obs_clear,
  s3.obs_same_visit,
  s3.obs_sq,
  s3.pers,
  s3.pers_fma,
  s3.pers_fmb,
  s3.pers_fmab,
  s3.pers_fmab_inc,
  s3.pers_same_visit,
  s3.lag_sum,
  s3.lag_abs_sum,
  s3.lag_sq,
  s3.util_sum,
  s3.util_n,
  s3.fm_intake_days_a,
  s3.fm_intake_days_b,
  a.obs_act as obs_a_act,
  a.pers_act as pers_a,
  a.obs_fm_act as obs_a_fm_act,
  a.pers_fm_act as pers_a_fm,
  a.max_per_person as max_a,
  a.obs_clear_act as obs_a_clear,
  a.pers_fm_incident_act as pers_a_fm_inc,
  a.util_sum_act as util_sum_a,
  a.person_days_at_risk,
  b.obs_act as obs_b_act,
  b.pers_act as pers_b,
  b.obs_fm_act as obs_b_fm_act,
  b.pers_fm_act as pers_b_fm,
  b.max_per_person as max_b,
  b.obs_clear_act as obs_b_clear,
  b.pers_fm_incident_act as pers_b_fm_inc,
  b.util_sum_act as util_sum_b,
  base.total_persons,
  base.total_person_days,
  base.total_person_days_clear,
  base.total_util_sum,
  base.total_util_sq
from @results_database_schema.cab_s30_all s3
  inner join @results_database_schema.cab_s20_marginal_all a on s3.concept_a = a.concept_id and cast(s3.pair_type / 100 as int) = a.src and s3.anchor_code = a.anchor_code and a.interval_code = case when s3.anchor_code = 4 then s3.interval_code else 0 end
  inner join @results_database_schema.cab_s20_marginal_all b on s3.concept_b = b.concept_id and (s3.pair_type % 100) = b.src and b.anchor_code = 1 and b.interval_code = 0
  cross join base
where
  a.obs_act >= @cab_min_concept_obs
  and
  b.obs_act >= @cab_min_concept_obs
)
select
  a.*,
  case
    when a.anchor_code = 4
    then cast(a.obs_b_act * 1.0 * a.person_days_at_risk * 1.0 / nullif(a.total_person_days * 1.0, 0.0) as float)
    else cast(a.obs_a_act * 1.0 * a.obs_b_act * 1.0 * a.win_w / nullif(a.total_person_days * 1.0, 0.0) as float)
  end as obs_exp,
  case
    when a.anchor_code = 4
    then cast(a.obs_b_fm_act * 1.0 * a.person_days_at_risk * 1.0 / nullif(a.total_person_days * 1.0, 0.0) as float)
    else cast(a.obs_a_act * 1.0 * a.obs_b_fm_act * 1.0 * a.win_w / nullif(a.total_person_days * 1.0, 0.0) as float)
  end as obs_exp_fmb,
  case
    when a.anchor_code = 4
    then cast(a.obs_b_act * 1.0 * a.person_days_at_risk * 1.0 / nullif(a.total_person_days * 1.0, 0.0) as float)
    else cast(a.obs_a_fm_act * 1.0 * a.obs_b_act * 1.0 * a.win_w / nullif(a.total_person_days * 1.0, 0.0) as float)
  end as obs_exp_fma,
  case
    when a.anchor_code = 4
    then cast(a.obs_b_fm_act * 1.0 * a.person_days_at_risk * 1.0 / nullif(a.total_person_days * 1.0, 0.0) as float)
    else cast(a.obs_a_fm_act * 1.0 * a.obs_b_fm_act * 1.0 * a.win_w / nullif(a.total_person_days * 1.0, 0.0) as float)
  end as obs_exp_fmab,
  cast(a.obs_a_clear * 1.0 * a.obs_b_clear * 1.0 * a.win_w / nullif(a.total_person_days_clear * 1.0, 0.0) as float) as obs_exp_clear,
  cast(a.pers_a * 1.0 * a.pers_b * 1.0 * a.win_w / nullif(a.total_persons * 1.0 * (2.0 * @window_days + 1.0), 0.0) as float) as pers_exp,
  cast(a.pers_a * 1.0 * a.pers_b_fm * 1.0 * a.win_w / nullif(a.total_persons * 1.0 * (2.0 * @window_days + 1.0), 0.0) as float) as pers_exp_fmb,
  cast(a.pers_a_fm * 1.0 * a.pers_b * 1.0 * a.win_w / nullif(a.total_persons * 1.0 * (2.0 * @window_days + 1.0), 0.0) as float) as pers_exp_fma,
  cast(a.pers_a_fm * 1.0 * a.pers_b_fm * 1.0 * a.win_w / nullif(a.total_persons * 1.0 * (2.0 * @window_days + 1.0), 0.0) as float) as pers_exp_fmab,
  cast(a.pers_a_fm_inc * 1.0 * a.pers_b_fm_inc * 1.0 * a.win_w / nullif(a.total_persons * 1.0 * (2.0 * @window_days + 1.0), 0.0) as float) as pers_exp_fmab_inc
into @results_database_schema.cab_s40_all
from joined a
;


-- MIRROR for same-domain pair types, ANCHOR 1 ONLY. Swapping concept_a and
-- concept_b also swaps the DIRECTION, so interval 2 (B after A) and interval 3
-- (B before A) exchange, and lag_sum changes sign.
--
-- Anchors 2 and 3 are excluded because their same-domain blocks use a
-- concept_a <> concept_b guard and therefore already emit BOTH orientations
-- natively -- mirroring them would double every count. They emit both because
-- their forward-only intervals (4, 5 and 6) are genuinely different quantities
-- in each direction and cannot be recovered by a swap: mirroring interval 4
-- would relabel "B at +182 from A" as "A at +182 from B", which is false.
-- Anchor 1 uses concept_a < concept_b and does need the swap.
--
-- Cross-domain pair types are never mirrored: they exist in one orientation by
-- convention, and interval 2 versus 3 carries the direction within it.
insert into @results_database_schema.cab_s40_all
select
  a.pair_type,
  a.anchor_code,
  case a.interval_code when 2 then 3 when 3 then 2 else a.interval_code end as interval_code,
  a.src_b as src_a,
  a.src_a as src_b,
  a.concept_b as concept_a,
  a.concept_a as concept_b,
  a.win_w,
  a.obs,
  a.obs_fmb as obs_fma,
  a.obs_fma as obs_fmb,
  a.obs_fmab,
  a.obs_fmab_inc,
  a.obs_clear,
  a.obs_same_visit,
  a.obs_sq,
  a.pers,
  a.pers_fmb as pers_fma,
  a.pers_fma as pers_fmb,
  a.pers_fmab,
  a.pers_fmab_inc,
  a.pers_same_visit,
  -a.lag_sum as lag_sum,
  a.lag_abs_sum,
  a.lag_sq,
  a.util_sum,
  a.util_n,
  a.fm_intake_days_b as fm_intake_days_a,
  a.fm_intake_days_a as fm_intake_days_b,
  a.obs_b_act as obs_a_act,
  a.pers_b as pers_a,
  a.obs_b_fm_act as obs_a_fm_act,
  a.pers_b_fm as pers_a_fm,
  a.max_b as max_a,
  a.obs_b_clear as obs_a_clear,
  a.pers_b_fm_inc as pers_a_fm_inc,
  a.util_sum_b as util_sum_a,
  a.person_days_at_risk,
  a.obs_a_act as obs_b_act,
  a.pers_a as pers_b,
  a.obs_a_fm_act as obs_b_fm_act,
  a.pers_a_fm as pers_b_fm,
  a.max_a as max_b,
  a.obs_a_clear as obs_b_clear,
  a.pers_a_fm_inc as pers_b_fm_inc,
  a.util_sum_a as util_sum_b,
  a.total_persons,
  a.total_person_days,
  a.total_person_days_clear,
  a.total_util_sum,
  a.total_util_sq,
  a.obs_exp,
  a.obs_exp_fma as obs_exp_fmb,
  a.obs_exp_fmb as obs_exp_fma,
  a.obs_exp_fmab,
  a.obs_exp_clear,
  a.pers_exp,
  a.pers_exp_fma as pers_exp_fmb,
  a.pers_exp_fmb as pers_exp_fma,
  a.pers_exp_fmab,
  a.pers_exp_fmab_inc
from @results_database_schema.cab_s40_all a
where a.pair_type in (1010, 2020, 3030, 4040)
  and a.anchor_code = 1
;

{@create_index_ddl} ? {
  create index ix_cab4_all on @results_database_schema.cab_s40_all (pair_type, anchor_code, concept_a, concept_b);
  update statistics @results_database_schema.cab_s40_all;
}


-- ============================================================
-- cab_vocab_all_output  -  names + domain/vocab for EVERY distinct concept_id in
-- cab_s20_marginal_all (all srcs). SqlRender-parameterized; runs in finalize
-- after cab_s20_marginal_all. Single output table; the naming authority (the
-- union of result-concept sources) is an inline CTE, not a persisted table.
--
--   packed meas/obs keys (src 51 obs, 61 meas): key = test*1e9 + result,
--     named as  test_name: result_name  (integer band 60000000..60099999 is
--     synthetic and named by rule; every other part resolves in the union CTE).
--   all other srcs: concept_id is a plain concept, named directly from the union.
-- ============================================================
drop table if exists @results_database_schema.cab_vocab_all_output;

with names as ( -- naming authority: every nameable concept that can appear in s20
select concept_id, concept_name, concept_domain, concept_vocab from (
  select concept_id, concept_name, domain_id as concept_domain, vocabulary_id as concept_vocab
    from @omop_reference_schema.concept where domain_id in ('Observation','Condition') and vocabulary_id = 'SNOMED'
  union
  select concept_id, concept_name, domain_id, vocabulary_id
    from @omop_reference_schema.concept where domain_id = 'Metadata'
  union
  select concept_id, concept_name, domain_id, vocabulary_id
    from @omop_reference_schema.concept where domain_id = 'Meas Value'
  union
  -- Visit, for the src 01 pair types. Those pair a record's visit_concept_id
  -- against the record's own concept, so the A side is a care setting rather
  -- than a clinical concept and would otherwise resolve to no name at all.
  select concept_id, concept_name, domain_id, vocabulary_id
    from @omop_reference_schema.concept where domain_id = 'Visit'
  union
  -- The no-linked-visit sentinel. Records whose visit could not be resolved --
  -- no visit_occurrence_id on the source row, or a visit falling outside the
  -- observation period -- are counted under -99 rather than dropped, so the
  -- share of records with no usable visit stays visible. -99 is not an OMOP
  -- concept and has no row in the vocabulary, so it is named here or not at
  -- all. Note this is NOT concept 0: 0 means the source value could not be
  -- mapped, which is a different failure from having no visit to map.
  select cast(-99 as int), cast('No linked visit' as varchar(255)), cast('Visit' as varchar(20)), cast('CAB' as varchar(20))
  union
  select concept_id, concept_name, domain_id, vocabulary_id
    from @omop_reference_schema.concept where concept_id in (4267416, 4328749, 4069590, 46237210, 36309857)
  union
  select concept_id, concept_name, concept_domain, concept_vocab from @project_reference_schema.cab_vocab_all_procedure
  union
  select concept_id, concept_name, concept_domain, concept_vocab from @project_reference_schema.cab_vocab_all_device
  union
  select concept_id, concept_name, concept_domain, concept_vocab from @project_reference_schema.cab_vocab_all_drug_ing_form
  union
  select concept_id, concept_name, concept_domain, concept_vocab from @project_reference_schema.cab_vocab_all_meas_obs_test
) u
), keys as ( -- every distinct (concept_id, src) in this run's marginal table
select distinct concept_id, src from @results_database_schema.cab_s20_marginal_all
), s0 as ( -- split into test side and result side; packed only for src 51/61
select
  a.concept_id,
  a.src,
  case when a.src in (51,61) then a.concept_id / 1000000000 else a.concept_id end as test_concept_id,
  case when a.src in (51,61) then a.concept_id % 1000000000 else cast(null as bigint) end as result_in
from keys a
), s1 as ( -- classify the result component of a packed key (reserved + integer band by position)
select
  a.concept_id,
  a.src,
  a.test_concept_id,
  a.result_in,
  case
    when a.src not in (51,61) then null
    when a.result_in = 46237210 then 'no_result'
    when a.result_in = 36309857 then 'unusable'
    when a.result_in >= 60000000 and a.result_in <= 60099999 then 'integer'
    when a.result_in = a.test_concept_id then 'assertion'
    else 'value'
  end as result_shape
from s0 a
), s2 as ( -- resolve test-side and result-side name/domain/vocab from the union CTE
select
  a.concept_id,
  a.src,
  a.test_concept_id,
  a.result_in,
  a.result_shape,
  t.concept_name   as test_name,
  t.concept_domain as test_domain,
  t.concept_vocab  as test_vocab,
  case
    when a.src not in (51,61) then null
    when a.result_shape = 'integer' then cast(a.result_in - 60000000 as varchar(20))
    else r.concept_name
  end as result_name
from s1 a
  left outer join names t on t.concept_id = a.test_concept_id
  left outer join names r on r.concept_id = a.result_in and a.src in (51,61) and a.result_shape <> 'integer'
), s3 as ( -- one row per src, before deduplication
select
  distinct
  a.concept_id,
  a.src,
  case when a.src in (51,61) then concat(a.test_name, ': ', lower(coalesce(a.result_name, '?')))
       else a.test_name end as concept_name,
  a.test_domain as concept_domain,
  a.test_vocab  as concept_vocab,
  case when a.src in (50,51,60,61) then a.test_concept_id else null end as test_concept_id,
  case when a.src in (51,61) then a.result_in else null end as result_concept_id,
  case when a.src in (50,51,60,61) then a.test_name else null end as test_concept_name,
  case when a.src in (51,61) then a.result_name else null end as result_concept_name,
  a.result_shape
from s2 a
), s4 as ( -- ONE ROW PER concept_id, which is what the downstream joins assume.
-- The distinct above is not sufficient on its own: the test and result columns
-- are derived from src, so a concept appearing under two srcs -- a procedure
-- that is also an observation test, say -- yields two rows that differ in those
-- columns and both survive. cab_s50_all left joins this table twice, once for
-- each concept in the pair, so every duplicate here multiplies s50 rows for
-- every pair the concept appears in. Preference goes to the row carrying test
-- detail, since it is the more informative of the two and the name is the same
-- either way.
select
  a.concept_id,
  a.concept_name,
  a.concept_domain,
  a.concept_vocab,
  a.test_concept_id,
  a.result_concept_id,
  a.test_concept_name,
  a.result_concept_name,
  a.result_shape,
  row_number() over (
    partition by a.concept_id
    order by case when a.test_concept_id is null then 1 else 0 end, a.src
  ) as rn
from s3 a
)
select
  a.concept_id,
  a.concept_name,
  a.concept_domain,
  a.concept_vocab,
  a.test_concept_id,
  a.result_concept_id,
  a.test_concept_name,
  a.result_concept_name,
  a.result_shape
into @results_database_schema.cab_vocab_all_output
from s4 a
where a.rn = 1
;
{@create_index_ddl} ? {
  create index ix_cab_vocab_all_output on @results_database_schema.cab_vocab_all_output (concept_id);
  update statistics @results_database_schema.cab_vocab_all_output;
}



-- ============================================================
-- DESIGN PROFILING ROLLUPS (cab_s37_lag_all, cab_s38_profile_all)
-- Descriptive only, from the profiling batches. cab_s37_lag_all is the one to
-- read first: plot n_events against lag_bucket and find where the curve
-- flattens. That point is the honest near-window width, and it says whether
-- the 182 and 365 day reference offsets sit in genuinely flat territory or are
-- still picking up real signal.
-- ============================================================
drop table if exists @results_database_schema.cab_s37_lag_all;

select
  pair_type,
  lag_bucket,
  lag_bucket * 10 as lag_days_approx,
  sum(n_events) as n_events,
  sum(n_pairs) as n_pairs
into @results_database_schema.cab_s37_lag_all
from @results_database_schema.cab_s37_lag_cum
where batch_number <= @max_batch_number
group by pair_type, lag_bucket
;

{@create_index_ddl} ? {
  update statistics @results_database_schema.cab_s37_lag_all;
}

drop table if exists @results_database_schema.cab_s38_profile_all;

select
  metric,
  src,
  bucket,
  sum(n_records) as n_records,
  sum(n_persons) as n_persons
into @results_database_schema.cab_s38_profile_all
from @results_database_schema.cab_s38_profile_cum
where batch_number <= @max_batch_number
group by metric, src, bucket
;

{@create_index_ddl} ? {
  update statistics @results_database_schema.cab_s38_profile_all;
}


-- ============================================================
-- cab_s39_pattern_all  -  concept recording pattern, rolled up
-- ============================================================
drop table if exists @results_database_schema.cab_s39_pattern_all;

select
  metric,
  src,
  concept_id,
  bucket,
  sum(n_obs) as n_obs,
  sum(n_persons) as n_persons
into @results_database_schema.cab_s39_pattern_all
from @results_database_schema.cab_s39_pattern_cum
where batch_number <= @max_batch_number
group by
  metric,
  src,
  concept_id,
  bucket
;

{@create_index_ddl} ? {
  create index ix_cab39_all on @results_database_schema.cab_s39_pattern_all (concept_id, src, metric);
  update statistics @results_database_schema.cab_s39_pattern_all;
}


-- ============================================================
-- cab_s54_grain_guide  -  one row per concept: which grain to read
--
-- Reduces the gap histogram to the quantities that carry the signal and
-- applies the pattern signatures. median_gap_bucket is read off the cumulative
-- distribution -- the first bucket at which the running share reaches half.
--
--   pattern    mentions/person  median gap   gap shape
--   punctate   under 1.2        none         no gaps exist
--   clustered  1.2 to 8         14 or less   one mode, tight
--   recurrent  1.2 to 8         90 or more   one mode, long
--   chronic    8 or more        20 to 120    one mode, regular
--   episodic   1.2 to 8         meaningless  BIMODAL, mass at both ends
--
-- THE CUT POINTS ARE ARGUMENTS, NOT FITS. They should be revisited against the
-- observed histograms in cab_s39_pattern_all; real gap distributions may not
-- fall on these boundaries, and the bimodality test in particular is a guess at
-- how much mass must sit at each end before two modes is the right reading.
-- The histogram is stored precisely so this can be redone without a re-run.
--
-- grain says which mention grain to read for that concept. episodic gets
-- 'both' because NEITHER is right: all-mention counts each episode several
-- times, first-mention keeps only the first episode.
-- ============================================================
drop table if exists @results_database_schema.cab_s54_grain_guide;

with s1 as ( -- gap mass by band
select
  a.concept_id,
  a.src,
  sum(a.n_obs) as n_gaps,
  sum(case when a.bucket <= 14 then a.n_obs else 0 end) as gaps_tight,
  sum(case when a.bucket in (30, 60, 90) then a.n_obs else 0 end) as gaps_mid,
  sum(case when a.bucket >= 180 then a.n_obs else 0 end) as gaps_long
from @results_database_schema.cab_s39_pattern_all a
where a.metric = 'gap'
group by
  a.concept_id,
  a.src
), s2 as ( -- running share of the gap distribution
select
  a.concept_id,
  a.src,
  a.bucket,
  sum(a.n_obs) over (partition by a.concept_id, a.src order by a.bucket rows unbounded preceding) * 1.0
    / sum(a.n_obs) over (partition by a.concept_id, a.src) as cum_share
from @results_database_schema.cab_s39_pattern_all a
where a.metric = 'gap'
), s3 as ( -- the first bucket at or past the halfway point
select
  a.concept_id,
  a.src,
  min(a.bucket) as median_gap_bucket
from s2 a
where a.cum_share >= 0.5
group by
  a.concept_id,
  a.src
), s4 as ( -- the same for span
select
  a.concept_id,
  a.src,
  a.bucket,
  sum(a.n_obs) over (partition by a.concept_id, a.src order by a.bucket rows unbounded preceding) * 1.0
    / sum(a.n_obs) over (partition by a.concept_id, a.src) as cum_share
from @results_database_schema.cab_s39_pattern_all a
where a.metric = 'span'
), s5 as (
select
  a.concept_id,
  a.src,
  min(a.bucket) as median_span_bucket
from s4 a
where a.cum_share >= 0.5
group by
  a.concept_id,
  a.src
), s6 as ( -- marginal scale, unrestricted anchors
select
  a.concept_id,
  a.src,
  a.obs_act,
  a.pers_act,
  case when a.pers_act > 0 then a.obs_act * 1.0 / a.pers_act else null end as mentions_per_person
from @results_database_schema.cab_s20_marginal_all a
where a.anchor_code = 1
), s7 as ( -- everything on one row
select
  a.concept_id,
  a.src,
  a.obs_act,
  a.pers_act,
  a.mentions_per_person,
  coalesce(b.n_gaps, 0) as n_gaps,
  case when b.n_gaps > 0 then b.gaps_tight * 1.0 / b.n_gaps else null end as frac_tight,
  case when b.n_gaps > 0 then b.gaps_mid * 1.0 / b.n_gaps else null end as frac_mid,
  case when b.n_gaps > 0 then b.gaps_long * 1.0 / b.n_gaps else null end as frac_long,
  c.median_gap_bucket,
  d.median_span_bucket
from s6 a
  left outer join s1 b on a.concept_id = b.concept_id and a.src = b.src
  left outer join s3 c on a.concept_id = c.concept_id and a.src = c.src
  left outer join s5 d on a.concept_id = d.concept_id and a.src = d.src
), s8 as ( -- the pattern label
select
  a.concept_id,
  a.src,
  a.obs_act,
  a.pers_act,
  a.mentions_per_person,
  a.n_gaps,
  a.frac_tight,
  a.frac_mid,
  a.frac_long,
  a.median_gap_bucket,
  a.median_span_bucket,
  case
    when a.n_gaps is null or a.n_gaps = 0 then 'unknown'
    when a.mentions_per_person < 1.05 then 'punctate'
    when a.frac_tight >= 0.25 and a.frac_long >= 0.25 then 'episodic'
    when a.mentions_per_person >= 8 and a.median_gap_bucket <= 90 then 'chronic'
    when a.median_gap_bucket <= 14 then 'clustered'
    when a.median_gap_bucket >= 90 then 'recurrent'
    else 'mixed'
  end as pattern
from s7 a
)
select
  a.concept_id,
  a.src,
  a.obs_act,
  a.pers_act,
  cast(round(a.mentions_per_person, 3) as float) as mentions_per_person,
  a.n_gaps,
  a.median_gap_bucket,
  a.median_span_bucket,
  cast(round(a.frac_tight, 4) as float) as frac_gaps_tight,
  cast(round(a.frac_mid, 4) as float) as frac_gaps_mid,
  cast(round(a.frac_long, 4) as float) as frac_gaps_long,
  a.pattern,
  case a.pattern
    when 'unknown' then 'both'
    when 'punctate' then 'all'
    when 'clustered' then 'first'
    when 'chronic' then 'first'
    when 'recurrent' then 'all'
    when 'episodic' then 'both'
    else 'both'
  end as grain,
  case a.pattern
    when 'unknown' then 'no gap histogram for this source table, read both'
    when 'punctate' then 'one record per person, nothing to collapse'
    when 'clustered' then 'several records, one event -- all-mention counts it several times'
    when 'chronic' then 'redocumented state -- only the onset carries information'
    when 'recurrent' then 'each record is a separate event -- collapsing discards real signal'
    when 'episodic' then 'several events each with several records -- NEITHER grain is right, read both'
    else 'pattern not clear cut, read both'
  end as rationale
into @results_database_schema.cab_s54_grain_guide
from s8 a
;

{@create_index_ddl} ? {
  create index ix_cab54_guide on @results_database_schema.cab_s54_grain_guide (concept_id, src);
  update statistics @results_database_schema.cab_s54_grain_guide;
}


-- ============================================================
-- STRATIFIED ROLLUPS AND THE UTILIZATION-ADJUSTED EXPECTED
--
-- cab_s33_strat_all is kept (not dropped) so the decile detail can be
-- exported and re-pooled later -- deciles sum into quintiles or any other
-- grouping without a re-run. cab_s33_mh_all collapses to ONE ROW PER PAIR,
-- which is what cab_s50_all joins, so nothing stratified reaches the wide
-- tables or the standard export.
--
-- The expected is formed INSIDE each decile and then summed. The order
-- matters: summing the marginals first and computing one expected returns
-- the unadjusted, confounded number exactly.
-- ============================================================
  drop table if exists @results_database_schema.cab_s13_strat_all;

  select
    util_decile,
    sum(persons_in_decile) as persons_in_decile,
    sum(person_days_in_decile) as person_days_in_decile
  into @results_database_schema.cab_s13_strat_all
  from @results_database_schema.cab_s13_strat_cum
  where batch_number <= @max_batch_number
  group by util_decile
  ;

  drop table if exists @results_database_schema.cab_s23_strat_all;

  select
    concept_id,
    src,
    util_decile,
    sum(n_obs_batch) as obs_act,
    sum(n_persons_batch) as pers_act,
    sum(n_obs_fm_batch) as obs_fm_act,
    sum(n_persons_fm_batch) as pers_fm_act
  into @results_database_schema.cab_s23_strat_all
  from @results_database_schema.cab_s23_strat_cum
  where batch_number <= @max_batch_number
  group by concept_id, src, util_decile
  ;

  {@create_index_ddl} ? {
    create index ix_cab23_strat on @results_database_schema.cab_s23_strat_all (concept_id, src, util_decile);
    update statistics @results_database_schema.cab_s23_strat_all;
  }

  drop table if exists @results_database_schema.cab_s33_strat_all;

  select
    pair_type,
    concept_a,
    concept_b,
    util_decile,
    sum(obs_ab_act) as obs_ab_act,
    sum(obs_ab_act_fmab) as obs_ab_act_fmab,
    sum(pers_ab) as pers_ab
  into @results_database_schema.cab_s33_strat_all
  from @results_database_schema.cab_s33_strat_cum
  where batch_number <= @max_batch_number
  group by pair_type, concept_a, concept_b, util_decile
  ;

  {@create_index_ddl} ? {
    create index ix_cab33_strat on @results_database_schema.cab_s33_strat_all (pair_type, concept_a, concept_b);
    update statistics @results_database_schema.cab_s33_strat_all;
  }

-- ============================================================
-- OPTIONAL: drop the cum tables no longer needed  (part 2 of 2)
--
-- The remaining six, dropped once the last rollup reading them has run.
-- Everything built after this point -- cab_s33_mh_all, cab_s50_all,
-- cab_s55_pair_all, cab_timing_all -- reads only _all tables and
-- cab_process_log, which is never dropped.
-- ============================================================
{@drop_cum_tables} ? {
  drop table if exists @results_database_schema.cab_s33_strat_cum;
  drop table if exists @results_database_schema.cab_s23_strat_cum;
  drop table if exists @results_database_schema.cab_s13_strat_cum;
  drop table if exists @results_database_schema.cab_s39_pattern_cum;
  drop table if exists @results_database_schema.cab_s38_profile_cum;
  drop table if exists @results_database_schema.cab_s37_lag_cum;
}






  -- cab_s33_mh_all: E_k per decile, then collapsed to one row per pair.
  -- Emitted with both orientations for the same-domain pair types, matching
  -- the cab_s40 mirror.
  drop table if exists @results_database_schema.cab_s33_mh_all;

  with s1 as ( -- mirror same-domain pairs so both orientations join to s50
  select pair_type, concept_a, concept_b, util_decile, obs_ab_act, obs_ab_act_fmab, pers_ab
  from @results_database_schema.cab_s33_strat_all
  union all
  select pair_type, concept_b as concept_a, concept_a as concept_b, util_decile, obs_ab_act, obs_ab_act_fmab, pers_ab
  from @results_database_schema.cab_s33_strat_all
  where pair_type in (1010, 2020, 3030, 4040)
  ), s2 as ( -- expected within each decile, from that decile's own rates
  select
    a.pair_type,
    a.concept_a,
    a.concept_b,
    a.util_decile,
    a.obs_ab_act,
    a.obs_ab_act_fmab,
    a.pers_ab,
    (m1.obs_act * 1.0 * m2.obs_act * 1.0 * (2.0 * @window_days + 1.0) / nullif(base.person_days_in_decile * 1.0, 0.0)) as exp_k,
    (m1.pers_fm_act * 1.0 * m2.pers_fm_act * 1.0 / nullif(base.persons_in_decile * 1.0, 0.0)) as exp_k_fmab
  from s1 a
    inner join @results_database_schema.cab_s23_strat_all m1 on a.concept_a = m1.concept_id and cast(a.pair_type / 100 as int) = m1.src and a.util_decile = m1.util_decile
    inner join @results_database_schema.cab_s23_strat_all m2 on a.concept_b = m2.concept_id and (a.pair_type % 100) = m2.src and a.util_decile = m2.util_decile
    inner join @results_database_schema.cab_s13_strat_all base on a.util_decile = base.util_decile
  )
  select
    a.pair_type,
    a.concept_a,
    a.concept_b,
    cast(sum(a.obs_ab_act) as bigint) as obs_ab_act_mh,
    cast(sum(a.exp_k) as float) as obs_ab_exp_mh,
    cast(sum(a.obs_ab_act_fmab) as bigint) as obs_ab_act_fmab_mh,
    cast(sum(a.exp_k_fmab) as float) as obs_ab_exp_fmab_mh,
    cast(count(*) as int) as n_deciles,
    -- utilization-weighted mean decile of this pair's co-occurrences: where in
    -- the utilization distribution the pair's signal actually sits
    cast(round(sum(a.util_decile * 1.0 * a.obs_ab_act) / nullif(sum(a.obs_ab_act) * 1.0, 0.0), 2) as float) as mean_decile,
    cast(sum(case when a.util_decile = 10 then a.obs_ab_act else 0 end) as bigint) as obs_ab_act_d10,
    cast(sum(case when a.util_decile = 10 then a.exp_k else 0.0 end) as float) as obs_ab_exp_d10
  into @results_database_schema.cab_s33_mh_all
  from s2 a
  group by a.pair_type, a.concept_a, a.concept_b
  ;

  {@create_index_ddl} ? {
    create index ix_cab33_mh on @results_database_schema.cab_s33_mh_all (pair_type, concept_a, concept_b);
    update statistics @results_database_schema.cab_s33_mh_all;
  }



  -- ============================================================
  -- STRATIFIED ROLLUPS AND THE UTILIZATION-ADJUSTED EXPECTED
  --
  -- cab_s33_strat_all is kept (not dropped) so the decile detail can be
  -- exported and re-pooled later -- deciles sum into quintiles or any other
  -- grouping without a re-run. cab_s33_mh_all collapses to ONE ROW PER PAIR,
  -- which is what cab_s50_all joins, so nothing stratified reaches the wide
  -- tables or the standard export.
  --
  -- The expected is formed INSIDE each decile and then summed. The order
  -- matters: summing the marginals first and computing one expected returns
  -- the unadjusted, confounded number exactly.
  -- ============================================================
  -- cab_s50_all  -  every statistic, one row per
  --     pair_type, anchor_code, interval_code, concept_a, concept_b
  --
  -- ONE ROW SHAPE. Each row carries the same statistics for its own interval,
  -- so there is no direction x first-mention cross product of column names to
  -- learn. The same-day lift is interval 1, the forward lift is interval 2, the
  -- backward lift is interval 3, and the reference baselines are intervals 4 and
    --
  -- HOW TO USE IT
  --   Rank on obs_lift at anchor 1. Its failure mode is rarity, not
  --     relationship: a rare pair with a handful of co-occurrences outranks a
  --     common pair with a real one, which is what the support columns are for.
  --   Read obs_lift_fmb when B is persistent, obs_lift_fma when A is,
  --     obs_lift_fmab when both are. mentions_per_person_a and _b say which
  --     applies -- near 1 is a punctate concept, 40 is a maintenance drug -- so
  --     the choice is measured rather than assumed.
    --   lag_sd, dir (interval 2 vs 3), same_visit_frac and util_ratio are SHAPE,
  --     not magnitude. On Synthea, real pairs ran lag_sd 0.3-4 and incidental
  --     ones 10-23, which discriminated better than any lift variant.
  --
  -- A NOTE ON THE PERSON LIFTS. The person expected is width-scaled linearly by
  -- win_w, which is a good approximation for anything but very common concepts
  -- and is exact for none. The event expected is exact. Where they disagree,
  -- trust the event version.
  --
  -- cab_s33_mh_all (utilization-adjusted expected) is deliberately NOT joined
  -- here: it is one row per pair while this table is one row per interval, and
  -- repeating it on every row would imply a precision it does not have. Join it
  -- downstream on pair_type, concept_a, concept_b.
  -- ============================================================
  drop table if exists @results_database_schema.cab_s50_all;

  with s1 as ( -- derived quantities, computed once
  select
    a.*,
    case when a.pers > 0 and a.obs > 0 and (a.obs_sq * 1.0 / a.pers) - power(a.obs * 1.0 / a.pers, 2) > 0
      then 1.0 + ((a.obs_sq * 1.0 / a.pers) - power(a.obs * 1.0 / a.pers, 2)) / (a.obs * 1.0 / a.pers)
      else 1.0 end as deff,
    case when a.util_n > 0 and a.total_persons > 0 and a.total_util_sum > 0
      then (a.util_sum * 1.0 / a.util_n) / (a.total_util_sum * 1.0 / a.total_persons) else null end as util_ratio,
    case when a.pers_a > 0 and a.total_persons > 0 and a.total_util_sum > 0
      then (a.util_sum_a * 1.0 / a.pers_a) / (a.total_util_sum * 1.0 / a.total_persons) else null end as util_ratio_a,
    case when a.pers_b > 0 and a.total_persons > 0 and a.total_util_sum > 0
      then (a.util_sum_b * 1.0 / a.pers_b) / (a.total_util_sum * 1.0 / a.total_persons) else null end as util_ratio_b
  from @results_database_schema.cab_s40_all a
  )
  select
    s1.pair_type,
    s1.anchor_code,
    s1.interval_code,
    case s1.anchor_code when 1 then 'all' when 2 then 'trigger' when 4 then 'chronic onset' end as anchor_t,
    case s1.interval_code
      when 1 then 'same day'
      when 2 then 'B after A'
      when 3 then 'B before A'
      when 6 then 'post trigger'
      when 9 then 'before onset'
      when 10 then 'onset day'
      else concat('onset band ', cast(s1.interval_code - 10 as varchar(4)))
    end as interval_t,
    concat(case s1.src_a
      when 10 then 'condition' when 20 then 'procedure' when 30 then 'device' when 40 then 'drug'
      when 50 then 'obs test' when 60 then 'meas test' when 51 then 'obs result' when 61 then 'meas result'
      when 11 then 'chronic condition'
    end, '|', case s1.src_b
      when 10 then 'condition' when 20 then 'procedure' when 30 then 'device' when 40 then 'drug'
      when 50 then 'obs test' when 60 then 'meas test' when 51 then 'obs result' when 61 then 'meas result'
    end) as pair_type_t,
    s1.concept_a,
    ca.concept_name as concept_name_a,
    s1.concept_b,
    cb.concept_name as concept_name_b,
    cast(s1.win_w as float) as win_w,

    -- ===== counts =====
    s1.obs,
    s1.pers,
    s1.obs_fma,
    s1.obs_fmb,
    s1.obs_fmab,
    s1.obs_fmab_inc,
    s1.pers_fma,
    s1.pers_fmb,
    s1.pers_fmab,
    s1.pers_fmab_inc,
    s1.obs_clear,
    s1.obs_same_visit,
    s1.pers_same_visit,

    -- ===== marginals =====
    s1.obs_a_act,
    s1.obs_b_act,
    s1.pers_a,
    s1.pers_b,
    case when s1.pers_a > 0 then cast(round(s1.obs_a_act * 1.0 / s1.pers_a, 2) as float) else null end as mentions_per_person_a,
    case when s1.pers_b > 0 then cast(round(s1.obs_b_act * 1.0 / s1.pers_b, 2) as float) else null end as mentions_per_person_b,

    -- ===== EVENT LIFT: observed over a population-rate expected =====
    cast(round(s1.obs_exp, 3) as float) as obs_exp,
    case when s1.obs_exp > 0 then cast(round(s1.obs * 1.0 / s1.obs_exp, 3) as float) else null end as obs_lift,
    case when s1.obs_exp_fma > 0 then cast(round(s1.obs_fma * 1.0 / s1.obs_exp_fma, 3) as float) else null end as obs_lift_fma,
    case when s1.obs_exp_fmb > 0 then cast(round(s1.obs_fmb * 1.0 / s1.obs_exp_fmb, 3) as float) else null end as obs_lift_fmb,
    case when s1.obs_exp_fmab > 0 then cast(round(s1.obs_fmab * 1.0 / s1.obs_exp_fmab, 3) as float) else null end as obs_lift_fmab,
    case when s1.obs_exp_clear > 0 then cast(round(s1.obs_clear * 1.0 / s1.obs_exp_clear, 3) as float) else null end as obs_lift_clear,
    -- Byar approximation, exact only under independence; multiply the half-width
    -- by sqrt(deff) for an interval that allows for clustering within person
    case when s1.obs > 0 and s1.obs_exp > 0
      then cast(round((s1.obs * power(1.0 - 1.0/(9.0*s1.obs) - 1.96/(3.0*sqrt(s1.obs*1.0)), 3)) / s1.obs_exp, 3) as float) else null end as obs_lift_lo,
    case when s1.obs >= 0 and s1.obs_exp > 0
      then cast(round(((s1.obs + 1.0) * power(1.0 - 1.0/(9.0*(s1.obs+1.0)) + 1.96/(3.0*sqrt(s1.obs+1.0)), 3)) / s1.obs_exp, 3) as float) else null end as obs_lift_hi,

    -- ===== PERSON LIFT: width-scaled, approximate =====
    cast(round(s1.pers_exp, 3) as float) as pers_exp,
    case when s1.pers_exp > 0 then cast(round(s1.pers * 1.0 / s1.pers_exp, 3) as float) else null end as pers_lift,
    case when s1.pers_exp_fma > 0 then cast(round(s1.pers_fma * 1.0 / s1.pers_exp_fma, 3) as float) else null end as pers_lift_fma,
    case when s1.pers_exp_fmb > 0 then cast(round(s1.pers_fmb * 1.0 / s1.pers_exp_fmb, 3) as float) else null end as pers_lift_fmb,
    case when s1.pers_exp_fmab > 0 then cast(round(s1.pers_fmab * 1.0 / s1.pers_exp_fmab, 3) as float) else null end as pers_lift_fmab,
    case when s1.pers_exp_fmab_inc > 0 then cast(round(s1.pers_fmab_inc * 1.0 / s1.pers_exp_fmab_inc, 3) as float) else null end as pers_lift_fmab_inc,

    -- ===== SHAPE: not magnitude, and the better discriminators on Synthea =====
    case when s1.obs > 0 then cast(round(s1.obs_same_visit * 1.0 / s1.obs, 4) as float) else null end as same_visit_frac,
    case when s1.pers > 0 then cast(round(s1.pers_same_visit * 1.0 / s1.pers, 4) as float) else null end as pers_same_visit_frac,
    case when s1.obs > 0 then cast(round(s1.lag_sum * 1.0 / s1.obs, 2) as float) else null end as lag_mean,
    case when s1.obs > 0 then cast(round(s1.lag_abs_sum * 1.0 / s1.obs, 2) as float) else null end as lag_abs_mean,
    case when s1.obs > 1 and (s1.lag_sq * 1.0 / s1.obs) - power(s1.lag_sum * 1.0 / s1.obs, 2) > 0
      then cast(round(sqrt((s1.lag_sq * 1.0 / s1.obs) - power(s1.lag_sum * 1.0 / s1.obs, 2)), 2) as float) else null end as lag_sd,

    -- ===== CONFOUNDING DIAGNOSTICS =====
    cast(round(s1.util_ratio, 3) as float) as util_ratio,
    cast(round(s1.util_ratio_a, 3) as float) as util_ratio_a,
    cast(round(s1.util_ratio_b, 3) as float) as util_ratio_b,
    case when s1.total_persons > 0 and (s1.total_util_sq * 1.0 / s1.total_persons) - power(s1.total_util_sum * 1.0 / s1.total_persons, 2) > 0
      then cast(round(((s1.util_sum * 1.0 / nullif(s1.util_n, 0)) - (s1.total_util_sum * 1.0 / s1.total_persons))
        / sqrt((s1.total_util_sq * 1.0 / s1.total_persons) - power(s1.total_util_sum * 1.0 / s1.total_persons, 2)), 3) as float)
      else null end as util_z,
    cast(round(s1.deff, 3) as float) as deff,
    case when s1.deff > 0 then cast(round(sqrt(s1.deff), 3) as float) else null end as ci_infl,

    -- ===== INTAKE: days from enrollment to first mention, re-cuttable =====
    s1.fm_intake_days_a,
    s1.fm_intake_days_b

  into @results_database_schema.cab_s50_all
  from s1
    left outer join @results_database_schema.cab_vocab_all_output ca on ca.concept_id = s1.concept_a
    left outer join @results_database_schema.cab_vocab_all_output cb on cb.concept_id = s1.concept_b
  where
    s1.obs * 1.0 / nullif(s1.obs_a_act, 0) >= @cab_min_conditional_prob
    or s1.obs * 1.0 / nullif(s1.obs_b_act, 0) >= @cab_min_conditional_prob
    or s1.pers * 1.0 / nullif(s1.pers_a, 0) >= @cab_min_conditional_prob
    or s1.pers * 1.0 / nullif(s1.pers_b, 0) >= @cab_min_conditional_prob
  ;

  {@create_index_ddl} ? {
    create index ix_cab5_all on @results_database_schema.cab_s50_all (pair_type, anchor_code, concept_a, concept_b);
    update statistics @results_database_schema.cab_s10_person_all;
    update statistics @results_database_schema.cab_s20_marginal_all;
    update statistics @results_database_schema.cab_s30_all;
    update statistics @results_database_schema.cab_s40_all;
    update statistics @results_database_schema.cab_s50_all;
  }


-- ============================================================
-- cab_s55_pair_all  -  ONE ROW PER PAIR, anchor 1
--
-- cab_s50_all is one row per pair per anchor per interval, which is right for
-- reading and wrong for feeding anything. This pivots the three anchor-1
-- intervals onto one row and attaches the recording-pattern guidance for both
-- concepts, so every number needed to judge a pair sits together.
--
-- WHICH LIFT TO READ. pattern_a / pattern_b and grain_a / grain_b come from
-- cab_s54_grain_guide, and lift_to_read states the consequence:
--   A all,   B all    ->  lift_after
--   A all,   B first  ->  lift_after_fmb
--   A first, B all    ->  lift_after_fma
--   A first, B first  ->  lift_after_fmb, NOT fmab
-- A stays all-mention wherever possible because A is the anchor, and an anchor
-- must be available whenever B occurs. Collapsing A to a single date means that
-- date has to land near B, which fails for a third-line drug started years into
-- a chronic course. fmab answers a narrower question -- did these two things
-- get first RECORDED together -- which is onset synchrony rather than
-- association, and at IU it is contaminated by problem lists transcribed at
-- enrollment. Either side episodic gives 'unresolved': read all-mention and
-- fmb both and treat disagreement as the answer.
--
-- The rest of the row: magnitude (lift per interval per grain), shape (lag_sd,
-- dir_ab, same_visit_frac), trust (util_ratio, deff, support) and the marginals
-- that bound what person lift can reach. It picks no winner and emits no score.
-- Anchor 2 and anchor 4 stay in cab_s50_all.
-- ============================================================
drop table if exists @results_database_schema.cab_s55_pair_all;

with s1 as ( -- the three anchor-1 intervals pivoted onto one row
select
  a.pair_type,
  a.pair_type_t,
  a.concept_a,
  a.concept_name_a,
  a.concept_b,
  a.concept_name_b,
  sum(a.obs) as obs_all,
  max(case when a.interval_code = 1 then a.obs else null end) as obs_same_day,
  max(case when a.interval_code = 2 then a.obs else null end) as obs_after,
  max(case when a.interval_code = 3 then a.obs else null end) as obs_before,
  max(case when a.interval_code = 1 then a.pers else null end) as pers_same_day,
  max(case when a.interval_code = 2 then a.pers else null end) as pers_after,
  max(case when a.interval_code = 3 then a.pers else null end) as pers_before,
  max(case when a.interval_code = 1 then a.obs_lift else null end) as lift_same_day,
  max(case when a.interval_code = 2 then a.obs_lift else null end) as lift_after,
  max(case when a.interval_code = 3 then a.obs_lift else null end) as lift_before,
  max(case when a.interval_code = 1 then a.obs_lift_fmb else null end) as lift_same_day_fmb,
  max(case when a.interval_code = 2 then a.obs_lift_fma else null end) as lift_after_fma,
  max(case when a.interval_code = 2 then a.obs_lift_fmb else null end) as lift_after_fmb,
  max(case when a.interval_code = 2 then a.obs_lift_fmab else null end) as lift_after_fmab,
  max(case when a.interval_code = 2 then a.pers_lift else null end) as pers_lift_after,
  max(case when a.interval_code = 2 then a.lag_mean else null end) as lag_mean,
  max(case when a.interval_code = 2 then a.lag_sd else null end) as lag_sd,
  max(case when a.interval_code = 1 then a.same_visit_frac else null end) as same_visit_frac,
  max(case when a.interval_code = 2 then a.util_ratio else null end) as util_ratio,
  max(case when a.interval_code = 2 then a.util_ratio_a else null end) as util_ratio_a,
  max(case when a.interval_code = 2 then a.util_ratio_b else null end) as util_ratio_b,
  max(case when a.interval_code = 2 then a.deff else null end) as deff,
  max(a.obs_a_act) as obs_a_act,
  max(a.obs_b_act) as obs_b_act,
  max(a.pers_a) as pers_a,
  max(a.pers_b) as pers_b,
  max(a.mentions_per_person_a) as mentions_per_person_a,
  max(a.mentions_per_person_b) as mentions_per_person_b,
  max(a.fm_intake_days_a) as fm_intake_days_a,
  max(a.fm_intake_days_b) as fm_intake_days_b
from @results_database_schema.cab_s50_all a
where a.anchor_code = 1
group by
  a.pair_type,
  a.pair_type_t,
  a.concept_a,
  a.concept_name_a,
  a.concept_b,
  a.concept_name_b
)
select
  a.pair_type,
  a.pair_type_t,
  a.concept_a,
  a.concept_name_a,
  a.concept_b,
  a.concept_name_b,
  ga.pattern as pattern_a,
  gb.pattern as pattern_b,
  ga.grain as grain_a,
  gb.grain as grain_b,
  case
    when ga.grain = 'all' and gb.grain = 'all' then 'lift_after'
    when ga.grain = 'all' and gb.grain = 'first' then 'lift_after_fmb'
    when ga.grain = 'first' and gb.grain = 'all' then 'lift_after_fma'
    when ga.grain = 'first' and gb.grain = 'first' then 'lift_after_fmb'
    else 'unresolved -- read lift_after and lift_after_fmb both'
  end as lift_to_read,
  cast(round(a.mentions_per_person_a, 3) as float) as mentions_per_person_a,
  cast(round(a.mentions_per_person_b, 3) as float) as mentions_per_person_b,
  a.obs_all,
  a.obs_same_day,
  a.obs_after,
  a.obs_before,
  a.pers_same_day,
  a.pers_after,
  a.pers_before,
  a.lift_same_day,
  a.lift_after,
  a.lift_before,
  a.lift_same_day_fmb,
  a.lift_after_fma,
  a.lift_after_fmb,
  a.lift_after_fmab,
  a.pers_lift_after,
  a.lag_mean,
  a.lag_sd,
  a.same_visit_frac,
  case when a.obs_after + a.obs_before > 0 then cast(round(a.obs_after * 1.0 / (a.obs_after + a.obs_before), 4) as float) else null end as dir_ab,
  a.util_ratio,
  a.util_ratio_a,
  a.util_ratio_b,
  a.deff,
  a.fm_intake_days_a,
  a.fm_intake_days_b,
  a.obs_a_act,
  a.obs_b_act,
  a.pers_a,
  a.pers_b
into @results_database_schema.cab_s55_pair_all
from s1 a
  left outer join @results_database_schema.cab_s54_grain_guide ga on a.concept_a = ga.concept_id and cast(a.pair_type / 100 as int) = ga.src
  left outer join @results_database_schema.cab_s54_grain_guide gb on a.concept_b = gb.concept_id and (a.pair_type % 100) = gb.src
;

{@create_index_ddl} ? {
  create index ix_cab55_pair on @results_database_schema.cab_s55_pair_all (pair_type, concept_a, concept_b);
  update statistics @results_database_schema.cab_s55_pair_all;
}






  -- ============================================================
  -- cab_timing_all  -  run timing rolled up from cab_process_log
  -- Built at the very end of finalize so the log is complete (every batch has
  -- logged its steps; finalize does not write to the log). One table, three
  -- report_section values, each a different grain of the same measure -- the
  -- gap between a step's timestamp and the previous step's in the same batch:
  --   'step_detail'  one row per (batch, step): that step's duration
  --   'step_avg'     one row per named step: avg/max duration across batches
  --   'batch_total'  one row per batch: wall-clock start..end
  -- Exportable like the other _all tables, and queryable in place. Row order is
  -- not fixed here; sort when you read it.
  -- ============================================================
  drop table if exists @results_database_schema.cab_timing_all;

  with ordered as ( -- attach each step's previous timestamp within its batch
  select
    a.batch_number,
    a.table_name,
    a.step,
    a.step_datetime,
    lag(a.step_datetime) over (partition by a.batch_number order by a.step_datetime) as prev_datetime
  from @results_database_schema.cab_process_log a
  where a.batch_number <= @max_batch_number
  ), s_detail as ( -- per (batch, step) duration
  select
    'step_detail' as report_section,
    'by_batch' as scope,
    a.batch_number,
    a.step,
    a.table_name,
    cast(datediff(second, a.prev_datetime, a.step_datetime) as float) as seconds,
    cast(null as float) as max_seconds,
    cast(null as int) as batches_seen
  from ordered a
  where a.prev_datetime is not null
  ), s_avg as ( -- per named step, averaged across all batches
  select
    'step_avg' as report_section,
    'all_batches' as scope,
    cast(null as int) as batch_number,
    a.step,
    a.table_name,
    cast(avg(datediff(second, a.prev_datetime, a.step_datetime)) as float) as seconds,
    cast(max(datediff(second, a.prev_datetime, a.step_datetime)) as float) as max_seconds,
    cast(count(*) as int) as batches_seen
  from ordered a
  where a.prev_datetime is not null
  group by a.step, a.table_name
  ), s_batch as ( -- per batch, wall-clock start..end
  select
    'batch_total' as report_section,
    'by_batch' as scope,
    a.batch_number,
    cast(null as int) as step,
    cast(null as varchar(100)) as table_name,
    cast(datediff(second, min(a.step_datetime), max(a.step_datetime)) as float) as seconds,
    cast(null as float) as max_seconds,
    cast(null as int) as batches_seen
  from @results_database_schema.cab_process_log a
  where a.batch_number <= @max_batch_number
  group by a.batch_number
  )
  select report_section, scope, batch_number, step, table_name, seconds, max_seconds, batches_seen
  into @results_database_schema.cab_timing_all
  from s_detail
  union all
  select report_section, scope, batch_number, step, table_name, seconds, max_seconds, batches_seen
  from s_avg
  union all
  select report_section, scope, batch_number, step, table_name, seconds, max_seconds, batches_seen
  from s_batch
  ;

