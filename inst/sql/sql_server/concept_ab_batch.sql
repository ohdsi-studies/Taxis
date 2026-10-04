/* ==============================================================================
TAXIS Concept AB Association Mining Engine (Pipeline v57)
Script: concept_ab_batch.sql — PER-BATCH BUILD (runs once per batch in a loop)

ORIGINAL AUTHORSHIP & SCIENTIFIC ATTRIBUTION:
  All SQL scripts, database architectures, 40-batch random partitioning
  strategies, measurement key packing schemes, and original analytic algorithms
  in the TAXIS Concept AB Mining Pipeline were conceived, designed, and authored by:
    Stephen H. Bandeian, MD, JD
    Principal Investigator, Johns Hopkins University School of Medicine

STUDY LEADERSHIP:
  • Stephen H. Bandeian, MD, JD – Principal Investigator (Original Analytic Code & SQL Author)
  • J. Marc Overhage, MD, PhD – Co-Principal Investigator, The Overhage Group / Indiana Univ
  • Gowtham Rao, MD, PhD – Investigator, CoReason, Inc. / OHDSI
  • Shaun Grannis, MD, MS – Investigator, Regenstrief Institute / Indiana Univ
==============================================================================

WHAT THIS DOES / WHY
--------------------
This is the core of the CONCEPT_AB pipeline. For one batch of persons it
builds patient-level event tables and then counts, for every pair of
clinical concepts, how often the two co-occur within a +/- @window_days
time window. Those pair counts are the raw material from which the
finalize step computes association strength (lift) to separate genuine
clinical relationships from incidental co-occurrences.

The script runs ONCE PER BATCH; the R driver calls it in a loop, passing
a different @batch_number each time. Every batch appends its counts into
the shared cumulative tables created by init. Batching keeps memory and
runtime manageable on large populations; the results are identical to
processing everyone at once because the cumulative tables simply sum.

CONCEPT REPRESENTATION  (some concept_ids are NON-OMOP by design)
----------------------------------------------------------------
Every concept in the output — condition, procedure, device, drug, and
measurement/observation result — is represented by a single bigint
concept_id, so downstream pair-building can treat all domains uniformly.

For conditions and procedures/devices these are ordinary OMOP standard
concept_ids. But TWO families are deliberately NOT OMOP concepts, because
OMOP has no single standard concept for the thing we need to count:

  1. DRUG  -> ing_form_key (from cab_vocab_all_drug_ing_form).
     We count drugs at the ingredient + dose-form-category level, not at the
     raw drug-product level (e.g. "lisinopril - oral tablet", collapsing the
     many strengths/brands). No OMOP concept expresses that combination, so a
     minted bigint surrogate (ing_form_key) stands in as the concept_id.

  2. MEAS/OBS RESULT -> a PACKED key, minted in the last step of s06/s07:
         concept_id = test_concept_id * 1e9 + <result component>
     This binds a test to its result (a flag, a categorical value, an integer,
     or a reserved no-result / unusable / assertion code) as one id, so that
     "HbA1c: high" and "HbA1c: normal" are distinct, countable concepts. OMOP
     stores test and result in separate columns, not as one concept, so again
     there is no standard id and the pack supplies one.

CONSEQUENCES (true for both families):
  - These ids do NOT exist in the OMOP concept table. Joining them to
    @omop_reference_schema.concept returns nothing; a human-readable name must
    be built by DECODING (unpack the meas/obs key into test + result, or look
    ing_form_key up in cab_vocab_all_drug_ing_form). This is done in
    post-processing, not in the pipeline.
  - They are large. test_concept_id * 1e9 pushes result ids well above normal
    concept_id range, so every column that carries a concept_id — cab_s06/s07,
    cab_s20 marginals, cab_s30 concept_a / concept_b — is bigint.
  - Each mapping is deterministic: a given (ingredient, form) or (test, result)
    always yields the same id, so the same concept aggregates correctly across
    records and across batches.

WHAT IT BUILDS, IN ORDER
------------------------
  1. cab_person_batch  -- this batch's slice of persons (from the
     init-built all_persons_batch, where batch_number = @batch_number).
  2. cab_s00..cab_s09  -- per-patient staging tables, one per domain
     (observation period, visits, conditions, procedures, devices, drugs,
     observations, measurements, and the test-level observation/measurement
     tables). Each is deduplicated to one row per person/concept/date and
     flagged with concept_fm_flag (the person's FIRST occurrence of that
     concept, or test+result), and indexed on (person_id, start_bucket)
     to speed the pair join.
  3. cab_s10 / cab_s20 -- per-batch person counts and per-concept
     marginals (all-mention and first-mention).
  4. cab_s30           -- the concept-pair co-occurrence counts, for every
     domain combination. Each pair carries event and person counts,
     directional splits (a-before-b / same-day / b-before-a), same-visit
     counts, and the parallel first-mention variants (fma / fmb / fmab).
     Built with a two-level aggregation (per-person collapse, then sum) so
     the person-level distinct counts stay fast on large pairs.
  5. s35 / s36         -- descriptive adjudication profiles for the test
     domains: s35 counts records by which result-bearing fields are
     populated, s36 gives the actual attribute concept ids behind those
     flags (not part of the co-occurrence statistics).

FIRST-MENTION (fm) NOTE
-----------------------
Maintenance drugs and chronic conditions repeat across a record and can
inflate co-occurrence counts, flattening lift. First-mention counts
(collapsing each concept to its first occurrence) mitigate this. Both
all-mention and first-mention counts are captured here so either can be
used downstream without re-running.

PREREQUISITES
-------------
- init (concept_ab_init.sql) must have run: all_persons_batch and the
  empty cumulative tables must exist.
- Project lookup tables must exist in @project_reference_schema:
    cab_vocab_all_visit_hierarchy   (visit level lookup)
    cab_vocab_all_procedure         (procedure concept lookup)
    cab_vocab_all_device            (device concept lookup)
    cab_vocab_all_drug_ing_form     (drug input -> ing_form_key)
    cab_vocab_all_meas_obs_test     (test lookup: domain, is_question,
                                     is_assertion_eligible, flag_concept_id)
- The OMOP standard vocabulary 'concept' table must exist in
  @omop_reference_schema (used to recover coded measurement values).

PARAMETERS
----------
  @source_cdm_schema         -- OMOP CDM fact tables (input data)
  @project_reference_schema  -- project-built lookup tables (list above)
  @omop_reference_schema     -- OMOP standard vocabulary (concept table)
  @results_database_schema   -- where staging + cumulative tables are written
  @batch_count               -- total number of batches
  @batch_number              -- this batch's number (0 .. @batch_count-1)
  @window_days               -- +/- day window for pair co-occurrence
  @cab_min_ab_obs            -- minimum pair EVENT count to retain a pair in a
                             --   batch. The predicate is '>', so a value of 5
                             --   retains pairs with 6 or more.
  @data_profile_batch_limit  -- the descriptive profiling blocks (s35/s36
                             --   adjudication, s37 lag decay, s38 record
                             --   structure, s39 concept recording pattern) run
                             --   only for batch_number <= this. They characterise
                             --   what measurement and observation records look
                             --   like, which needs a sample rather than a
                             --   census; persons are randomly partitioned, so
                             --   any batches are a random sample. At 2 of 20
                             --   this is a 10% sample and recovers roughly a
                             --   third of total runtime -- s35 and s36 were
                             --   38% of it. They feed nothing in the
                             --   cab_s40/s50 statistics pipeline.

STEP TIMING / LOGGING
---------------------
Each numbered step appends one row to @results_database_schema.cab_process_log
(batch_number, table_name, step, step_datetime) at its completion — step 0 is
batch start. cab_process_log is created once by init and accumulates across the
batch loop. A step's duration is the gap between its step_datetime and the
previous step's within the same batch; total batch time is last minus first.
This makes per-step, per-batch timing visible so slow steps can be identified
and tuned (see diagnostics/timing_report.sql).

*/

{DEFAULT @now_expr = CURRENT_TIMESTAMP}
{DEFAULT @create_index_ddl = true}

---===================================Build of Pipeline Batch Files===============================================

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'batch_start' as table_name, 0 as step, @now_expr as step_datetime;

drop table if exists @results_database_schema.cab_person_batch;

select
  a.person_id,
  a.batch_number
into @results_database_schema.cab_person_batch
from @results_database_schema.all_persons_batch a
where a.batch_number = @batch_number
;

{@create_index_ddl} ? {
create index idx_cpb_pid on @results_database_schema.cab_person_batch (person_id);
update statistics @results_database_schema.cab_person_batch;
}

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_person_batch' as table_name, 1 as step, @now_expr as step_datetime;




drop table if exists @results_database_schema.cab_s00_obs_period;

with s0 as (
select
  distinct
  a.observation_period_id,
  a.person_id,
  a.observation_period_start_date,
  a.observation_period_end_date,
  a.period_type_concept_id, count(*) over(partition by a.person_id) as spans_per_person
from @source_cdm_schema.observation_period a
  inner join @results_database_schema.cab_person_batch p on a.person_id = p.person_id
), s1 as (
select
  a.observation_period_id,
  a.person_id,
  a.observation_period_start_date,
  a.observation_period_end_date,
  spans_per_person,
  coalesce(datediff(day, lag(a.observation_period_end_date) over(partition by a.person_id order by a.observation_period_start_date), a.observation_period_start_date) - 1, 9999999) as gap,
  case
    when coalesce(datediff(day, lag(a.observation_period_end_date) over(partition by a.person_id order by a.observation_period_start_date), a.observation_period_start_date) - 1, 9999999) >= 60 then a.observation_period_start_date
    else null
  end as epi_obs_row_start_date
from s0 a
), s2 as (
select
  a.observation_period_id,
  a.person_id,
  a.observation_period_start_date,
  a.observation_period_end_date,
  a.gap,
  case when a.gap <= 0 then -1 when spans_per_person = 1 then 9 when a.gap between 1 and 360 then 1 else 2 end as span_status, -- -1 = overlapping or adjacent spans; 1 = gaps filled, 2 gaps not filled in, 9 one span per person
  case when a.gap > 360 then a.observation_period_start_date else null end as epi_obs_row_start_date
from s1 a
), s3 as (
select
  distinct
  a.observation_period_id,
  a.person_id,
  a.observation_period_start_date,
  a.observation_period_end_date,
  a.gap,
  a.span_status,
  max(a.epi_obs_row_start_date) over(partition by a.person_id order by a.observation_period_start_date rows unbounded preceding) as epi_obs_row_start_date
from s2 a
)
select
  a.observation_period_id,
  a.person_id,
  a.observation_period_start_date,
  a.observation_period_end_date,
  b.period_type_concept_id,
  a.gap,
  a.span_status,
  b.observation_period_id as obs_epi_id,
  b.observation_period_start_date as obs_epi_start_date,
  max(a.observation_period_end_date) over(partition by a.person_id, a.epi_obs_row_start_date) as obs_epi_end_date
into @results_database_schema.cab_s00_obs_period
from s3 a inner join s0 b on a.person_id = b.person_id and b.observation_period_start_date = a.epi_obs_row_start_date
where span_status >= 1
;

{@create_index_ddl} ? {
create index ix_s00_pd on @results_database_schema.cab_s00_obs_period (person_id, observation_period_start_date, observation_period_end_date);
update statistics @results_database_schema.cab_s00_obs_period;
}

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s00_obs_period' as table_name, 1 as step, @now_expr as step_datetime;



drop table if exists @results_database_schema.cab_s01_visit;

with s1 as ( -- the distinct period-qualified visit set (unchanged)
select
distinct
  a.visit_occurrence_id,
  a.person_id,
  a.visit_concept_id,
  coalesce(c.visit_level, 99) as visit_level,
  a.visit_start_date,
  a.visit_end_date,
  case when dateadd(day, -90, a.visit_start_date) > b.observation_period_start_date and dateadd(day, 90, a.visit_end_date) < b.observation_period_end_date then 1 else 0 end as visit_clear_period
from @source_cdm_schema.visit_occurrence a
  inner join @results_database_schema.cab_s00_obs_period b on a.person_id = b.person_id and a.visit_start_date between b.observation_period_start_date and b.observation_period_end_date
  left join @project_reference_schema.cab_vocab_all_visit_hierarchy c on a.visit_concept_id = c.visit_concept_id
  inner join @results_database_schema.cab_person_batch p on a.person_id = p.person_id
)
select
  a.visit_occurrence_id,
  a.person_id,
  a.visit_concept_id,
  a.visit_level,
  a.visit_start_date,
  a.visit_end_date,
  a.visit_clear_period,
  count(*) over(partition by a.person_id) as util_score
into @results_database_schema.cab_s01_visit
from s1 a
;

{@create_index_ddl} ? {
create index ix_cab_s01_visit_person_visit on @results_database_schema.cab_s01_visit
(person_id, visit_occurrence_id);
update statistics @results_database_schema.cab_s01_visit;
}

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s01_visit' as table_name, 1 as step, @now_expr as step_datetime;


-- =========================================================
-- cab_person_attr  -  two person-grain attributes, both piggybacked on
-- work the batch has already done. No CDM fact table is re-scanned.
--
-- util_score: the person's visit count, off cab_s01_visit, which is already
--   deduplicated and already period-qualified -- so visits outside an
--   observation window do not count as observable utilization. This is the
--   confounder that population-baseline lift has no term for: sick people
--   accumulate more of everything, so any two concepts co-occur above the
--   independence baseline whether or not they are related, and the inflation
--   scales with each concept's utilization elasticity rather than being a
--   constant that cancels in ranking.
--
-- intake_bucket: the start of the person's FIRST observation period, from the
--   source table. Not the containing period: for a person with two spans
--   separated by years the second is a RETURN, not an intake -- the record
--   already holds their history, so anchoring on the containing period would
--   flag genuine later incidence as transcription. Taken from the source
--   rather than cab_s00_obs_period because s00 drops span_status = -1 rows
--   for reasons unrelated to this question.
--
-- Joined into each staging table's final select, so nothing carries through
-- the CTE chains and no new join enters cab_s30.
-- =========================================================
drop table if exists @results_database_schema.cab_person_attr;

with s1 as ( -- visit count per person
select
  a.person_id,
  cast(count(*) as bigint) as util_score
from @results_database_schema.cab_s01_visit a
group by a.person_id
), s2 as ( -- first observation period start = entry into the system
select
  a.person_id,
  datediff(day, '2000-01-03', min(a.observation_period_start_date)) as intake_bucket,
  datediff(day, '2000-01-03', max(a.observation_period_end_date)) as obs_end_bucket
from @source_cdm_schema.observation_period a
  inner join @results_database_schema.cab_person_batch p on a.person_id = p.person_id
group by a.person_id
)
select
  a.person_id,
  coalesce(b.util_score, 0) as util_score,
  -- util_decile: plain ntile(10) on the visit count. Deciles rather than
  -- quintiles because deciles can always be pooled into quintiles later by
  -- summing pairs of them, and the reverse is impossible. No hardcoded
  -- cutpoints, so nothing about the distribution is baked in. Note the
  -- deciles will NOT be exactly equal in size -- visit counts are integers
  -- with heavy ties at the low end and ntile splits a tie group arbitrarily
  -- across a boundary. Harmless: each decile is still internally homogeneous
  -- on utilization, which is all the stratified expected requires.
  ntile(10) over (order by coalesce(b.util_score, 0)) as util_decile,
  c.intake_bucket,
  c.obs_end_bucket
into @results_database_schema.cab_person_attr
from @results_database_schema.cab_person_batch a
  left outer join s1 b on a.person_id = b.person_id
  left outer join s2 c on a.person_id = c.person_id
;

{@create_index_ddl} ? {
create index ix_cpa_pid on @results_database_schema.cab_person_attr (person_id);
update statistics @results_database_schema.cab_person_attr;
}

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_person_attr' as table_name, 1 as step, @now_expr as step_datetime;


drop table if exists @results_database_schema.cab_s02_condition;
with s1 as (
select
  2 as input_type,
  a.person_id,
  a.visit_occurrence_id,
  c.visit_concept_id,
  coalesce(c.visit_level, 99999) as visit_level,
  coalesce(c.visit_clear_period,-99) as visit_clear_period,
  a.condition_occurrence_id,
  a.condition_concept_id as concept_id,
  a.condition_start_date as start_date,
  a.condition_end_date as end_date
from @source_cdm_schema.condition_occurrence a
  inner join @results_database_schema.cab_person_batch p on a.person_id = p.person_id
  left join @results_database_schema.cab_s01_visit c on a.person_id = c.person_id and a.visit_occurrence_id = c.visit_occurrence_id
), s2 as ( -- dedup: pick winning record per (person, concept_id, start_date)
select
  10 as src,
  a.person_id,
  a.visit_occurrence_id,
  a.visit_concept_id,
  a.visit_level,
  a.visit_clear_period,
  a.concept_id,
  a.start_date,
  a.end_date,
  row_number() over (
    partition by a.person_id, a.concept_id, a.start_date
    order by a.visit_level, coalesce(a.end_date, a.start_date) desc, a.condition_occurrence_id
  ) as rn
from s1 a
)
select
  a.src,
  a.person_id,
  a.visit_occurrence_id,
  a.visit_concept_id,
  a.visit_clear_period,
  a.concept_id,
  case when a.start_date = min(a.start_date) over(partition by a.person_id, a.concept_id) then 1 else 0 end as concept_fm_flag,
  pa.util_score,
  pa.util_decile,
  pa.intake_bucket,
  case when a.start_date = min(a.start_date) over(partition by a.person_id, a.concept_id) and datediff(day, '2000-01-03', a.start_date) - pa.intake_bucket <= 30 then 1 else 0 end as fm_early_flag,
  case when a.start_date = min(a.start_date) over(partition by a.person_id, a.concept_id) then datediff(day, '2000-01-03', a.start_date) - pa.intake_bucket else null end as fm_days_from_intake,
  case when ch.concept_id is null then 0 else 1 end as chronic_flag,
  pa.obs_end_bucket,
  a.start_date,
  a.end_date,
  datediff(day, '2000-01-03', a.start_date) as start_bucket,
  datediff(day, '2000-01-03', a.end_date) as end_bucket
into @results_database_schema.cab_s02_condition
from s2 a
  left outer join @results_database_schema.cab_person_attr pa on a.person_id = pa.person_id
  left outer join @project_reference_schema.cab_vocab_all_chronic_conditions ch on a.concept_id = ch.concept_id
where a.rn = 1
;

{@create_index_ddl} ? {
create index ix_s02_pb on @results_database_schema.cab_s02_condition (person_id, start_bucket);
update statistics @results_database_schema.cab_s02_condition;
}

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s02_condition' as table_name, 1 as step, @now_expr as step_datetime;



drop table if exists @results_database_schema.cab_s03_procedure;

with s1 as (
select
  a.person_id,
  a.visit_occurrence_id,
  c.visit_concept_id,
  coalesce(c.visit_level, 99999) as visit_level,
  coalesce(c.visit_clear_period,-99) as visit_clear_period,
  a.procedure_occurrence_id,
  b.concept_id,
  coalesce(b.concept_rbcs_1, 99) as concept_rbcs_1,
  coalesce(b.concept_rvu, 0.01) as concept_rvu,
  a.procedure_date as start_date,
  a.procedure_date as end_date
from @source_cdm_schema.procedure_occurrence a
  inner join @project_reference_schema.cab_vocab_all_procedure b on a.procedure_concept_id = b.concept_id_in
  inner join @results_database_schema.cab_person_batch p on a.person_id = p.person_id
  left outer join @results_database_schema.cab_s01_visit c on a.person_id = c.person_id and a.visit_occurrence_id = c.visit_occurrence_id
), s2 as ( -- dedup: pick winning record per (person, visit, procedure, start_date)
select
  20 as src,
  a.person_id,
  a.visit_occurrence_id,
  a.visit_concept_id,
  a.visit_clear_period,
  a.concept_id,
  a.concept_rbcs_1,
  a.concept_rvu,
  a.start_date,
  a.end_date,
  row_number() over (
    partition by a.person_id, a.concept_id, a.start_date
    order by a.visit_level, a.procedure_occurrence_id
  ) as rn
from s1 a
)
select
  a.src,
  a.person_id,
  a.visit_occurrence_id,
  a.visit_concept_id,
  a.visit_clear_period,
  a.concept_id,
  a.concept_rbcs_1,
  a.concept_rvu,
  case when a.concept_rbcs_1 in (1, 2, 3, 4, 5) then 1 else 0 end as trigger_flag,
  case when a.start_date = min(a.start_date) over(partition by a.person_id, a.concept_id) then 1 else 0 end as concept_fm_flag,
  pa.util_score,
  pa.util_decile,
  pa.intake_bucket,
  case when a.start_date = min(a.start_date) over(partition by a.person_id, a.concept_id) and datediff(day, '2000-01-03', a.start_date) - pa.intake_bucket <= 30 then 1 else 0 end as fm_early_flag,
  case when a.start_date = min(a.start_date) over(partition by a.person_id, a.concept_id) then datediff(day, '2000-01-03', a.start_date) - pa.intake_bucket else null end as fm_days_from_intake,
  a.start_date,
  a.end_date,
  datediff(day, '2000-01-03', a.start_date) as start_bucket,
  datediff(day, '2000-01-03', a.end_date) as end_bucket
into @results_database_schema.cab_s03_procedure
from s2 a
  left outer join @results_database_schema.cab_person_attr pa on a.person_id = pa.person_id
where a.rn = 1
;

{@create_index_ddl} ? {
create index ix_s03_pb on @results_database_schema.cab_s03_procedure (person_id, start_bucket);
update statistics @results_database_schema.cab_s03_procedure;
}

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s03_procedure' as table_name, 1 as step, @now_expr as step_datetime;



drop table if exists @results_database_schema.cab_s04_device;

with s1 as (
select
  a.person_id,
  a.device_exposure_id,
  coalesce(a.visit_occurrence_id, -1) as visit_occurrence_id,
  coalesce(c.visit_level, 99999) as visit_level,
  c.visit_concept_id,
  coalesce(c.visit_clear_period, -99) as visit_clear_period,
  b.concept_id,
  a.device_exposure_start_date as start_date,
  case
    when b.implant_flag = 1 then
      case
        when a.device_exposure_end_date is not null and a.device_exposure_end_date > dateadd(day, 365, a.device_exposure_start_date)
        then a.device_exposure_end_date
        else dateadd(day, 365, a.device_exposure_start_date)
      end
    when a.device_exposure_end_date is not null then a.device_exposure_end_date
    else dateadd(day, 0, a.device_exposure_start_date)
  end as end_date
from @source_cdm_schema.device_exposure a
  inner join @results_database_schema.cab_person_batch p on a.person_id = p.person_id
  inner join @project_reference_schema.cab_vocab_all_device b on a.device_concept_id = b.concept_id_in
  left outer join @results_database_schema.cab_s01_visit c on a.person_id = c.person_id and a.visit_occurrence_id = c.visit_occurrence_id
), s2 as ( -- dedup: pick winning record per (person, visit, concept_id, start_date)
select
  30 as src,
  a.person_id,
  a.visit_occurrence_id,
  a.visit_concept_id,
  a.visit_clear_period,
  a.concept_id,
  a.start_date,
  a.end_date,
  row_number() over (
    partition by a.person_id, a.concept_id, a.start_date
    order by a.visit_level asc, a.device_exposure_id
  ) as rn
from s1 a
)
select
  a.src,
  a.person_id,
  a.visit_occurrence_id,
  a.visit_concept_id,
  a.visit_clear_period,
  a.concept_id,
  case when a.start_date = min(a.start_date) over(partition by a.person_id, a.concept_id) then 1 else 0 end as concept_fm_flag,
  pa.util_score,
  pa.util_decile,
  pa.intake_bucket,
  case when a.start_date = min(a.start_date) over(partition by a.person_id, a.concept_id) and datediff(day, '2000-01-03', a.start_date) - pa.intake_bucket <= 30 then 1 else 0 end as fm_early_flag,
  case when a.start_date = min(a.start_date) over(partition by a.person_id, a.concept_id) then datediff(day, '2000-01-03', a.start_date) - pa.intake_bucket else null end as fm_days_from_intake,
  a.start_date,
  a.end_date,
  datediff(day, '2000-01-03', a.start_date) as start_bucket,
  datediff(day, '2000-01-03', a.end_date) as end_bucket
into @results_database_schema.cab_s04_device
from s2 a
  left outer join @results_database_schema.cab_person_attr pa on a.person_id = pa.person_id
where a.rn = 1;

{@create_index_ddl} ? {
create index ix_s04_pb on @results_database_schema.cab_s04_device (person_id, start_bucket);
update statistics @results_database_schema.cab_s04_device;
}

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s04_device' as table_name, 1 as step, @now_expr as step_datetime;



drop table if exists @results_database_schema.cab_s05_drug;

with s1 as ( -- resolve drug + visit + compute end_date + attach provenance rank, all in one pass
select distinct
  a.drug_exposure_id,
  a.person_id,
  coalesce(a.visit_occurrence_id, -1) as visit_occurrence_id,
  coalesce(c.visit_level, 99999) as visit_level,
  c.visit_concept_id,
  coalesce(c.visit_clear_period, -99) as visit_clear_period,
  a.drug_exposure_start_date as start_date,
  case
    when a.drug_exposure_end_date is not null then a.drug_exposure_end_date
    when a.days_supply > 0 then dateadd(day, a.days_supply - 1, a.drug_exposure_start_date)
    else a.drug_exposure_start_date
  end as end_date,
  case
    when a.drug_exposure_end_date is not null then 1
    when a.days_supply > 0 or a.quantity is not null or a.refills is not null then 2
    else 3
  end as end_date_tier,
  b.concept_id,
  b.ingredient_id,
  b.dose_form_concept_id
from @source_cdm_schema.drug_exposure a
  inner join @results_database_schema.cab_person_batch p on a.person_id = p.person_id
  inner join @project_reference_schema.cab_vocab_all_drug_ing_form b on a.drug_concept_id = b.concept_id_in
  left outer join @results_database_schema.cab_s01_visit c on a.person_id = c.person_id and a.visit_occurrence_id = c.visit_occurrence_id
), s2 as ( -- dedup: pick winning record per (person, visit, ing_form_key, start_date)
select
  40 as src,
  a.person_id,
  a.visit_occurrence_id,
  a.visit_concept_id,
  a.visit_clear_period,
  a.start_date,
  a.end_date,
  a.concept_id,
  a.ingredient_id,
  a.dose_form_concept_id,
  row_number() over (
    partition by a.person_id, a.concept_id, a.start_date
    order by a.end_date_tier asc, a.drug_exposure_id
  ) as rn
from s1 a
)
select
  distinct
  a.src,
  a.person_id,
  a.visit_occurrence_id,
  a.visit_concept_id,
  a.visit_clear_period,
  a.concept_id, -- the ing_form_key not  a omop concept
  a.ingredient_id,
  a.dose_form_concept_id,
  case when a.start_date = min(a.start_date) over(partition by a.person_id, a.concept_id) then 1 else 0 end as concept_fm_flag,
  pa.util_score,
  pa.util_decile,
  pa.intake_bucket,
  case when a.start_date = min(a.start_date) over(partition by a.person_id, a.concept_id) and datediff(day, '2000-01-03', a.start_date) - pa.intake_bucket <= 30 then 1 else 0 end as fm_early_flag,
  case when a.start_date = min(a.start_date) over(partition by a.person_id, a.concept_id) then datediff(day, '2000-01-03', a.start_date) - pa.intake_bucket else null end as fm_days_from_intake,
  a.start_date,
  a.end_date,
  datediff(day, '2000-01-03', a.start_date) as start_bucket,
  datediff(day, '2000-01-03', a.end_date) as end_bucket
into @results_database_schema.cab_s05_drug
from s2 a
  left outer join @results_database_schema.cab_person_attr pa on a.person_id = pa.person_id
where a.rn = 1;

{@create_index_ddl} ? {
create index ix_s05_pb on @results_database_schema.cab_s05_drug (person_id, start_bucket);
update statistics @results_database_schema.cab_s05_drug;
}

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s05_drug' as table_name, 1 as step, @now_expr as step_datetime;


-- =====================================================================================================
-- cab_s06_observation / cab_s07_measurement  —  result adjudication + packed-key build
-- =====================================================================================================
-- Each measurement/observation record is reduced to ONE concept_id: a bijective PACKED key
--
--       concept_id = cast(test_concept_id as bigint) * 1000000000 + <value_component>
--
-- computed inline in s5.
--
-- TEST LOOKUP  (cab_vocab_all_meas_obs_test), two-column identity:
--     concept_id_in   -> matches the fact table (join key)
--     concept_id      -> canonical/remapped id (= concept_id_in except CPT4/HCPCS/ICD-proc test
--                        concepts crosswalked to SNOMED/LOINC); used for the pack, output, dedup.
--   plus the precomputed adjudication facts:
--     flag_concept_id                     -> value-side flag: the interpretation concept id when the
--                                            VALUE concept is itself a flag (null otherwise); read by
--                                            the 'val' join and packed directly.
--     is_question / is_assertion_eligible -> test-side value-less split.
--
-- ADJUDICATION (s4 result_shape), first match wins:
--     value-side flag concept present            -> flag        (lab-coded high/low/normal/abnormal)
--     number + BOTH range bounds present         -> flag        (range-derived; one-sided range is
--                                                                 NOT graded -> unusable_result)
--     value_as_concept_id present                -> categorical (a present coded value IS the answer)
--     value_as_number present (no usable range)  -> unusable_result
--       (observation only: a whole number in [0,100000) is 'integer' instead — e.g. Apgar, counts)
--     value_as_string present                    -> unusable_result
--     is_question = 0 and is_assertion_eligible=1 -> assertion
--     otherwise                                  -> no_result
--
-- VALUE COMPONENT packed per shape (the low part of the key):
--     categorical      -> value_as_concept_id
--     flag             -> flag_concept_id: value-side flag passed through, or range-derived
--                         (low 4267416 / high 4328749 / normal 4069590; abnormal only via value-side)
--     integer (obs)    -> 60000000 + value_as_number     (whole number in [0,100000) -> band 60000000..60099999)
--     assertion        -> test concept_id (self)
--     no_result        -> 46237210        (OMOP 'No matching concept' placeholder)
--     unusable_result  -> 70000000        (reserved: value present but not usable as a result)
--
-- If any reserved literal (46237210, 70000000, the 60000000 integer band, or the 1000000000
-- multiplier) is changed, update every occurrence in s4/s5 of BOTH s06 and s07 together, and the
-- decode in the label/post-processing step, so pack and unpack stay inverse.
-- =====================================================================================================

--TODO test concept id muddle; difficulate anyone to understand untangle - concept_id_in is valid omop concept with valid omop name -
--TODO continued muddle results form cleaning of test names -- which is a positive from knowledge graph, but has created the muddle.
drop table if exists @results_database_schema.cab_s06_observation;
with vmap as ( -- string->concept recovery (value_as_concept_id 0 but answer text sits in value_as_string)
select
  upper(ltrim(rtrim(c.concept_name))) as source_text,
  c.concept_id as value_as_concept_id
from @omop_reference_schema.concept c
where c.domain_id = 'Meas Value'
  and c.standard_concept = 'S'
), s0 as (
select
  a.person_id,
  a.visit_occurrence_id,
  a.observation_id,
  b.concept_id as concept_id,
  coalesce(b.is_question, 0) as is_question,
  coalesce(b.is_assertion_eligible, 0) as is_assertion_eligible,
  a.value_as_number as value_as_number,
  nullif(a.value_as_string, '') as value_as_string,
  coalesce(nullif(a.value_as_concept_id, 0), v.value_as_concept_id) as value_as_concept_id,
  a.observation_date as start_date
from @source_cdm_schema.observation a
  inner join @results_database_schema.cab_person_batch p on a.person_id = p.person_id
  inner join @project_reference_schema.cab_vocab_all_meas_obs_test b on b.concept_id_in = a.observation_concept_id
  left outer join vmap v on nullif(a.value_as_concept_id, 0) is null and v.source_text = upper(ltrim(rtrim(a.value_as_string)))
), s4 as (
select
  s0.*,
  case
    when value_as_concept_id is not null then 'categorical'
    when value_as_number is not null and value_as_number = floor(value_as_number)
         and value_as_number >= 0 and value_as_number < 100000 then 'integer'
    when value_as_number is not null then 'unusable_result'
    when value_as_string is not null then 'unusable_result'
    when is_question = 0 and is_assertion_eligible = 1 then 'assertion'
    else 'no_result'
  end as result_shape
from s0
), s5 as (
select
  s4.*,
  cast(s4.concept_id as bigint) * 1000000000 +
  case
    when s4.result_shape = 'categorical' then s4.value_as_concept_id
    when s4.result_shape = 'integer'     then 60000000 + cast(s4.value_as_number as int)
    when s4.result_shape = 'assertion'   then s4.concept_id
    when s4.result_shape = 'no_result'   then 46237210
    else 36309857
  end as result_key
from s4
), s6 as (
select
  distinct
  a.person_id,
  a.visit_occurrence_id,
  coalesce(c.visit_concept_id, -99) as visit_concept_id,
  coalesce(c.visit_level, -99) as visit_level,
  coalesce(c.visit_clear_period,-99) as visit_clear_period,
  a.observation_id,
  a.concept_id,
  a.result_key,
  a.result_shape,
  a.start_date,
  datediff(day, '2000-01-03', a.start_date) as start_bucket
from s5 a
  left outer join @results_database_schema.cab_s01_visit c on a.person_id = c.person_id and a.visit_occurrence_id = c.visit_occurrence_id
), s7 as ( -- dedup: pick winning record per (person, concept, start_date); best result_shape wins
select
  51 as src,
  a.person_id,
  a.visit_occurrence_id,
  a.visit_concept_id,
  a.visit_clear_period,
  a.concept_id,
  a.result_key,
  a.start_date,
  row_number() over (
    partition by a.person_id, a.concept_id, a.start_date
    order by
      case
        when a.result_shape = 'unusable_result' then 5
        when a.result_shape = 'no_result' then 4
        when a.result_shape = 'assertion' then 3
        when a.result_shape = 'integer' then 2
        else 1
      end,
      a.visit_level,
      a.observation_id
  ) as rn
from s6 a
)
select
  distinct
  'observation' as domain,
  a.src,
  a.person_id,
  a.visit_occurrence_id,
  a.visit_concept_id,
  a.visit_clear_period,
  a.concept_id as test_concept_id,
  a.result_key as concept_id,
  case when a.start_date = min(a.start_date) over(partition by a.person_id, a.result_key) then 1 else 0 end as concept_fm_flag,
  pa.util_score,
  pa.util_decile,
  pa.intake_bucket,
  case when a.start_date = min(a.start_date) over(partition by a.person_id, a.result_key) and datediff(day, '2000-01-03', a.start_date) - pa.intake_bucket <= 30 then 1 else 0 end as fm_early_flag,
  case when a.start_date = min(a.start_date) over(partition by a.person_id, a.result_key) then datediff(day, '2000-01-03', a.start_date) - pa.intake_bucket else null end as fm_days_from_intake,
  a.start_date,
  a.start_date as end_date,
  datediff(day, '2000-01-03', a.start_date) as start_bucket,
  datediff(day, '2000-01-03', a.start_date) as end_bucket
into @results_database_schema.cab_s06_observation
from s7 a
  left outer join @results_database_schema.cab_person_attr pa on a.person_id = pa.person_id
where a.rn = 1
;

{@create_index_ddl} ? {
create index ix_s06_pb on @results_database_schema.cab_s06_observation (person_id, start_bucket);
update statistics @results_database_schema.cab_s06_observation;
}

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s06_observation' as table_name, 1 as step, @now_expr as step_datetime;



drop table if exists @results_database_schema.cab_s07_measurement;
with vmap as ( -- string->concept map built from the standard vocabulary, no instance data
select
  upper(ltrim(rtrim(c.concept_name))) as source_text,
  c.concept_id as value_as_concept_id
from @omop_reference_schema.concept c
where c.domain_id = 'Meas Value'
  and c.standard_concept = 'S'
), s0 as (
select
  a.person_id,
  a.visit_occurrence_id,
  a.measurement_id,
  a.measurement_date as start_date,
  b.concept_id as concept_id,
  coalesce(b.is_question, 0) as is_question,
  coalesce(b.is_assertion_eligible, 0) as is_assertion_eligible,
  case
    when a.value_as_number = 0
         and (a.range_low <> 0 or a.range_high <> 0) then 0
    else nullif(a.value_as_number, 0)
  end as value_as_number,
  coalesce(nullif(a.value_as_concept_id, 0), v.value_as_concept_id) as value_as_concept_id,
  case when a.range_low = 0 and a.range_high = 0 then null else a.range_low end as range_low,
  case when a.range_low = 0 and a.range_high = 0 then null else a.range_high end as range_high
from @source_cdm_schema.measurement a
  inner join @results_database_schema.cab_person_batch p on a.person_id = p.person_id
  inner join @project_reference_schema.cab_vocab_all_meas_obs_test b on b.concept_id_in = a.measurement_concept_id
  left outer join vmap v on a.value_as_concept_id = 0 and v.source_text = upper(ltrim(rtrim(a.value_source_value)))
), s1 as ( -- value-side flag fact: the interpretation concept for the VALUE concept, precomputed on the
          -- lookup as flag_concept_id (null when the value is not a flag). keyed on the value concept.
select
  s0.*,
  val.flag_concept_id as val_flag_concept_id
from s0
  left outer join @project_reference_schema.cab_vocab_all_meas_obs_test val on val.concept_id_in = s0.value_as_concept_id
), s4 as ( -- one pass: result_shape (for dedup) and flag_concept_id (the interpretation concept). the
          -- value-side flag is a straight passthrough of the precomputed id; only the range-derived flag
          -- is computed per-record. no string flag_label anywhere.
select
  s1.*,
  case
    when val_flag_concept_id is not null then 'flag'
    when value_as_number is not null and (range_low is not null and range_high is not null) then 'flag'
    when value_as_concept_id is not null then 'categorical'
    when value_as_number is not null then 'unusable_result'
    when is_question = 0 and is_assertion_eligible = 1 then 'assertion'
    else 'no_result'
  end as result_shape,
  case
    when val_flag_concept_id is not null then val_flag_concept_id
    when value_as_number is not null and (range_low is not null and range_high is not null) then
      case
        when range_low is not null and value_as_number < range_low then 4267416
        when range_high is not null and value_as_number > range_high then 4328749
        else 4069590
      end
    else null
  end as flag_concept_id
from s1
), s5 as ( -- pack: key consumes shape + flag_concept_id, so shape and key cannot drift
select
  s4.*,
  cast(s4.concept_id as bigint) * 1000000000 +
  case
    when s4.result_shape = 'flag'        then s4.flag_concept_id
    when s4.result_shape = 'categorical' then s4.value_as_concept_id
    when s4.result_shape = 'assertion'   then s4.concept_id
    when s4.result_shape = 'no_result'   then 46237210
    else 36309857
  end as result_key
from s4
), s6 as (
select
  distinct
  a.person_id,
  a.visit_occurrence_id,
  coalesce(c.visit_concept_id, -99) as visit_concept_id,
  coalesce(c.visit_level, -99) as visit_level,
  coalesce(c.visit_clear_period,-99) as visit_clear_period,
  a.measurement_id,
  a.concept_id,
  a.result_key,
  a.result_shape,
  a.start_date
from s5 a
  left outer join @results_database_schema.cab_s01_visit c on a.person_id = c.person_id and a.visit_occurrence_id = c.visit_occurrence_id
), s7 as ( -- dedup: pick winning record per (person, concept, start_date); best result_shape wins
select
  61 as src,
  a.person_id,
  a.visit_occurrence_id,
  a.visit_concept_id,
  a.visit_clear_period,
  a.concept_id,
  a.result_key,
  a.start_date,
  row_number() over (
    partition by a.person_id, a.concept_id, a.start_date
    order by
      case
        when a.result_shape = 'flag' then 1
        when a.result_shape = 'categorical' then 2
        when a.result_shape = 'assertion' then 3
        when a.result_shape = 'no_result' then 4
        else 5
      end,
      a.visit_level,
      a.measurement_id
  ) as rn
from s6 a
)
select
  distinct
  'measurement' as domain,
  a0.src,
  a0.person_id,
  a0.visit_occurrence_id,
  a0.visit_concept_id,
  a0.visit_clear_period,
  a0.concept_id as test_concept_id,
  a0.result_key as concept_id,
  case when a0.start_date = min(a0.start_date) over(partition by a0.person_id, a0.result_key) then 1 else 0 end as concept_fm_flag,
  pa.util_score,
  pa.util_decile,
  pa.intake_bucket,
  case when a0.start_date = min(a0.start_date) over(partition by a0.person_id, a0.result_key) and datediff(day, '2000-01-03', a0.start_date) - pa.intake_bucket <= 30 then 1 else 0 end as fm_early_flag,
  case when a0.start_date = min(a0.start_date) over(partition by a0.person_id, a0.result_key) then datediff(day, '2000-01-03', a0.start_date) - pa.intake_bucket else null end as fm_days_from_intake,
  a0.start_date,
  a0.start_date as end_date,
  datediff(day, '2000-01-03', a0.start_date) as start_bucket,
  datediff(day, '2000-01-03', a0.start_date) as end_bucket
into @results_database_schema.cab_s07_measurement
from s7 a0
  left outer join @results_database_schema.cab_person_attr pa on a0.person_id = pa.person_id
where a0.rn = 1
;

{@create_index_ddl} ? {
create index ix_s07_pb on @results_database_schema.cab_s07_measurement (person_id, start_bucket);
update statistics @results_database_schema.cab_s07_measurement;
}

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s07_measurement' as table_name, 1 as step, @now_expr as step_datetime;



drop table if exists @results_database_schema.cab_s08_observation_test;
select
  distinct
  domain,
  50 as src,
  person_id,
  visit_occurrence_id,
  visit_concept_id,
  visit_clear_period,
  test_concept_id as concept_id,
  case when start_date = min(start_date) over(partition by person_id, test_concept_id) then 1 else 0 end as concept_fm_flag,
  util_score,
  util_decile,
  intake_bucket,
  case when start_date = min(start_date) over(partition by person_id, test_concept_id) and start_bucket - intake_bucket <= 30 then 1 else 0 end as fm_early_flag,
  case when start_date = min(start_date) over(partition by person_id, test_concept_id) then start_bucket - intake_bucket else null end as fm_days_from_intake,
  start_date,
  end_date,
  start_bucket,
  end_bucket
into @results_database_schema.cab_s08_observation_test
from @results_database_schema.cab_s06_observation
;

{@create_index_ddl} ? {
create index ix_s08_pb on @results_database_schema.cab_s08_observation_test (person_id, start_bucket);
update statistics @results_database_schema.cab_s08_observation_test;
}

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s08_observation_test' as table_name, 1 as step, @now_expr as step_datetime;



drop table if exists @results_database_schema.cab_s09_measurement_test;
select
  distinct
  domain,
  60 as src,
  person_id,
  visit_occurrence_id,
  visit_concept_id,
  visit_clear_period,
  test_concept_id as concept_id,
  case when start_date = min(start_date) over(partition by person_id, test_concept_id) then 1 else 0 end as concept_fm_flag,
  util_score,
  util_decile,
  intake_bucket,
  case when start_date = min(start_date) over(partition by person_id, test_concept_id) and start_bucket - intake_bucket <= 30 then 1 else 0 end as fm_early_flag,
  case when start_date = min(start_date) over(partition by person_id, test_concept_id) then start_bucket - intake_bucket else null end as fm_days_from_intake,
  start_date,
  end_date,
  start_bucket,
  end_bucket
into @results_database_schema.cab_s09_measurement_test
from @results_database_schema.cab_s07_measurement
;

{@create_index_ddl} ? {
create index ix_s09_pb on @results_database_schema.cab_s09_measurement_test (person_id, start_bucket);
update statistics @results_database_schema.cab_s09_measurement_test;
}

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s09_measurement_test' as table_name, 1 as step, @now_expr as step_datetime;





-- cab_s10_person_cum
with s1 as (
  select distinct person_id from @results_database_schema.cab_s02_condition
  union
  select distinct person_id from @results_database_schema.cab_s03_procedure
  union
  select distinct person_id from @results_database_schema.cab_s04_device
  union
  select distinct person_id from @results_database_schema.cab_s05_drug
  union
  select distinct person_id from @results_database_schema.cab_s06_observation
  union
  select distinct person_id from @results_database_schema.cab_s07_measurement
), s2 as ( -- population utilization moments, one row per person
select
  sum(cast(b.util_score as bigint)) as util_sum,
  sum(cast(b.util_score as bigint) * cast(b.util_score as bigint)) as util_sq
from s1 a
  inner join @results_database_schema.cab_person_attr b on a.person_id = b.person_id
), s3 as ( -- visit count, from the table this batch already built. Needed for
-- same_visit_frac's null: two unrelated events land on the same visit with
-- probability about 1 / (visits in the window), so without visit density there
-- is no way to say whether an observed same_visit_frac is above chance.
select
  cast(count(*) as bigint) as n_visits
from @results_database_schema.cab_s01_visit a
)
insert into @results_database_schema.cab_s10_person_cum
  (batch_number, persons_in_batch, person_days_in_batch, person_days_clear_batch, util_sum_batch, util_sq_batch, visits_in_batch)
select
  @batch_number,
  count(distinct a.person_id),
  sum(cast(datediff(day, b.observation_period_start_date, b.observation_period_end_date) + 1 as bigint)),
  sum(cast(case when datediff(day, b.observation_period_start_date, b.observation_period_end_date) + 1 - 180 > 0
    then datediff(day, b.observation_period_start_date, b.observation_period_end_date) + 1 - 180 else 0 end as bigint)),
  max(s2.util_sum),
  max(s2.util_sq),
  max(s3.n_visits)
from s1 a
  inner join @source_cdm_schema.observation_period b on a.person_id = b.person_id
  cross join s2
  cross join s3;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s10_person_cum' as table_name, 1 as step, @now_expr as step_datetime;




-- cab_s20_marginal_cum
-- One self-contained insert per source/src table. Each computes a per-person
-- event count in the inner query, then aggregates to one row per (concept_id, src):
--   n_obs_batch     = total events           = sum(n_person)
--   n_persons_batch = distinct persons        = count(*) over per-person rows
--   max_per_person  = max events for any one person (dispersion diagnostic)
-- No commingling across src: each insert reads exactly one staging table.
;

-- 10 condition
with s0 as (
select
  a.concept_id,
  a.src,
  a.person_id,
  count(*) as n_person,
  sum(a.concept_fm_flag) as n_person_fm,
  sum(case when a.visit_clear_period = 1 then 1 else 0 end) as n_person_clear,
  max(a.util_score) as util_pp,
  sum(case when a.concept_fm_flag = 1 and a.fm_early_flag = 0 then 1 else 0 end) as n_person_fm_inc
from @results_database_schema.cab_s02_condition a
group by a.concept_id, a.src, a.person_id
)
insert into @results_database_schema.cab_s20_marginal_cum
  (batch_number, concept_id, src, anchor_code, interval_code, n_obs_batch, n_persons_batch, n_obs_fm_batch, n_persons_fm_batch, max_per_person, n_obs_sq_batch, n_obs_clear_batch, n_util_sum_batch, n_persons_fm_incident_batch, person_days_at_risk)
select
  @batch_number,
  concept_id,
  src,
  1 as anchor_code,
  0 as interval_code,
  sum(n_person),
  count(*),
  sum(n_person_fm),
  sum(case when n_person_fm > 0 then 1 else 0 end),
  max(n_person),
  sum(cast(n_person as bigint) * cast(n_person as bigint)),
  sum(n_person_clear),
  sum(util_pp),
  sum(case when n_person_fm_inc > 0 then 1 else 0 end),
  null
from s0
group by concept_id, src;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s20_marginal_cum' as table_name, 1 as step, @now_expr as step_datetime;



-- 20 procedure
with s0 as (
select
  a.concept_id,
  a.src,
  a.person_id,
  count(*) as n_person,
  sum(a.concept_fm_flag) as n_person_fm,
  sum(case when a.visit_clear_period = 1 then 1 else 0 end) as n_person_clear,
  max(a.util_score) as util_pp,
  sum(case when a.concept_fm_flag = 1 and a.fm_early_flag = 0 then 1 else 0 end) as n_person_fm_inc
from @results_database_schema.cab_s03_procedure a
group by a.concept_id, a.src, a.person_id
)
insert into @results_database_schema.cab_s20_marginal_cum
  (batch_number, concept_id, src, anchor_code, interval_code, n_obs_batch, n_persons_batch, n_obs_fm_batch, n_persons_fm_batch, max_per_person, n_obs_sq_batch, n_obs_clear_batch, n_util_sum_batch, n_persons_fm_incident_batch, person_days_at_risk)
select
  @batch_number,
  concept_id,
  src,
  1 as anchor_code,
  0 as interval_code,
  sum(n_person),
  count(*),
  sum(n_person_fm),
  sum(case when n_person_fm > 0 then 1 else 0 end),
  max(n_person),
  sum(cast(n_person as bigint) * cast(n_person as bigint)),
  sum(n_person_clear),
  sum(util_pp),
  sum(case when n_person_fm_inc > 0 then 1 else 0 end),
  null
from s0
group by concept_id, src;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s20_marginal_cum' as table_name, 2 as step, @now_expr as step_datetime;



-- 30 device
with s0 as (
select
  a.concept_id,
  a.src,
  a.person_id,
  count(*) as n_person,
  sum(a.concept_fm_flag) as n_person_fm,
  sum(case when a.visit_clear_period = 1 then 1 else 0 end) as n_person_clear,
  max(a.util_score) as util_pp,
  sum(case when a.concept_fm_flag = 1 and a.fm_early_flag = 0 then 1 else 0 end) as n_person_fm_inc
from @results_database_schema.cab_s04_device a
group by a.concept_id, a.src, a.person_id
)
insert into @results_database_schema.cab_s20_marginal_cum
  (batch_number, concept_id, src, anchor_code, interval_code, n_obs_batch, n_persons_batch, n_obs_fm_batch, n_persons_fm_batch, max_per_person, n_obs_sq_batch, n_obs_clear_batch, n_util_sum_batch, n_persons_fm_incident_batch, person_days_at_risk)
select
  @batch_number,
  concept_id,
  src,
  1 as anchor_code,
  0 as interval_code,
  sum(n_person),
  count(*),
  sum(n_person_fm),
  sum(case when n_person_fm > 0 then 1 else 0 end),
  max(n_person),
  sum(cast(n_person as bigint) * cast(n_person as bigint)),
  sum(n_person_clear),
  sum(util_pp),
  sum(case when n_person_fm_inc > 0 then 1 else 0 end),
  null
from s0
group by concept_id, src;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s20_marginal_cum' as table_name, 3 as step, @now_expr as step_datetime;


-- 40 drug
with s0 as (
select
  a.concept_id,
  a.src,
  a.person_id,
  count(*) as n_person,
  sum(a.concept_fm_flag) as n_person_fm,
  sum(case when a.visit_clear_period = 1 then 1 else 0 end) as n_person_clear,
  max(a.util_score) as util_pp,
  sum(case when a.concept_fm_flag = 1 and a.fm_early_flag = 0 then 1 else 0 end) as n_person_fm_inc
from @results_database_schema.cab_s05_drug a
group by a.concept_id, a.src, a.person_id
)
insert into @results_database_schema.cab_s20_marginal_cum
  (batch_number, concept_id, src, anchor_code, interval_code, n_obs_batch, n_persons_batch, n_obs_fm_batch, n_persons_fm_batch, max_per_person, n_obs_sq_batch, n_obs_clear_batch, n_util_sum_batch, n_persons_fm_incident_batch, person_days_at_risk)
select
  @batch_number,
  concept_id,
  src,
  1 as anchor_code,
  0 as interval_code,
  sum(n_person),
  count(*),
  sum(n_person_fm),
  sum(case when n_person_fm > 0 then 1 else 0 end),
  max(n_person),
  sum(cast(n_person as bigint) * cast(n_person as bigint)),
  sum(n_person_clear),
  sum(util_pp),
  sum(case when n_person_fm_inc > 0 then 1 else 0 end),
  null
from s0
group by concept_id, src;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s20_marginal_cum' as table_name, 4 as step, @now_expr as step_datetime;



-- 50 observation
with s0 as (
select
  a.concept_id,
  a.src,
  a.person_id,
  count(*) as n_person,
  sum(a.concept_fm_flag) as n_person_fm,
  sum(case when a.visit_clear_period = 1 then 1 else 0 end) as n_person_clear,
  max(a.util_score) as util_pp,
  sum(case when a.concept_fm_flag = 1 and a.fm_early_flag = 0 then 1 else 0 end) as n_person_fm_inc
from @results_database_schema.cab_s06_observation a
group by a.concept_id, a.src, a.person_id
)
insert into @results_database_schema.cab_s20_marginal_cum
  (batch_number, concept_id, src, anchor_code, interval_code, n_obs_batch, n_persons_batch, n_obs_fm_batch, n_persons_fm_batch, max_per_person, n_obs_sq_batch, n_obs_clear_batch, n_util_sum_batch, n_persons_fm_incident_batch, person_days_at_risk)
select
  @batch_number,
  concept_id,
  src,
  1 as anchor_code,
  0 as interval_code,
  sum(n_person),
  count(*),
  sum(n_person_fm),
  sum(case when n_person_fm > 0 then 1 else 0 end),
  max(n_person),
  sum(cast(n_person as bigint) * cast(n_person as bigint)),
  sum(n_person_clear),
  sum(util_pp),
  sum(case when n_person_fm_inc > 0 then 1 else 0 end),
  null
from s0
group by concept_id, src;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s20_marginal_cum' as table_name, 5 as step, @now_expr as step_datetime;



-- 60 measurement
with s0 as (
select
  a.concept_id,
  a.src,
  a.person_id,
  count(*) as n_person,
  sum(a.concept_fm_flag) as n_person_fm,
  sum(case when a.visit_clear_period = 1 then 1 else 0 end) as n_person_clear,
  max(a.util_score) as util_pp,
  sum(case when a.concept_fm_flag = 1 and a.fm_early_flag = 0 then 1 else 0 end) as n_person_fm_inc
from @results_database_schema.cab_s07_measurement a
group by a.concept_id, a.src, a.person_id
)
insert into @results_database_schema.cab_s20_marginal_cum
  (batch_number, concept_id, src, anchor_code, interval_code, n_obs_batch, n_persons_batch, n_obs_fm_batch, n_persons_fm_batch, max_per_person, n_obs_sq_batch, n_obs_clear_batch, n_util_sum_batch, n_persons_fm_incident_batch, person_days_at_risk)
select
  @batch_number,
  concept_id,
  src,
  1 as anchor_code,
  0 as interval_code,
  sum(n_person),
  count(*),
  sum(n_person_fm),
  sum(case when n_person_fm > 0 then 1 else 0 end),
  max(n_person),
  sum(cast(n_person as bigint) * cast(n_person as bigint)),
  sum(n_person_clear),
  sum(util_pp),
  sum(case when n_person_fm_inc > 0 then 1 else 0 end),
  null
from s0
group by concept_id, src;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s20_marginal_cum' as table_name, 6 as step, @now_expr as step_datetime;



-- 51 observation_test
with s0 as (
select
  a.concept_id,
  a.src,
  a.person_id,
  count(*) as n_person,
  sum(a.concept_fm_flag) as n_person_fm,
  sum(case when a.visit_clear_period = 1 then 1 else 0 end) as n_person_clear,
  max(a.util_score) as util_pp,
  sum(case when a.concept_fm_flag = 1 and a.fm_early_flag = 0 then 1 else 0 end) as n_person_fm_inc
from @results_database_schema.cab_s08_observation_test a
group by a.concept_id, a.src, a.person_id
)
insert into @results_database_schema.cab_s20_marginal_cum
  (batch_number, concept_id, src, anchor_code, interval_code, n_obs_batch, n_persons_batch, n_obs_fm_batch, n_persons_fm_batch, max_per_person, n_obs_sq_batch, n_obs_clear_batch, n_util_sum_batch, n_persons_fm_incident_batch, person_days_at_risk)
select
  @batch_number,
  concept_id,
  src,
  1 as anchor_code,
  0 as interval_code,
  sum(n_person),
  count(*),
  sum(n_person_fm),
  sum(case when n_person_fm > 0 then 1 else 0 end),
  max(n_person),
  sum(cast(n_person as bigint) * cast(n_person as bigint)),
  sum(n_person_clear),
  sum(util_pp),
  sum(case when n_person_fm_inc > 0 then 1 else 0 end),
  null
from s0
group by concept_id, src;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s20_marginal_cum' as table_name, 7 as step, @now_expr as step_datetime;



-- 61 measurement_test
with s0 as (
select
  a.concept_id,
  a.src,
  a.person_id,
  count(*) as n_person,
  sum(a.concept_fm_flag) as n_person_fm,
  sum(case when a.visit_clear_period = 1 then 1 else 0 end) as n_person_clear,
  max(a.util_score) as util_pp,
  sum(case when a.concept_fm_flag = 1 and a.fm_early_flag = 0 then 1 else 0 end) as n_person_fm_inc
from @results_database_schema.cab_s09_measurement_test a
group by a.concept_id, a.src, a.person_id
)
insert into @results_database_schema.cab_s20_marginal_cum
  (batch_number, concept_id, src, anchor_code, interval_code, n_obs_batch, n_persons_batch, n_obs_fm_batch, n_persons_fm_batch, max_per_person, n_obs_sq_batch, n_obs_clear_batch, n_util_sum_batch, n_persons_fm_incident_batch, person_days_at_risk)
select
  @batch_number,
  concept_id,
  src,
  1 as anchor_code,
  0 as interval_code,
  sum(n_person),
  count(*),
  sum(n_person_fm),
  sum(case when n_person_fm > 0 then 1 else 0 end),
  max(n_person),
  sum(cast(n_person as bigint) * cast(n_person as bigint)),
  sum(n_person_clear),
  sum(util_pp),
  sum(case when n_person_fm_inc > 0 then 1 else 0 end),
  null
from s0
group by concept_id, src;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s20_marginal_cum' as table_name, 8 as step, @now_expr as step_datetime;



-- 21/22/23 trigger  (A-side marginal for the trigger-anchored pair types)
-- Same per-person collapse as the eight inserts above, restricted to
-- trigger records. Three identical copies, one per time band, because
-- finalize joins the A marginal on src_a and each band carries its own
-- src. The redundancy is what lets the finalize join stay unchanged.
--
-- Counted over the whole population, exactly like every other marginal.
-- Lift asks how often A and B would co-occur if they were unrelated; a
-- baseline restricted to persons who have the trigger would condition
-- that null on the exposure itself, raising the expected in step with
-- the association being measured and suppressing the signal the pair
-- types exist to find. Bands 21 and 22 together span delta -35..+35 --
-- the standard window -- so a trigger concept must yield the same lift
-- here as it does in the ordinary pair types, which requires the same
-- reference population.
with s0 as ( -- per-person collapse (same shape as the eight inserts above)
select
  a.concept_id,
  a.person_id,
  count(*) as n_person,
  sum(a.concept_fm_flag) as n_person_fm,
  sum(case when a.visit_clear_period = 1 then 1 else 0 end) as n_person_clear,
  max(a.util_score) as util_pp,
  sum(case when a.concept_fm_flag = 1 and a.fm_early_flag = 0 then 1 else 0 end) as n_person_fm_inc
from @results_database_schema.cab_s03_procedure a
where a.trigger_flag = 1
group by a.concept_id, a.person_id
), s1 as ( -- collapse to concept grain ONCE, before replicating across bands
select
  s0.concept_id,
  sum(s0.n_person) as n_obs,
  count(*) as n_pers,
  sum(s0.n_person_fm) as n_obs_fm,
  sum(case when s0.n_person_fm > 0 then 1 else 0 end) as n_pers_fm,
  max(s0.n_person) as max_pp,
  sum(cast(s0.n_person as bigint) * cast(s0.n_person as bigint)) as n_obs_sq,
  sum(s0.n_person_clear) as n_obs_clear,
  sum(s0.util_pp) as util_sum,
  sum(case when s0.n_person_fm_inc > 0 then 1 else 0 end) as n_pers_fm_inc
from s0
group by s0.concept_id
)
insert into @results_database_schema.cab_s20_marginal_cum
  (batch_number, concept_id, src, anchor_code, interval_code, n_obs_batch, n_persons_batch, n_obs_fm_batch, n_persons_fm_batch, max_per_person, n_obs_sq_batch, n_obs_clear_batch, n_util_sum_batch, n_persons_fm_incident_batch, person_days_at_risk)
select
  @batch_number,
  s1.concept_id,
  20,
  2 as anchor_code,
  0 as interval_code,
  s1.n_obs,
  s1.n_pers,
  s1.n_obs_fm,
  s1.n_pers_fm,
  s1.max_pp,
  s1.n_obs_sq,
  s1.n_obs_clear,
  s1.util_sum,
  s1.n_pers_fm_inc,
  null
from s1;






insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s20_marginal_cum' as table_name, 9 as step, @now_expr as step_datetime;

-- chronic-condition at-risk denominator, src 11, anchor 4. The src 11 blocks
-- ask what happens to B's rate after a chronic condition is first recorded,
-- which needs person-days rather than a window width. It cannot be derived as
-- n_persons * @window_days: a person diagnosed shortly before their record ends
-- is at risk for the early intervals only, and counting them in all ten would
-- overstate the denominator in the late bands and make the hazard curve falsely
-- decline.
with s0 as (
select
  a.concept_id,
  a.person_id,
  a.obs_end_bucket - a.start_bucket as days_remaining,
  a.start_bucket - a.intake_bucket as days_before
from @results_database_schema.cab_s02_condition a
where a.chronic_flag = 1
  and a.concept_fm_flag = 1
  and a.obs_end_bucket is not null
), s1 as ( -- three regimes, because the intervals are not all forward-looking.
-- 9 is the window BEFORE onset, so its at-risk time is bounded by how much
-- record precedes the first mention, not by how much follows it. 10 is the
-- onset day itself, exactly one day for everyone who has a first mention.
-- 11 through 20 are the forward bands, truncated by whatever record remains.
select
  a.concept_id,
  a.person_id,
  v.interval_code,
  case
    when v.interval_code = 9 and a.days_before >= @window_days then @window_days
    when v.interval_code = 9 then a.days_before
    when v.interval_code = 10 then 1
    when a.days_remaining >= (v.interval_code - 10) * @window_days then @window_days
    else a.days_remaining - (v.interval_code - 11) * @window_days
  end as days_at_risk
from s0 a
  cross join (values (9), (10), (11), (12), (13), (14), (15), (16), (17), (18), (19), (20)) as v(interval_code)
where (
    (v.interval_code = 9 and a.days_before > 0)
    or v.interval_code = 10
    or (v.interval_code >= 11 and a.days_remaining > (v.interval_code - 11) * @window_days)
  )
)
insert into @results_database_schema.cab_s20_marginal_cum
  (batch_number, concept_id, src, anchor_code, interval_code, n_obs_batch, n_persons_batch, n_obs_fm_batch, n_persons_fm_batch, max_per_person, n_obs_sq_batch, n_obs_clear_batch, n_util_sum_batch, n_persons_fm_incident_batch, person_days_at_risk)
select
  @batch_number,
  a.concept_id,
  11,
  4 as anchor_code,
  a.interval_code,
  cast(count(*) as bigint),
  cast(count(*) as bigint),
  cast(count(*) as bigint),
  cast(count(*) as bigint),
  1,
  cast(count(*) as bigint),
  0,
  null,
  0,
  sum(cast(a.days_at_risk as bigint))
from s1 a
group by
  a.concept_id,
  a.interval_code;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s20_marginal_cum' as table_name, 10 as step, @now_expr as step_datetime;





-- =========================================================
-- CO-OCCURRENCE COUNTS  (cab_s30_cum)
--
-- ONE TABLE, ONE ROW SHAPE. Every co-occurrence count in the pipeline lives
-- here, keyed by
--     pair_type, anchor_code, interval_code, concept_a, concept_b
-- Direction and same-day are ROWS (interval_code), not columns, which removes
-- the direction x first-mention cross product that made the previous version
-- 43 columns wide -- a_before_b_fmab and b_before_a_fma collapse into obs_fmab
-- and obs_fma within their interval row.
--
-- ANCHOR CODES -- which A events were eligible to start the clock:
--   1  ALL       every A event
--   2  TRIGGER   procedures with trigger_flag = 1 (rbcs_1 in 1-5)
--   4  CHRONIC   first mention of a chronic condition, src 11. The anchor is a
--                PERIOD rather than an event: from that first mention to the
--                end of observation.
--
-- INTERVAL CODES -- delta = B bucket minus A bucket:
--   1  delta = 0                          same day             1 day
--   2  delta +1 .. +@window_days          B after A           35 days
--   3  delta -@window_days .. -1          B before A          35 days
--   6  delta +@window_days+1 .. +2*@window_days  post-trigger 35 days
--   9  delta -@window_days .. -1            before chronic onset  35 days
--  10  delta = 0                            chronic onset day      1 day
--  11 .. 20  bands 1 .. 10 after chronic onset, @window_days each
--
-- WHICH ANCHOR EMITS WHICH INTERVALS:
--   anchor 1  intervals 1,2,3        all 26 standard pair types
--   anchor 2  intervals 1,2,3,6      the trigger family
--   anchor 4  intervals 9,10,11..20  1110 1120 1130 1140, chronic anchors only
--
-- THRESHOLD ON THE PAIR TOTAL, not per interval. @cab_min_ab_obs is applied
-- through a window over the aggregate, so all of a pair's interval rows survive
-- together or not at all. Applied per row it would delete the sparsest interval
-- on exactly the pairs where the relationship is strongest.
--
-- The 21 measure columns are identical in every row, so a reader learns one
-- shape rather than 43 column names. same_visit is retained alongside interval
-- 1 on purpose: same DAY and same ENCOUNTER are different questions -- a drug
-- ordered at the visit versus one filled at a retail pharmacy that afternoon.
-- =========================================================

-- 1010 anchor 1 -- all anchors, near intervals
with w as ( -- aggregate per interval, then threshold on the PAIR total: an
-- interval is smallest exactly when a relationship is strongest, so it must
-- never be filtered away on its own
select
  z.ca,
  z.cb,
  z.iv,
  sum(z.ev_obs) as obs,
  sum(z.ev_obs_fma) as obs_fma,
  sum(z.ev_obs_fmb) as obs_fmb,
  sum(z.ev_obs_fmab) as obs_fmab,
  sum(z.ev_obs_fmab_inc) as obs_fmab_inc,
  sum(z.ev_obs_clear) as obs_clear,
  sum(z.ev_obs_same_visit) as obs_same_visit,
  sum(z.ev_obs * z.ev_obs) as obs_sq,
  count(*) as pers,
  sum(z.hp_pers_fma) as pers_fma,
  sum(z.hp_pers_fmb) as pers_fmb,
  sum(z.hp_pers_fmab) as pers_fmab,
  sum(z.hp_pers_fmab_inc) as pers_fmab_inc,
  sum(z.hp_pers_same_visit) as pers_same_visit,
  sum(z.lag_s) as lag_sum,
  sum(z.lag_a) as lag_abs_sum,
  sum(z.lag_q) as lag_sq,
  sum(z.util_pp) as util_sum,
  sum(case when z.util_pp is null then 0 else 1 end) as util_n,
  min(z.fmi_a) as fm_intake_days_a,
  min(z.fmi_b) as fm_intake_days_b,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end as iv,
    sum(cast(1 as bigint)) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fma,
    sum(cast(case when b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmb,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmab,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end as bigint)) as ev_obs_fmab_inc,
    sum(cast(case when a.visit_clear_period = 1 and b.visit_clear_period = 1 then 1 else 0 end as bigint)) as ev_obs_clear,
    sum(cast(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end as bigint)) as ev_obs_same_visit,
    max(case when a.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fma,
    max(case when b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmb,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmab,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end) as hp_pers_fmab_inc,
    max(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end) as hp_pers_same_visit,
    sum(cast(b.start_bucket - a.start_bucket as bigint)) as lag_s,
    sum(abs(cast(b.start_bucket - a.start_bucket as bigint))) as lag_a,
    sum(cast(b.start_bucket - a.start_bucket as bigint) * cast(b.start_bucket - a.start_bucket as bigint)) as lag_q,
    max(coalesce(a.util_score, b.util_score)) as util_pp,
    min(case when a.concept_fm_flag = 1 then a.fm_days_from_intake else null end) as fmi_a,
    min(case when b.concept_fm_flag = 1 then b.fm_days_from_intake else null end) as fmi_b
  from @results_database_schema.cab_s02_condition a
    inner join @results_database_schema.cab_s02_condition b on a.person_id = b.person_id and b.start_bucket - a.start_bucket between -@window_days and @window_days
     and a.concept_id < b.concept_id
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end
) z
where z.iv is not null
group by z.ca, z.cb, z.iv
)
insert into @results_database_schema.cab_s30_cum
select
  @batch_number as batch_number,
  1010 as pair_type,
  1 as anchor_code,
  a.iv as interval_code,
  a.ca as concept_a,
  a.cb as concept_b,
  a.obs,
  a.obs_fma,
  a.obs_fmb,
  a.obs_fmab,
  a.obs_fmab_inc,
  a.obs_clear,
  a.obs_same_visit,
  a.obs_sq,
  a.pers,
  a.pers_fma,
  a.pers_fmb,
  a.pers_fmab,
  a.pers_fmab_inc,
  a.pers_same_visit,
  a.lag_sum,
  a.lag_abs_sum,
  a.lag_sq,
  a.util_sum,
  a.util_n,
  a.fm_intake_days_a,
  a.fm_intake_days_b
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s30_cum' as table_name, 1 as step, @now_expr as step_datetime;

-- 2020 anchor 1 -- all anchors, near intervals
with w as ( -- aggregate per interval, then threshold on the PAIR total: an
-- interval is smallest exactly when a relationship is strongest, so it must
-- never be filtered away on its own
select
  z.ca,
  z.cb,
  z.iv,
  sum(z.ev_obs) as obs,
  sum(z.ev_obs_fma) as obs_fma,
  sum(z.ev_obs_fmb) as obs_fmb,
  sum(z.ev_obs_fmab) as obs_fmab,
  sum(z.ev_obs_fmab_inc) as obs_fmab_inc,
  sum(z.ev_obs_clear) as obs_clear,
  sum(z.ev_obs_same_visit) as obs_same_visit,
  sum(z.ev_obs * z.ev_obs) as obs_sq,
  count(*) as pers,
  sum(z.hp_pers_fma) as pers_fma,
  sum(z.hp_pers_fmb) as pers_fmb,
  sum(z.hp_pers_fmab) as pers_fmab,
  sum(z.hp_pers_fmab_inc) as pers_fmab_inc,
  sum(z.hp_pers_same_visit) as pers_same_visit,
  sum(z.lag_s) as lag_sum,
  sum(z.lag_a) as lag_abs_sum,
  sum(z.lag_q) as lag_sq,
  sum(z.util_pp) as util_sum,
  sum(case when z.util_pp is null then 0 else 1 end) as util_n,
  min(z.fmi_a) as fm_intake_days_a,
  min(z.fmi_b) as fm_intake_days_b,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end as iv,
    sum(cast(1 as bigint)) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fma,
    sum(cast(case when b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmb,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmab,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end as bigint)) as ev_obs_fmab_inc,
    sum(cast(case when a.visit_clear_period = 1 and b.visit_clear_period = 1 then 1 else 0 end as bigint)) as ev_obs_clear,
    sum(cast(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end as bigint)) as ev_obs_same_visit,
    max(case when a.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fma,
    max(case when b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmb,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmab,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end) as hp_pers_fmab_inc,
    max(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end) as hp_pers_same_visit,
    sum(cast(b.start_bucket - a.start_bucket as bigint)) as lag_s,
    sum(abs(cast(b.start_bucket - a.start_bucket as bigint))) as lag_a,
    sum(cast(b.start_bucket - a.start_bucket as bigint) * cast(b.start_bucket - a.start_bucket as bigint)) as lag_q,
    max(coalesce(a.util_score, b.util_score)) as util_pp,
    min(case when a.concept_fm_flag = 1 then a.fm_days_from_intake else null end) as fmi_a,
    min(case when b.concept_fm_flag = 1 then b.fm_days_from_intake else null end) as fmi_b
  from @results_database_schema.cab_s03_procedure a
    inner join @results_database_schema.cab_s03_procedure b on a.person_id = b.person_id and b.start_bucket - a.start_bucket between -@window_days and @window_days
     and a.concept_id < b.concept_id
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end
) z
where z.iv is not null
group by z.ca, z.cb, z.iv
)
insert into @results_database_schema.cab_s30_cum
select
  @batch_number as batch_number,
  2020 as pair_type,
  1 as anchor_code,
  a.iv as interval_code,
  a.ca as concept_a,
  a.cb as concept_b,
  a.obs,
  a.obs_fma,
  a.obs_fmb,
  a.obs_fmab,
  a.obs_fmab_inc,
  a.obs_clear,
  a.obs_same_visit,
  a.obs_sq,
  a.pers,
  a.pers_fma,
  a.pers_fmb,
  a.pers_fmab,
  a.pers_fmab_inc,
  a.pers_same_visit,
  a.lag_sum,
  a.lag_abs_sum,
  a.lag_sq,
  a.util_sum,
  a.util_n,
  a.fm_intake_days_a,
  a.fm_intake_days_b
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s30_cum' as table_name, 2 as step, @now_expr as step_datetime;

-- 3030 anchor 1 -- all anchors, near intervals
with w as ( -- aggregate per interval, then threshold on the PAIR total: an
-- interval is smallest exactly when a relationship is strongest, so it must
-- never be filtered away on its own
select
  z.ca,
  z.cb,
  z.iv,
  sum(z.ev_obs) as obs,
  sum(z.ev_obs_fma) as obs_fma,
  sum(z.ev_obs_fmb) as obs_fmb,
  sum(z.ev_obs_fmab) as obs_fmab,
  sum(z.ev_obs_fmab_inc) as obs_fmab_inc,
  sum(z.ev_obs_clear) as obs_clear,
  sum(z.ev_obs_same_visit) as obs_same_visit,
  sum(z.ev_obs * z.ev_obs) as obs_sq,
  count(*) as pers,
  sum(z.hp_pers_fma) as pers_fma,
  sum(z.hp_pers_fmb) as pers_fmb,
  sum(z.hp_pers_fmab) as pers_fmab,
  sum(z.hp_pers_fmab_inc) as pers_fmab_inc,
  sum(z.hp_pers_same_visit) as pers_same_visit,
  sum(z.lag_s) as lag_sum,
  sum(z.lag_a) as lag_abs_sum,
  sum(z.lag_q) as lag_sq,
  sum(z.util_pp) as util_sum,
  sum(case when z.util_pp is null then 0 else 1 end) as util_n,
  min(z.fmi_a) as fm_intake_days_a,
  min(z.fmi_b) as fm_intake_days_b,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end as iv,
    sum(cast(1 as bigint)) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fma,
    sum(cast(case when b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmb,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmab,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end as bigint)) as ev_obs_fmab_inc,
    sum(cast(case when a.visit_clear_period = 1 and b.visit_clear_period = 1 then 1 else 0 end as bigint)) as ev_obs_clear,
    sum(cast(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end as bigint)) as ev_obs_same_visit,
    max(case when a.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fma,
    max(case when b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmb,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmab,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end) as hp_pers_fmab_inc,
    max(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end) as hp_pers_same_visit,
    sum(cast(b.start_bucket - a.start_bucket as bigint)) as lag_s,
    sum(abs(cast(b.start_bucket - a.start_bucket as bigint))) as lag_a,
    sum(cast(b.start_bucket - a.start_bucket as bigint) * cast(b.start_bucket - a.start_bucket as bigint)) as lag_q,
    max(coalesce(a.util_score, b.util_score)) as util_pp,
    min(case when a.concept_fm_flag = 1 then a.fm_days_from_intake else null end) as fmi_a,
    min(case when b.concept_fm_flag = 1 then b.fm_days_from_intake else null end) as fmi_b
  from @results_database_schema.cab_s04_device a
    inner join @results_database_schema.cab_s04_device b on a.person_id = b.person_id and b.start_bucket - a.start_bucket between -@window_days and @window_days
     and a.concept_id < b.concept_id
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end
) z
where z.iv is not null
group by z.ca, z.cb, z.iv
)
insert into @results_database_schema.cab_s30_cum
select
  @batch_number as batch_number,
  3030 as pair_type,
  1 as anchor_code,
  a.iv as interval_code,
  a.ca as concept_a,
  a.cb as concept_b,
  a.obs,
  a.obs_fma,
  a.obs_fmb,
  a.obs_fmab,
  a.obs_fmab_inc,
  a.obs_clear,
  a.obs_same_visit,
  a.obs_sq,
  a.pers,
  a.pers_fma,
  a.pers_fmb,
  a.pers_fmab,
  a.pers_fmab_inc,
  a.pers_same_visit,
  a.lag_sum,
  a.lag_abs_sum,
  a.lag_sq,
  a.util_sum,
  a.util_n,
  a.fm_intake_days_a,
  a.fm_intake_days_b
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s30_cum' as table_name, 3 as step, @now_expr as step_datetime;

-- 4040 anchor 1 -- all anchors, near intervals
with w as ( -- aggregate per interval, then threshold on the PAIR total: an
-- interval is smallest exactly when a relationship is strongest, so it must
-- never be filtered away on its own
select
  z.ca,
  z.cb,
  z.iv,
  sum(z.ev_obs) as obs,
  sum(z.ev_obs_fma) as obs_fma,
  sum(z.ev_obs_fmb) as obs_fmb,
  sum(z.ev_obs_fmab) as obs_fmab,
  sum(z.ev_obs_fmab_inc) as obs_fmab_inc,
  sum(z.ev_obs_clear) as obs_clear,
  sum(z.ev_obs_same_visit) as obs_same_visit,
  sum(z.ev_obs * z.ev_obs) as obs_sq,
  count(*) as pers,
  sum(z.hp_pers_fma) as pers_fma,
  sum(z.hp_pers_fmb) as pers_fmb,
  sum(z.hp_pers_fmab) as pers_fmab,
  sum(z.hp_pers_fmab_inc) as pers_fmab_inc,
  sum(z.hp_pers_same_visit) as pers_same_visit,
  sum(z.lag_s) as lag_sum,
  sum(z.lag_a) as lag_abs_sum,
  sum(z.lag_q) as lag_sq,
  sum(z.util_pp) as util_sum,
  sum(case when z.util_pp is null then 0 else 1 end) as util_n,
  min(z.fmi_a) as fm_intake_days_a,
  min(z.fmi_b) as fm_intake_days_b,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end as iv,
    sum(cast(1 as bigint)) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fma,
    sum(cast(case when b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmb,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmab,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end as bigint)) as ev_obs_fmab_inc,
    sum(cast(case when a.visit_clear_period = 1 and b.visit_clear_period = 1 then 1 else 0 end as bigint)) as ev_obs_clear,
    sum(cast(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end as bigint)) as ev_obs_same_visit,
    max(case when a.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fma,
    max(case when b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmb,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmab,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end) as hp_pers_fmab_inc,
    max(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end) as hp_pers_same_visit,
    sum(cast(b.start_bucket - a.start_bucket as bigint)) as lag_s,
    sum(abs(cast(b.start_bucket - a.start_bucket as bigint))) as lag_a,
    sum(cast(b.start_bucket - a.start_bucket as bigint) * cast(b.start_bucket - a.start_bucket as bigint)) as lag_q,
    max(coalesce(a.util_score, b.util_score)) as util_pp,
    min(case when a.concept_fm_flag = 1 then a.fm_days_from_intake else null end) as fmi_a,
    min(case when b.concept_fm_flag = 1 then b.fm_days_from_intake else null end) as fmi_b
  from @results_database_schema.cab_s05_drug a
    inner join @results_database_schema.cab_s05_drug b on a.person_id = b.person_id and b.start_bucket - a.start_bucket between -@window_days and @window_days
     and a.concept_id < b.concept_id
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end
) z
where z.iv is not null
group by z.ca, z.cb, z.iv
)
insert into @results_database_schema.cab_s30_cum
select
  @batch_number as batch_number,
  4040 as pair_type,
  1 as anchor_code,
  a.iv as interval_code,
  a.ca as concept_a,
  a.cb as concept_b,
  a.obs,
  a.obs_fma,
  a.obs_fmb,
  a.obs_fmab,
  a.obs_fmab_inc,
  a.obs_clear,
  a.obs_same_visit,
  a.obs_sq,
  a.pers,
  a.pers_fma,
  a.pers_fmb,
  a.pers_fmab,
  a.pers_fmab_inc,
  a.pers_same_visit,
  a.lag_sum,
  a.lag_abs_sum,
  a.lag_sq,
  a.util_sum,
  a.util_n,
  a.fm_intake_days_a,
  a.fm_intake_days_b
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s30_cum' as table_name, 4 as step, @now_expr as step_datetime;

-- 1020 anchor 1 -- all anchors, near intervals
with w as ( -- aggregate per interval, then threshold on the PAIR total: an
-- interval is smallest exactly when a relationship is strongest, so it must
-- never be filtered away on its own
select
  z.ca,
  z.cb,
  z.iv,
  sum(z.ev_obs) as obs,
  sum(z.ev_obs_fma) as obs_fma,
  sum(z.ev_obs_fmb) as obs_fmb,
  sum(z.ev_obs_fmab) as obs_fmab,
  sum(z.ev_obs_fmab_inc) as obs_fmab_inc,
  sum(z.ev_obs_clear) as obs_clear,
  sum(z.ev_obs_same_visit) as obs_same_visit,
  sum(z.ev_obs * z.ev_obs) as obs_sq,
  count(*) as pers,
  sum(z.hp_pers_fma) as pers_fma,
  sum(z.hp_pers_fmb) as pers_fmb,
  sum(z.hp_pers_fmab) as pers_fmab,
  sum(z.hp_pers_fmab_inc) as pers_fmab_inc,
  sum(z.hp_pers_same_visit) as pers_same_visit,
  sum(z.lag_s) as lag_sum,
  sum(z.lag_a) as lag_abs_sum,
  sum(z.lag_q) as lag_sq,
  sum(z.util_pp) as util_sum,
  sum(case when z.util_pp is null then 0 else 1 end) as util_n,
  min(z.fmi_a) as fm_intake_days_a,
  min(z.fmi_b) as fm_intake_days_b,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end as iv,
    sum(cast(1 as bigint)) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fma,
    sum(cast(case when b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmb,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmab,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end as bigint)) as ev_obs_fmab_inc,
    sum(cast(case when a.visit_clear_period = 1 and b.visit_clear_period = 1 then 1 else 0 end as bigint)) as ev_obs_clear,
    sum(cast(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end as bigint)) as ev_obs_same_visit,
    max(case when a.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fma,
    max(case when b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmb,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmab,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end) as hp_pers_fmab_inc,
    max(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end) as hp_pers_same_visit,
    sum(cast(b.start_bucket - a.start_bucket as bigint)) as lag_s,
    sum(abs(cast(b.start_bucket - a.start_bucket as bigint))) as lag_a,
    sum(cast(b.start_bucket - a.start_bucket as bigint) * cast(b.start_bucket - a.start_bucket as bigint)) as lag_q,
    max(coalesce(a.util_score, b.util_score)) as util_pp,
    min(case when a.concept_fm_flag = 1 then a.fm_days_from_intake else null end) as fmi_a,
    min(case when b.concept_fm_flag = 1 then b.fm_days_from_intake else null end) as fmi_b
  from @results_database_schema.cab_s02_condition a
    inner join @results_database_schema.cab_s03_procedure b on a.person_id = b.person_id and b.start_bucket - a.start_bucket between -@window_days and @window_days
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end
) z
where z.iv is not null
group by z.ca, z.cb, z.iv
)
insert into @results_database_schema.cab_s30_cum
select
  @batch_number as batch_number,
  1020 as pair_type,
  1 as anchor_code,
  a.iv as interval_code,
  a.ca as concept_a,
  a.cb as concept_b,
  a.obs,
  a.obs_fma,
  a.obs_fmb,
  a.obs_fmab,
  a.obs_fmab_inc,
  a.obs_clear,
  a.obs_same_visit,
  a.obs_sq,
  a.pers,
  a.pers_fma,
  a.pers_fmb,
  a.pers_fmab,
  a.pers_fmab_inc,
  a.pers_same_visit,
  a.lag_sum,
  a.lag_abs_sum,
  a.lag_sq,
  a.util_sum,
  a.util_n,
  a.fm_intake_days_a,
  a.fm_intake_days_b
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s30_cum' as table_name, 5 as step, @now_expr as step_datetime;

-- 1030 anchor 1 -- all anchors, near intervals
with w as ( -- aggregate per interval, then threshold on the PAIR total: an
-- interval is smallest exactly when a relationship is strongest, so it must
-- never be filtered away on its own
select
  z.ca,
  z.cb,
  z.iv,
  sum(z.ev_obs) as obs,
  sum(z.ev_obs_fma) as obs_fma,
  sum(z.ev_obs_fmb) as obs_fmb,
  sum(z.ev_obs_fmab) as obs_fmab,
  sum(z.ev_obs_fmab_inc) as obs_fmab_inc,
  sum(z.ev_obs_clear) as obs_clear,
  sum(z.ev_obs_same_visit) as obs_same_visit,
  sum(z.ev_obs * z.ev_obs) as obs_sq,
  count(*) as pers,
  sum(z.hp_pers_fma) as pers_fma,
  sum(z.hp_pers_fmb) as pers_fmb,
  sum(z.hp_pers_fmab) as pers_fmab,
  sum(z.hp_pers_fmab_inc) as pers_fmab_inc,
  sum(z.hp_pers_same_visit) as pers_same_visit,
  sum(z.lag_s) as lag_sum,
  sum(z.lag_a) as lag_abs_sum,
  sum(z.lag_q) as lag_sq,
  sum(z.util_pp) as util_sum,
  sum(case when z.util_pp is null then 0 else 1 end) as util_n,
  min(z.fmi_a) as fm_intake_days_a,
  min(z.fmi_b) as fm_intake_days_b,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end as iv,
    sum(cast(1 as bigint)) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fma,
    sum(cast(case when b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmb,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmab,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end as bigint)) as ev_obs_fmab_inc,
    sum(cast(case when a.visit_clear_period = 1 and b.visit_clear_period = 1 then 1 else 0 end as bigint)) as ev_obs_clear,
    sum(cast(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end as bigint)) as ev_obs_same_visit,
    max(case when a.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fma,
    max(case when b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmb,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmab,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end) as hp_pers_fmab_inc,
    max(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end) as hp_pers_same_visit,
    sum(cast(b.start_bucket - a.start_bucket as bigint)) as lag_s,
    sum(abs(cast(b.start_bucket - a.start_bucket as bigint))) as lag_a,
    sum(cast(b.start_bucket - a.start_bucket as bigint) * cast(b.start_bucket - a.start_bucket as bigint)) as lag_q,
    max(coalesce(a.util_score, b.util_score)) as util_pp,
    min(case when a.concept_fm_flag = 1 then a.fm_days_from_intake else null end) as fmi_a,
    min(case when b.concept_fm_flag = 1 then b.fm_days_from_intake else null end) as fmi_b
  from @results_database_schema.cab_s02_condition a
    inner join @results_database_schema.cab_s04_device b on a.person_id = b.person_id and b.start_bucket - a.start_bucket between -@window_days and @window_days
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end
) z
where z.iv is not null
group by z.ca, z.cb, z.iv
)
insert into @results_database_schema.cab_s30_cum
select
  @batch_number as batch_number,
  1030 as pair_type,
  1 as anchor_code,
  a.iv as interval_code,
  a.ca as concept_a,
  a.cb as concept_b,
  a.obs,
  a.obs_fma,
  a.obs_fmb,
  a.obs_fmab,
  a.obs_fmab_inc,
  a.obs_clear,
  a.obs_same_visit,
  a.obs_sq,
  a.pers,
  a.pers_fma,
  a.pers_fmb,
  a.pers_fmab,
  a.pers_fmab_inc,
  a.pers_same_visit,
  a.lag_sum,
  a.lag_abs_sum,
  a.lag_sq,
  a.util_sum,
  a.util_n,
  a.fm_intake_days_a,
  a.fm_intake_days_b
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s30_cum' as table_name, 6 as step, @now_expr as step_datetime;

-- 1040 anchor 1 -- all anchors, near intervals
with w as ( -- aggregate per interval, then threshold on the PAIR total: an
-- interval is smallest exactly when a relationship is strongest, so it must
-- never be filtered away on its own
select
  z.ca,
  z.cb,
  z.iv,
  sum(z.ev_obs) as obs,
  sum(z.ev_obs_fma) as obs_fma,
  sum(z.ev_obs_fmb) as obs_fmb,
  sum(z.ev_obs_fmab) as obs_fmab,
  sum(z.ev_obs_fmab_inc) as obs_fmab_inc,
  sum(z.ev_obs_clear) as obs_clear,
  sum(z.ev_obs_same_visit) as obs_same_visit,
  sum(z.ev_obs * z.ev_obs) as obs_sq,
  count(*) as pers,
  sum(z.hp_pers_fma) as pers_fma,
  sum(z.hp_pers_fmb) as pers_fmb,
  sum(z.hp_pers_fmab) as pers_fmab,
  sum(z.hp_pers_fmab_inc) as pers_fmab_inc,
  sum(z.hp_pers_same_visit) as pers_same_visit,
  sum(z.lag_s) as lag_sum,
  sum(z.lag_a) as lag_abs_sum,
  sum(z.lag_q) as lag_sq,
  sum(z.util_pp) as util_sum,
  sum(case when z.util_pp is null then 0 else 1 end) as util_n,
  min(z.fmi_a) as fm_intake_days_a,
  min(z.fmi_b) as fm_intake_days_b,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end as iv,
    sum(cast(1 as bigint)) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fma,
    sum(cast(case when b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmb,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmab,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end as bigint)) as ev_obs_fmab_inc,
    sum(cast(case when a.visit_clear_period = 1 and b.visit_clear_period = 1 then 1 else 0 end as bigint)) as ev_obs_clear,
    sum(cast(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end as bigint)) as ev_obs_same_visit,
    max(case when a.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fma,
    max(case when b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmb,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmab,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end) as hp_pers_fmab_inc,
    max(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end) as hp_pers_same_visit,
    sum(cast(b.start_bucket - a.start_bucket as bigint)) as lag_s,
    sum(abs(cast(b.start_bucket - a.start_bucket as bigint))) as lag_a,
    sum(cast(b.start_bucket - a.start_bucket as bigint) * cast(b.start_bucket - a.start_bucket as bigint)) as lag_q,
    max(coalesce(a.util_score, b.util_score)) as util_pp,
    min(case when a.concept_fm_flag = 1 then a.fm_days_from_intake else null end) as fmi_a,
    min(case when b.concept_fm_flag = 1 then b.fm_days_from_intake else null end) as fmi_b
  from @results_database_schema.cab_s02_condition a
    inner join @results_database_schema.cab_s05_drug b on a.person_id = b.person_id and b.start_bucket - a.start_bucket between -@window_days and @window_days
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end
) z
where z.iv is not null
group by z.ca, z.cb, z.iv
)
insert into @results_database_schema.cab_s30_cum
select
  @batch_number as batch_number,
  1040 as pair_type,
  1 as anchor_code,
  a.iv as interval_code,
  a.ca as concept_a,
  a.cb as concept_b,
  a.obs,
  a.obs_fma,
  a.obs_fmb,
  a.obs_fmab,
  a.obs_fmab_inc,
  a.obs_clear,
  a.obs_same_visit,
  a.obs_sq,
  a.pers,
  a.pers_fma,
  a.pers_fmb,
  a.pers_fmab,
  a.pers_fmab_inc,
  a.pers_same_visit,
  a.lag_sum,
  a.lag_abs_sum,
  a.lag_sq,
  a.util_sum,
  a.util_n,
  a.fm_intake_days_a,
  a.fm_intake_days_b
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s30_cum' as table_name, 7 as step, @now_expr as step_datetime;

-- 2030 anchor 1 -- all anchors, near intervals
with w as ( -- aggregate per interval, then threshold on the PAIR total: an
-- interval is smallest exactly when a relationship is strongest, so it must
-- never be filtered away on its own
select
  z.ca,
  z.cb,
  z.iv,
  sum(z.ev_obs) as obs,
  sum(z.ev_obs_fma) as obs_fma,
  sum(z.ev_obs_fmb) as obs_fmb,
  sum(z.ev_obs_fmab) as obs_fmab,
  sum(z.ev_obs_fmab_inc) as obs_fmab_inc,
  sum(z.ev_obs_clear) as obs_clear,
  sum(z.ev_obs_same_visit) as obs_same_visit,
  sum(z.ev_obs * z.ev_obs) as obs_sq,
  count(*) as pers,
  sum(z.hp_pers_fma) as pers_fma,
  sum(z.hp_pers_fmb) as pers_fmb,
  sum(z.hp_pers_fmab) as pers_fmab,
  sum(z.hp_pers_fmab_inc) as pers_fmab_inc,
  sum(z.hp_pers_same_visit) as pers_same_visit,
  sum(z.lag_s) as lag_sum,
  sum(z.lag_a) as lag_abs_sum,
  sum(z.lag_q) as lag_sq,
  sum(z.util_pp) as util_sum,
  sum(case when z.util_pp is null then 0 else 1 end) as util_n,
  min(z.fmi_a) as fm_intake_days_a,
  min(z.fmi_b) as fm_intake_days_b,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end as iv,
    sum(cast(1 as bigint)) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fma,
    sum(cast(case when b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmb,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmab,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end as bigint)) as ev_obs_fmab_inc,
    sum(cast(case when a.visit_clear_period = 1 and b.visit_clear_period = 1 then 1 else 0 end as bigint)) as ev_obs_clear,
    sum(cast(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end as bigint)) as ev_obs_same_visit,
    max(case when a.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fma,
    max(case when b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmb,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmab,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end) as hp_pers_fmab_inc,
    max(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end) as hp_pers_same_visit,
    sum(cast(b.start_bucket - a.start_bucket as bigint)) as lag_s,
    sum(abs(cast(b.start_bucket - a.start_bucket as bigint))) as lag_a,
    sum(cast(b.start_bucket - a.start_bucket as bigint) * cast(b.start_bucket - a.start_bucket as bigint)) as lag_q,
    max(coalesce(a.util_score, b.util_score)) as util_pp,
    min(case when a.concept_fm_flag = 1 then a.fm_days_from_intake else null end) as fmi_a,
    min(case when b.concept_fm_flag = 1 then b.fm_days_from_intake else null end) as fmi_b
  from @results_database_schema.cab_s03_procedure a
    inner join @results_database_schema.cab_s04_device b on a.person_id = b.person_id and b.start_bucket - a.start_bucket between -@window_days and @window_days
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end
) z
where z.iv is not null
group by z.ca, z.cb, z.iv
)
insert into @results_database_schema.cab_s30_cum
select
  @batch_number as batch_number,
  2030 as pair_type,
  1 as anchor_code,
  a.iv as interval_code,
  a.ca as concept_a,
  a.cb as concept_b,
  a.obs,
  a.obs_fma,
  a.obs_fmb,
  a.obs_fmab,
  a.obs_fmab_inc,
  a.obs_clear,
  a.obs_same_visit,
  a.obs_sq,
  a.pers,
  a.pers_fma,
  a.pers_fmb,
  a.pers_fmab,
  a.pers_fmab_inc,
  a.pers_same_visit,
  a.lag_sum,
  a.lag_abs_sum,
  a.lag_sq,
  a.util_sum,
  a.util_n,
  a.fm_intake_days_a,
  a.fm_intake_days_b
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s30_cum' as table_name, 8 as step, @now_expr as step_datetime;

-- 2040 anchor 1 -- all anchors, near intervals
with w as ( -- aggregate per interval, then threshold on the PAIR total: an
-- interval is smallest exactly when a relationship is strongest, so it must
-- never be filtered away on its own
select
  z.ca,
  z.cb,
  z.iv,
  sum(z.ev_obs) as obs,
  sum(z.ev_obs_fma) as obs_fma,
  sum(z.ev_obs_fmb) as obs_fmb,
  sum(z.ev_obs_fmab) as obs_fmab,
  sum(z.ev_obs_fmab_inc) as obs_fmab_inc,
  sum(z.ev_obs_clear) as obs_clear,
  sum(z.ev_obs_same_visit) as obs_same_visit,
  sum(z.ev_obs * z.ev_obs) as obs_sq,
  count(*) as pers,
  sum(z.hp_pers_fma) as pers_fma,
  sum(z.hp_pers_fmb) as pers_fmb,
  sum(z.hp_pers_fmab) as pers_fmab,
  sum(z.hp_pers_fmab_inc) as pers_fmab_inc,
  sum(z.hp_pers_same_visit) as pers_same_visit,
  sum(z.lag_s) as lag_sum,
  sum(z.lag_a) as lag_abs_sum,
  sum(z.lag_q) as lag_sq,
  sum(z.util_pp) as util_sum,
  sum(case when z.util_pp is null then 0 else 1 end) as util_n,
  min(z.fmi_a) as fm_intake_days_a,
  min(z.fmi_b) as fm_intake_days_b,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end as iv,
    sum(cast(1 as bigint)) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fma,
    sum(cast(case when b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmb,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmab,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end as bigint)) as ev_obs_fmab_inc,
    sum(cast(case when a.visit_clear_period = 1 and b.visit_clear_period = 1 then 1 else 0 end as bigint)) as ev_obs_clear,
    sum(cast(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end as bigint)) as ev_obs_same_visit,
    max(case when a.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fma,
    max(case when b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmb,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmab,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end) as hp_pers_fmab_inc,
    max(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end) as hp_pers_same_visit,
    sum(cast(b.start_bucket - a.start_bucket as bigint)) as lag_s,
    sum(abs(cast(b.start_bucket - a.start_bucket as bigint))) as lag_a,
    sum(cast(b.start_bucket - a.start_bucket as bigint) * cast(b.start_bucket - a.start_bucket as bigint)) as lag_q,
    max(coalesce(a.util_score, b.util_score)) as util_pp,
    min(case when a.concept_fm_flag = 1 then a.fm_days_from_intake else null end) as fmi_a,
    min(case when b.concept_fm_flag = 1 then b.fm_days_from_intake else null end) as fmi_b
  from @results_database_schema.cab_s03_procedure a
    inner join @results_database_schema.cab_s05_drug b on a.person_id = b.person_id and b.start_bucket - a.start_bucket between -@window_days and @window_days
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end
) z
where z.iv is not null
group by z.ca, z.cb, z.iv
)
insert into @results_database_schema.cab_s30_cum
select
  @batch_number as batch_number,
  2040 as pair_type,
  1 as anchor_code,
  a.iv as interval_code,
  a.ca as concept_a,
  a.cb as concept_b,
  a.obs,
  a.obs_fma,
  a.obs_fmb,
  a.obs_fmab,
  a.obs_fmab_inc,
  a.obs_clear,
  a.obs_same_visit,
  a.obs_sq,
  a.pers,
  a.pers_fma,
  a.pers_fmb,
  a.pers_fmab,
  a.pers_fmab_inc,
  a.pers_same_visit,
  a.lag_sum,
  a.lag_abs_sum,
  a.lag_sq,
  a.util_sum,
  a.util_n,
  a.fm_intake_days_a,
  a.fm_intake_days_b
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s30_cum' as table_name, 9 as step, @now_expr as step_datetime;

-- 3040 anchor 1 -- all anchors, near intervals
with w as ( -- aggregate per interval, then threshold on the PAIR total: an
-- interval is smallest exactly when a relationship is strongest, so it must
-- never be filtered away on its own
select
  z.ca,
  z.cb,
  z.iv,
  sum(z.ev_obs) as obs,
  sum(z.ev_obs_fma) as obs_fma,
  sum(z.ev_obs_fmb) as obs_fmb,
  sum(z.ev_obs_fmab) as obs_fmab,
  sum(z.ev_obs_fmab_inc) as obs_fmab_inc,
  sum(z.ev_obs_clear) as obs_clear,
  sum(z.ev_obs_same_visit) as obs_same_visit,
  sum(z.ev_obs * z.ev_obs) as obs_sq,
  count(*) as pers,
  sum(z.hp_pers_fma) as pers_fma,
  sum(z.hp_pers_fmb) as pers_fmb,
  sum(z.hp_pers_fmab) as pers_fmab,
  sum(z.hp_pers_fmab_inc) as pers_fmab_inc,
  sum(z.hp_pers_same_visit) as pers_same_visit,
  sum(z.lag_s) as lag_sum,
  sum(z.lag_a) as lag_abs_sum,
  sum(z.lag_q) as lag_sq,
  sum(z.util_pp) as util_sum,
  sum(case when z.util_pp is null then 0 else 1 end) as util_n,
  min(z.fmi_a) as fm_intake_days_a,
  min(z.fmi_b) as fm_intake_days_b,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end as iv,
    sum(cast(1 as bigint)) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fma,
    sum(cast(case when b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmb,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmab,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end as bigint)) as ev_obs_fmab_inc,
    sum(cast(case when a.visit_clear_period = 1 and b.visit_clear_period = 1 then 1 else 0 end as bigint)) as ev_obs_clear,
    sum(cast(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end as bigint)) as ev_obs_same_visit,
    max(case when a.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fma,
    max(case when b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmb,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmab,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end) as hp_pers_fmab_inc,
    max(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end) as hp_pers_same_visit,
    sum(cast(b.start_bucket - a.start_bucket as bigint)) as lag_s,
    sum(abs(cast(b.start_bucket - a.start_bucket as bigint))) as lag_a,
    sum(cast(b.start_bucket - a.start_bucket as bigint) * cast(b.start_bucket - a.start_bucket as bigint)) as lag_q,
    max(coalesce(a.util_score, b.util_score)) as util_pp,
    min(case when a.concept_fm_flag = 1 then a.fm_days_from_intake else null end) as fmi_a,
    min(case when b.concept_fm_flag = 1 then b.fm_days_from_intake else null end) as fmi_b
  from @results_database_schema.cab_s04_device a
    inner join @results_database_schema.cab_s05_drug b on a.person_id = b.person_id and b.start_bucket - a.start_bucket between -@window_days and @window_days
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end
) z
where z.iv is not null
group by z.ca, z.cb, z.iv
)
insert into @results_database_schema.cab_s30_cum
select
  @batch_number as batch_number,
  3040 as pair_type,
  1 as anchor_code,
  a.iv as interval_code,
  a.ca as concept_a,
  a.cb as concept_b,
  a.obs,
  a.obs_fma,
  a.obs_fmb,
  a.obs_fmab,
  a.obs_fmab_inc,
  a.obs_clear,
  a.obs_same_visit,
  a.obs_sq,
  a.pers,
  a.pers_fma,
  a.pers_fmb,
  a.pers_fmab,
  a.pers_fmab_inc,
  a.pers_same_visit,
  a.lag_sum,
  a.lag_abs_sum,
  a.lag_sq,
  a.util_sum,
  a.util_n,
  a.fm_intake_days_a,
  a.fm_intake_days_b
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s30_cum' as table_name, 10 as step, @now_expr as step_datetime;

-- 1050 anchor 1 -- all anchors, near intervals
with w as ( -- aggregate per interval, then threshold on the PAIR total: an
-- interval is smallest exactly when a relationship is strongest, so it must
-- never be filtered away on its own
select
  z.ca,
  z.cb,
  z.iv,
  sum(z.ev_obs) as obs,
  sum(z.ev_obs_fma) as obs_fma,
  sum(z.ev_obs_fmb) as obs_fmb,
  sum(z.ev_obs_fmab) as obs_fmab,
  sum(z.ev_obs_fmab_inc) as obs_fmab_inc,
  sum(z.ev_obs_clear) as obs_clear,
  sum(z.ev_obs_same_visit) as obs_same_visit,
  sum(z.ev_obs * z.ev_obs) as obs_sq,
  count(*) as pers,
  sum(z.hp_pers_fma) as pers_fma,
  sum(z.hp_pers_fmb) as pers_fmb,
  sum(z.hp_pers_fmab) as pers_fmab,
  sum(z.hp_pers_fmab_inc) as pers_fmab_inc,
  sum(z.hp_pers_same_visit) as pers_same_visit,
  sum(z.lag_s) as lag_sum,
  sum(z.lag_a) as lag_abs_sum,
  sum(z.lag_q) as lag_sq,
  sum(z.util_pp) as util_sum,
  sum(case when z.util_pp is null then 0 else 1 end) as util_n,
  min(z.fmi_a) as fm_intake_days_a,
  min(z.fmi_b) as fm_intake_days_b,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end as iv,
    sum(cast(1 as bigint)) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fma,
    sum(cast(case when b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmb,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmab,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end as bigint)) as ev_obs_fmab_inc,
    sum(cast(case when a.visit_clear_period = 1 and b.visit_clear_period = 1 then 1 else 0 end as bigint)) as ev_obs_clear,
    sum(cast(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end as bigint)) as ev_obs_same_visit,
    max(case when a.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fma,
    max(case when b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmb,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmab,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end) as hp_pers_fmab_inc,
    max(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end) as hp_pers_same_visit,
    sum(cast(b.start_bucket - a.start_bucket as bigint)) as lag_s,
    sum(abs(cast(b.start_bucket - a.start_bucket as bigint))) as lag_a,
    sum(cast(b.start_bucket - a.start_bucket as bigint) * cast(b.start_bucket - a.start_bucket as bigint)) as lag_q,
    max(coalesce(a.util_score, b.util_score)) as util_pp,
    min(case when a.concept_fm_flag = 1 then a.fm_days_from_intake else null end) as fmi_a,
    min(case when b.concept_fm_flag = 1 then b.fm_days_from_intake else null end) as fmi_b
  from @results_database_schema.cab_s02_condition a
    inner join @results_database_schema.cab_s08_observation_test b on a.person_id = b.person_id and b.start_bucket - a.start_bucket between -@window_days and @window_days
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end
) z
where z.iv is not null
group by z.ca, z.cb, z.iv
)
insert into @results_database_schema.cab_s30_cum
select
  @batch_number as batch_number,
  1050 as pair_type,
  1 as anchor_code,
  a.iv as interval_code,
  a.ca as concept_a,
  a.cb as concept_b,
  a.obs,
  a.obs_fma,
  a.obs_fmb,
  a.obs_fmab,
  a.obs_fmab_inc,
  a.obs_clear,
  a.obs_same_visit,
  a.obs_sq,
  a.pers,
  a.pers_fma,
  a.pers_fmb,
  a.pers_fmab,
  a.pers_fmab_inc,
  a.pers_same_visit,
  a.lag_sum,
  a.lag_abs_sum,
  a.lag_sq,
  a.util_sum,
  a.util_n,
  a.fm_intake_days_a,
  a.fm_intake_days_b
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s30_cum' as table_name, 11 as step, @now_expr as step_datetime;

-- 1060 anchor 1 -- all anchors, near intervals
with w as ( -- aggregate per interval, then threshold on the PAIR total: an
-- interval is smallest exactly when a relationship is strongest, so it must
-- never be filtered away on its own
select
  z.ca,
  z.cb,
  z.iv,
  sum(z.ev_obs) as obs,
  sum(z.ev_obs_fma) as obs_fma,
  sum(z.ev_obs_fmb) as obs_fmb,
  sum(z.ev_obs_fmab) as obs_fmab,
  sum(z.ev_obs_fmab_inc) as obs_fmab_inc,
  sum(z.ev_obs_clear) as obs_clear,
  sum(z.ev_obs_same_visit) as obs_same_visit,
  sum(z.ev_obs * z.ev_obs) as obs_sq,
  count(*) as pers,
  sum(z.hp_pers_fma) as pers_fma,
  sum(z.hp_pers_fmb) as pers_fmb,
  sum(z.hp_pers_fmab) as pers_fmab,
  sum(z.hp_pers_fmab_inc) as pers_fmab_inc,
  sum(z.hp_pers_same_visit) as pers_same_visit,
  sum(z.lag_s) as lag_sum,
  sum(z.lag_a) as lag_abs_sum,
  sum(z.lag_q) as lag_sq,
  sum(z.util_pp) as util_sum,
  sum(case when z.util_pp is null then 0 else 1 end) as util_n,
  min(z.fmi_a) as fm_intake_days_a,
  min(z.fmi_b) as fm_intake_days_b,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end as iv,
    sum(cast(1 as bigint)) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fma,
    sum(cast(case when b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmb,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmab,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end as bigint)) as ev_obs_fmab_inc,
    sum(cast(case when a.visit_clear_period = 1 and b.visit_clear_period = 1 then 1 else 0 end as bigint)) as ev_obs_clear,
    sum(cast(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end as bigint)) as ev_obs_same_visit,
    max(case when a.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fma,
    max(case when b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmb,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmab,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end) as hp_pers_fmab_inc,
    max(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end) as hp_pers_same_visit,
    sum(cast(b.start_bucket - a.start_bucket as bigint)) as lag_s,
    sum(abs(cast(b.start_bucket - a.start_bucket as bigint))) as lag_a,
    sum(cast(b.start_bucket - a.start_bucket as bigint) * cast(b.start_bucket - a.start_bucket as bigint)) as lag_q,
    max(coalesce(a.util_score, b.util_score)) as util_pp,
    min(case when a.concept_fm_flag = 1 then a.fm_days_from_intake else null end) as fmi_a,
    min(case when b.concept_fm_flag = 1 then b.fm_days_from_intake else null end) as fmi_b
  from @results_database_schema.cab_s02_condition a
    inner join @results_database_schema.cab_s09_measurement_test b on a.person_id = b.person_id and b.start_bucket - a.start_bucket between -@window_days and @window_days
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end
) z
where z.iv is not null
group by z.ca, z.cb, z.iv
)
insert into @results_database_schema.cab_s30_cum
select
  @batch_number as batch_number,
  1060 as pair_type,
  1 as anchor_code,
  a.iv as interval_code,
  a.ca as concept_a,
  a.cb as concept_b,
  a.obs,
  a.obs_fma,
  a.obs_fmb,
  a.obs_fmab,
  a.obs_fmab_inc,
  a.obs_clear,
  a.obs_same_visit,
  a.obs_sq,
  a.pers,
  a.pers_fma,
  a.pers_fmb,
  a.pers_fmab,
  a.pers_fmab_inc,
  a.pers_same_visit,
  a.lag_sum,
  a.lag_abs_sum,
  a.lag_sq,
  a.util_sum,
  a.util_n,
  a.fm_intake_days_a,
  a.fm_intake_days_b
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s30_cum' as table_name, 12 as step, @now_expr as step_datetime;

-- 2050 anchor 1 -- all anchors, near intervals
with w as ( -- aggregate per interval, then threshold on the PAIR total: an
-- interval is smallest exactly when a relationship is strongest, so it must
-- never be filtered away on its own
select
  z.ca,
  z.cb,
  z.iv,
  sum(z.ev_obs) as obs,
  sum(z.ev_obs_fma) as obs_fma,
  sum(z.ev_obs_fmb) as obs_fmb,
  sum(z.ev_obs_fmab) as obs_fmab,
  sum(z.ev_obs_fmab_inc) as obs_fmab_inc,
  sum(z.ev_obs_clear) as obs_clear,
  sum(z.ev_obs_same_visit) as obs_same_visit,
  sum(z.ev_obs * z.ev_obs) as obs_sq,
  count(*) as pers,
  sum(z.hp_pers_fma) as pers_fma,
  sum(z.hp_pers_fmb) as pers_fmb,
  sum(z.hp_pers_fmab) as pers_fmab,
  sum(z.hp_pers_fmab_inc) as pers_fmab_inc,
  sum(z.hp_pers_same_visit) as pers_same_visit,
  sum(z.lag_s) as lag_sum,
  sum(z.lag_a) as lag_abs_sum,
  sum(z.lag_q) as lag_sq,
  sum(z.util_pp) as util_sum,
  sum(case when z.util_pp is null then 0 else 1 end) as util_n,
  min(z.fmi_a) as fm_intake_days_a,
  min(z.fmi_b) as fm_intake_days_b,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end as iv,
    sum(cast(1 as bigint)) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fma,
    sum(cast(case when b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmb,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmab,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end as bigint)) as ev_obs_fmab_inc,
    sum(cast(case when a.visit_clear_period = 1 and b.visit_clear_period = 1 then 1 else 0 end as bigint)) as ev_obs_clear,
    sum(cast(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end as bigint)) as ev_obs_same_visit,
    max(case when a.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fma,
    max(case when b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmb,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmab,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end) as hp_pers_fmab_inc,
    max(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end) as hp_pers_same_visit,
    sum(cast(b.start_bucket - a.start_bucket as bigint)) as lag_s,
    sum(abs(cast(b.start_bucket - a.start_bucket as bigint))) as lag_a,
    sum(cast(b.start_bucket - a.start_bucket as bigint) * cast(b.start_bucket - a.start_bucket as bigint)) as lag_q,
    max(coalesce(a.util_score, b.util_score)) as util_pp,
    min(case when a.concept_fm_flag = 1 then a.fm_days_from_intake else null end) as fmi_a,
    min(case when b.concept_fm_flag = 1 then b.fm_days_from_intake else null end) as fmi_b
  from @results_database_schema.cab_s03_procedure a
    inner join @results_database_schema.cab_s08_observation_test b on a.person_id = b.person_id and b.start_bucket - a.start_bucket between -@window_days and @window_days
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end
) z
where z.iv is not null
group by z.ca, z.cb, z.iv
)
insert into @results_database_schema.cab_s30_cum
select
  @batch_number as batch_number,
  2050 as pair_type,
  1 as anchor_code,
  a.iv as interval_code,
  a.ca as concept_a,
  a.cb as concept_b,
  a.obs,
  a.obs_fma,
  a.obs_fmb,
  a.obs_fmab,
  a.obs_fmab_inc,
  a.obs_clear,
  a.obs_same_visit,
  a.obs_sq,
  a.pers,
  a.pers_fma,
  a.pers_fmb,
  a.pers_fmab,
  a.pers_fmab_inc,
  a.pers_same_visit,
  a.lag_sum,
  a.lag_abs_sum,
  a.lag_sq,
  a.util_sum,
  a.util_n,
  a.fm_intake_days_a,
  a.fm_intake_days_b
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s30_cum' as table_name, 13 as step, @now_expr as step_datetime;

-- 2060 anchor 1 -- all anchors, near intervals
with w as ( -- aggregate per interval, then threshold on the PAIR total: an
-- interval is smallest exactly when a relationship is strongest, so it must
-- never be filtered away on its own
select
  z.ca,
  z.cb,
  z.iv,
  sum(z.ev_obs) as obs,
  sum(z.ev_obs_fma) as obs_fma,
  sum(z.ev_obs_fmb) as obs_fmb,
  sum(z.ev_obs_fmab) as obs_fmab,
  sum(z.ev_obs_fmab_inc) as obs_fmab_inc,
  sum(z.ev_obs_clear) as obs_clear,
  sum(z.ev_obs_same_visit) as obs_same_visit,
  sum(z.ev_obs * z.ev_obs) as obs_sq,
  count(*) as pers,
  sum(z.hp_pers_fma) as pers_fma,
  sum(z.hp_pers_fmb) as pers_fmb,
  sum(z.hp_pers_fmab) as pers_fmab,
  sum(z.hp_pers_fmab_inc) as pers_fmab_inc,
  sum(z.hp_pers_same_visit) as pers_same_visit,
  sum(z.lag_s) as lag_sum,
  sum(z.lag_a) as lag_abs_sum,
  sum(z.lag_q) as lag_sq,
  sum(z.util_pp) as util_sum,
  sum(case when z.util_pp is null then 0 else 1 end) as util_n,
  min(z.fmi_a) as fm_intake_days_a,
  min(z.fmi_b) as fm_intake_days_b,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end as iv,
    sum(cast(1 as bigint)) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fma,
    sum(cast(case when b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmb,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmab,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end as bigint)) as ev_obs_fmab_inc,
    sum(cast(case when a.visit_clear_period = 1 and b.visit_clear_period = 1 then 1 else 0 end as bigint)) as ev_obs_clear,
    sum(cast(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end as bigint)) as ev_obs_same_visit,
    max(case when a.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fma,
    max(case when b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmb,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmab,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end) as hp_pers_fmab_inc,
    max(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end) as hp_pers_same_visit,
    sum(cast(b.start_bucket - a.start_bucket as bigint)) as lag_s,
    sum(abs(cast(b.start_bucket - a.start_bucket as bigint))) as lag_a,
    sum(cast(b.start_bucket - a.start_bucket as bigint) * cast(b.start_bucket - a.start_bucket as bigint)) as lag_q,
    max(coalesce(a.util_score, b.util_score)) as util_pp,
    min(case when a.concept_fm_flag = 1 then a.fm_days_from_intake else null end) as fmi_a,
    min(case when b.concept_fm_flag = 1 then b.fm_days_from_intake else null end) as fmi_b
  from @results_database_schema.cab_s03_procedure a
    inner join @results_database_schema.cab_s09_measurement_test b on a.person_id = b.person_id and b.start_bucket - a.start_bucket between -@window_days and @window_days
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end
) z
where z.iv is not null
group by z.ca, z.cb, z.iv
)
insert into @results_database_schema.cab_s30_cum
select
  @batch_number as batch_number,
  2060 as pair_type,
  1 as anchor_code,
  a.iv as interval_code,
  a.ca as concept_a,
  a.cb as concept_b,
  a.obs,
  a.obs_fma,
  a.obs_fmb,
  a.obs_fmab,
  a.obs_fmab_inc,
  a.obs_clear,
  a.obs_same_visit,
  a.obs_sq,
  a.pers,
  a.pers_fma,
  a.pers_fmb,
  a.pers_fmab,
  a.pers_fmab_inc,
  a.pers_same_visit,
  a.lag_sum,
  a.lag_abs_sum,
  a.lag_sq,
  a.util_sum,
  a.util_n,
  a.fm_intake_days_a,
  a.fm_intake_days_b
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s30_cum' as table_name, 14 as step, @now_expr as step_datetime;

-- 3050 anchor 1 -- all anchors, near intervals
with w as ( -- aggregate per interval, then threshold on the PAIR total: an
-- interval is smallest exactly when a relationship is strongest, so it must
-- never be filtered away on its own
select
  z.ca,
  z.cb,
  z.iv,
  sum(z.ev_obs) as obs,
  sum(z.ev_obs_fma) as obs_fma,
  sum(z.ev_obs_fmb) as obs_fmb,
  sum(z.ev_obs_fmab) as obs_fmab,
  sum(z.ev_obs_fmab_inc) as obs_fmab_inc,
  sum(z.ev_obs_clear) as obs_clear,
  sum(z.ev_obs_same_visit) as obs_same_visit,
  sum(z.ev_obs * z.ev_obs) as obs_sq,
  count(*) as pers,
  sum(z.hp_pers_fma) as pers_fma,
  sum(z.hp_pers_fmb) as pers_fmb,
  sum(z.hp_pers_fmab) as pers_fmab,
  sum(z.hp_pers_fmab_inc) as pers_fmab_inc,
  sum(z.hp_pers_same_visit) as pers_same_visit,
  sum(z.lag_s) as lag_sum,
  sum(z.lag_a) as lag_abs_sum,
  sum(z.lag_q) as lag_sq,
  sum(z.util_pp) as util_sum,
  sum(case when z.util_pp is null then 0 else 1 end) as util_n,
  min(z.fmi_a) as fm_intake_days_a,
  min(z.fmi_b) as fm_intake_days_b,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end as iv,
    sum(cast(1 as bigint)) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fma,
    sum(cast(case when b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmb,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmab,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end as bigint)) as ev_obs_fmab_inc,
    sum(cast(case when a.visit_clear_period = 1 and b.visit_clear_period = 1 then 1 else 0 end as bigint)) as ev_obs_clear,
    sum(cast(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end as bigint)) as ev_obs_same_visit,
    max(case when a.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fma,
    max(case when b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmb,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmab,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end) as hp_pers_fmab_inc,
    max(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end) as hp_pers_same_visit,
    sum(cast(b.start_bucket - a.start_bucket as bigint)) as lag_s,
    sum(abs(cast(b.start_bucket - a.start_bucket as bigint))) as lag_a,
    sum(cast(b.start_bucket - a.start_bucket as bigint) * cast(b.start_bucket - a.start_bucket as bigint)) as lag_q,
    max(coalesce(a.util_score, b.util_score)) as util_pp,
    min(case when a.concept_fm_flag = 1 then a.fm_days_from_intake else null end) as fmi_a,
    min(case when b.concept_fm_flag = 1 then b.fm_days_from_intake else null end) as fmi_b
  from @results_database_schema.cab_s04_device a
    inner join @results_database_schema.cab_s08_observation_test b on a.person_id = b.person_id and b.start_bucket - a.start_bucket between -@window_days and @window_days
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end
) z
where z.iv is not null
group by z.ca, z.cb, z.iv
)
insert into @results_database_schema.cab_s30_cum
select
  @batch_number as batch_number,
  3050 as pair_type,
  1 as anchor_code,
  a.iv as interval_code,
  a.ca as concept_a,
  a.cb as concept_b,
  a.obs,
  a.obs_fma,
  a.obs_fmb,
  a.obs_fmab,
  a.obs_fmab_inc,
  a.obs_clear,
  a.obs_same_visit,
  a.obs_sq,
  a.pers,
  a.pers_fma,
  a.pers_fmb,
  a.pers_fmab,
  a.pers_fmab_inc,
  a.pers_same_visit,
  a.lag_sum,
  a.lag_abs_sum,
  a.lag_sq,
  a.util_sum,
  a.util_n,
  a.fm_intake_days_a,
  a.fm_intake_days_b
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s30_cum' as table_name, 15 as step, @now_expr as step_datetime;

-- 3060 anchor 1 -- all anchors, near intervals
with w as ( -- aggregate per interval, then threshold on the PAIR total: an
-- interval is smallest exactly when a relationship is strongest, so it must
-- never be filtered away on its own
select
  z.ca,
  z.cb,
  z.iv,
  sum(z.ev_obs) as obs,
  sum(z.ev_obs_fma) as obs_fma,
  sum(z.ev_obs_fmb) as obs_fmb,
  sum(z.ev_obs_fmab) as obs_fmab,
  sum(z.ev_obs_fmab_inc) as obs_fmab_inc,
  sum(z.ev_obs_clear) as obs_clear,
  sum(z.ev_obs_same_visit) as obs_same_visit,
  sum(z.ev_obs * z.ev_obs) as obs_sq,
  count(*) as pers,
  sum(z.hp_pers_fma) as pers_fma,
  sum(z.hp_pers_fmb) as pers_fmb,
  sum(z.hp_pers_fmab) as pers_fmab,
  sum(z.hp_pers_fmab_inc) as pers_fmab_inc,
  sum(z.hp_pers_same_visit) as pers_same_visit,
  sum(z.lag_s) as lag_sum,
  sum(z.lag_a) as lag_abs_sum,
  sum(z.lag_q) as lag_sq,
  sum(z.util_pp) as util_sum,
  sum(case when z.util_pp is null then 0 else 1 end) as util_n,
  min(z.fmi_a) as fm_intake_days_a,
  min(z.fmi_b) as fm_intake_days_b,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end as iv,
    sum(cast(1 as bigint)) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fma,
    sum(cast(case when b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmb,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmab,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end as bigint)) as ev_obs_fmab_inc,
    sum(cast(case when a.visit_clear_period = 1 and b.visit_clear_period = 1 then 1 else 0 end as bigint)) as ev_obs_clear,
    sum(cast(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end as bigint)) as ev_obs_same_visit,
    max(case when a.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fma,
    max(case when b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmb,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmab,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end) as hp_pers_fmab_inc,
    max(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end) as hp_pers_same_visit,
    sum(cast(b.start_bucket - a.start_bucket as bigint)) as lag_s,
    sum(abs(cast(b.start_bucket - a.start_bucket as bigint))) as lag_a,
    sum(cast(b.start_bucket - a.start_bucket as bigint) * cast(b.start_bucket - a.start_bucket as bigint)) as lag_q,
    max(coalesce(a.util_score, b.util_score)) as util_pp,
    min(case when a.concept_fm_flag = 1 then a.fm_days_from_intake else null end) as fmi_a,
    min(case when b.concept_fm_flag = 1 then b.fm_days_from_intake else null end) as fmi_b
  from @results_database_schema.cab_s04_device a
    inner join @results_database_schema.cab_s09_measurement_test b on a.person_id = b.person_id and b.start_bucket - a.start_bucket between -@window_days and @window_days
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end
) z
where z.iv is not null
group by z.ca, z.cb, z.iv
)
insert into @results_database_schema.cab_s30_cum
select
  @batch_number as batch_number,
  3060 as pair_type,
  1 as anchor_code,
  a.iv as interval_code,
  a.ca as concept_a,
  a.cb as concept_b,
  a.obs,
  a.obs_fma,
  a.obs_fmb,
  a.obs_fmab,
  a.obs_fmab_inc,
  a.obs_clear,
  a.obs_same_visit,
  a.obs_sq,
  a.pers,
  a.pers_fma,
  a.pers_fmb,
  a.pers_fmab,
  a.pers_fmab_inc,
  a.pers_same_visit,
  a.lag_sum,
  a.lag_abs_sum,
  a.lag_sq,
  a.util_sum,
  a.util_n,
  a.fm_intake_days_a,
  a.fm_intake_days_b
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s30_cum' as table_name, 16 as step, @now_expr as step_datetime;

-- 4050 anchor 1 -- all anchors, near intervals
with w as ( -- aggregate per interval, then threshold on the PAIR total: an
-- interval is smallest exactly when a relationship is strongest, so it must
-- never be filtered away on its own
select
  z.ca,
  z.cb,
  z.iv,
  sum(z.ev_obs) as obs,
  sum(z.ev_obs_fma) as obs_fma,
  sum(z.ev_obs_fmb) as obs_fmb,
  sum(z.ev_obs_fmab) as obs_fmab,
  sum(z.ev_obs_fmab_inc) as obs_fmab_inc,
  sum(z.ev_obs_clear) as obs_clear,
  sum(z.ev_obs_same_visit) as obs_same_visit,
  sum(z.ev_obs * z.ev_obs) as obs_sq,
  count(*) as pers,
  sum(z.hp_pers_fma) as pers_fma,
  sum(z.hp_pers_fmb) as pers_fmb,
  sum(z.hp_pers_fmab) as pers_fmab,
  sum(z.hp_pers_fmab_inc) as pers_fmab_inc,
  sum(z.hp_pers_same_visit) as pers_same_visit,
  sum(z.lag_s) as lag_sum,
  sum(z.lag_a) as lag_abs_sum,
  sum(z.lag_q) as lag_sq,
  sum(z.util_pp) as util_sum,
  sum(case when z.util_pp is null then 0 else 1 end) as util_n,
  min(z.fmi_a) as fm_intake_days_a,
  min(z.fmi_b) as fm_intake_days_b,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end as iv,
    sum(cast(1 as bigint)) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fma,
    sum(cast(case when b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmb,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmab,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end as bigint)) as ev_obs_fmab_inc,
    sum(cast(case when a.visit_clear_period = 1 and b.visit_clear_period = 1 then 1 else 0 end as bigint)) as ev_obs_clear,
    sum(cast(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end as bigint)) as ev_obs_same_visit,
    max(case when a.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fma,
    max(case when b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmb,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmab,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end) as hp_pers_fmab_inc,
    max(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end) as hp_pers_same_visit,
    sum(cast(b.start_bucket - a.start_bucket as bigint)) as lag_s,
    sum(abs(cast(b.start_bucket - a.start_bucket as bigint))) as lag_a,
    sum(cast(b.start_bucket - a.start_bucket as bigint) * cast(b.start_bucket - a.start_bucket as bigint)) as lag_q,
    max(coalesce(a.util_score, b.util_score)) as util_pp,
    min(case when a.concept_fm_flag = 1 then a.fm_days_from_intake else null end) as fmi_a,
    min(case when b.concept_fm_flag = 1 then b.fm_days_from_intake else null end) as fmi_b
  from @results_database_schema.cab_s05_drug a
    inner join @results_database_schema.cab_s08_observation_test b on a.person_id = b.person_id and b.start_bucket - a.start_bucket between -@window_days and @window_days
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end
) z
where z.iv is not null
group by z.ca, z.cb, z.iv
)
insert into @results_database_schema.cab_s30_cum
select
  @batch_number as batch_number,
  4050 as pair_type,
  1 as anchor_code,
  a.iv as interval_code,
  a.ca as concept_a,
  a.cb as concept_b,
  a.obs,
  a.obs_fma,
  a.obs_fmb,
  a.obs_fmab,
  a.obs_fmab_inc,
  a.obs_clear,
  a.obs_same_visit,
  a.obs_sq,
  a.pers,
  a.pers_fma,
  a.pers_fmb,
  a.pers_fmab,
  a.pers_fmab_inc,
  a.pers_same_visit,
  a.lag_sum,
  a.lag_abs_sum,
  a.lag_sq,
  a.util_sum,
  a.util_n,
  a.fm_intake_days_a,
  a.fm_intake_days_b
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s30_cum' as table_name, 17 as step, @now_expr as step_datetime;

-- 4060 anchor 1 -- all anchors, near intervals
with w as ( -- aggregate per interval, then threshold on the PAIR total: an
-- interval is smallest exactly when a relationship is strongest, so it must
-- never be filtered away on its own
select
  z.ca,
  z.cb,
  z.iv,
  sum(z.ev_obs) as obs,
  sum(z.ev_obs_fma) as obs_fma,
  sum(z.ev_obs_fmb) as obs_fmb,
  sum(z.ev_obs_fmab) as obs_fmab,
  sum(z.ev_obs_fmab_inc) as obs_fmab_inc,
  sum(z.ev_obs_clear) as obs_clear,
  sum(z.ev_obs_same_visit) as obs_same_visit,
  sum(z.ev_obs * z.ev_obs) as obs_sq,
  count(*) as pers,
  sum(z.hp_pers_fma) as pers_fma,
  sum(z.hp_pers_fmb) as pers_fmb,
  sum(z.hp_pers_fmab) as pers_fmab,
  sum(z.hp_pers_fmab_inc) as pers_fmab_inc,
  sum(z.hp_pers_same_visit) as pers_same_visit,
  sum(z.lag_s) as lag_sum,
  sum(z.lag_a) as lag_abs_sum,
  sum(z.lag_q) as lag_sq,
  sum(z.util_pp) as util_sum,
  sum(case when z.util_pp is null then 0 else 1 end) as util_n,
  min(z.fmi_a) as fm_intake_days_a,
  min(z.fmi_b) as fm_intake_days_b,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end as iv,
    sum(cast(1 as bigint)) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fma,
    sum(cast(case when b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmb,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmab,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end as bigint)) as ev_obs_fmab_inc,
    sum(cast(case when a.visit_clear_period = 1 and b.visit_clear_period = 1 then 1 else 0 end as bigint)) as ev_obs_clear,
    sum(cast(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end as bigint)) as ev_obs_same_visit,
    max(case when a.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fma,
    max(case when b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmb,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmab,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end) as hp_pers_fmab_inc,
    max(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end) as hp_pers_same_visit,
    sum(cast(b.start_bucket - a.start_bucket as bigint)) as lag_s,
    sum(abs(cast(b.start_bucket - a.start_bucket as bigint))) as lag_a,
    sum(cast(b.start_bucket - a.start_bucket as bigint) * cast(b.start_bucket - a.start_bucket as bigint)) as lag_q,
    max(coalesce(a.util_score, b.util_score)) as util_pp,
    min(case when a.concept_fm_flag = 1 then a.fm_days_from_intake else null end) as fmi_a,
    min(case when b.concept_fm_flag = 1 then b.fm_days_from_intake else null end) as fmi_b
  from @results_database_schema.cab_s05_drug a
    inner join @results_database_schema.cab_s09_measurement_test b on a.person_id = b.person_id and b.start_bucket - a.start_bucket between -@window_days and @window_days
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end
) z
where z.iv is not null
group by z.ca, z.cb, z.iv
)
insert into @results_database_schema.cab_s30_cum
select
  @batch_number as batch_number,
  4060 as pair_type,
  1 as anchor_code,
  a.iv as interval_code,
  a.ca as concept_a,
  a.cb as concept_b,
  a.obs,
  a.obs_fma,
  a.obs_fmb,
  a.obs_fmab,
  a.obs_fmab_inc,
  a.obs_clear,
  a.obs_same_visit,
  a.obs_sq,
  a.pers,
  a.pers_fma,
  a.pers_fmb,
  a.pers_fmab,
  a.pers_fmab_inc,
  a.pers_same_visit,
  a.lag_sum,
  a.lag_abs_sum,
  a.lag_sq,
  a.util_sum,
  a.util_n,
  a.fm_intake_days_a,
  a.fm_intake_days_b
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s30_cum' as table_name, 18 as step, @now_expr as step_datetime;

-- 1051 anchor 1 -- all anchors, near intervals
with w as ( -- aggregate per interval, then threshold on the PAIR total: an
-- interval is smallest exactly when a relationship is strongest, so it must
-- never be filtered away on its own
select
  z.ca,
  z.cb,
  z.iv,
  sum(z.ev_obs) as obs,
  sum(z.ev_obs_fma) as obs_fma,
  sum(z.ev_obs_fmb) as obs_fmb,
  sum(z.ev_obs_fmab) as obs_fmab,
  sum(z.ev_obs_fmab_inc) as obs_fmab_inc,
  sum(z.ev_obs_clear) as obs_clear,
  sum(z.ev_obs_same_visit) as obs_same_visit,
  sum(z.ev_obs * z.ev_obs) as obs_sq,
  count(*) as pers,
  sum(z.hp_pers_fma) as pers_fma,
  sum(z.hp_pers_fmb) as pers_fmb,
  sum(z.hp_pers_fmab) as pers_fmab,
  sum(z.hp_pers_fmab_inc) as pers_fmab_inc,
  sum(z.hp_pers_same_visit) as pers_same_visit,
  sum(z.lag_s) as lag_sum,
  sum(z.lag_a) as lag_abs_sum,
  sum(z.lag_q) as lag_sq,
  sum(z.util_pp) as util_sum,
  sum(case when z.util_pp is null then 0 else 1 end) as util_n,
  min(z.fmi_a) as fm_intake_days_a,
  min(z.fmi_b) as fm_intake_days_b,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end as iv,
    sum(cast(1 as bigint)) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fma,
    sum(cast(case when b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmb,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmab,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end as bigint)) as ev_obs_fmab_inc,
    sum(cast(case when a.visit_clear_period = 1 and b.visit_clear_period = 1 then 1 else 0 end as bigint)) as ev_obs_clear,
    sum(cast(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end as bigint)) as ev_obs_same_visit,
    max(case when a.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fma,
    max(case when b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmb,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmab,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end) as hp_pers_fmab_inc,
    max(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end) as hp_pers_same_visit,
    sum(cast(b.start_bucket - a.start_bucket as bigint)) as lag_s,
    sum(abs(cast(b.start_bucket - a.start_bucket as bigint))) as lag_a,
    sum(cast(b.start_bucket - a.start_bucket as bigint) * cast(b.start_bucket - a.start_bucket as bigint)) as lag_q,
    max(coalesce(a.util_score, b.util_score)) as util_pp,
    min(case when a.concept_fm_flag = 1 then a.fm_days_from_intake else null end) as fmi_a,
    min(case when b.concept_fm_flag = 1 then b.fm_days_from_intake else null end) as fmi_b
  from @results_database_schema.cab_s02_condition a
    inner join @results_database_schema.cab_s06_observation b on a.person_id = b.person_id and b.start_bucket - a.start_bucket between -@window_days and @window_days
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end
) z
where z.iv is not null
group by z.ca, z.cb, z.iv
)
insert into @results_database_schema.cab_s30_cum
select
  @batch_number as batch_number,
  1051 as pair_type,
  1 as anchor_code,
  a.iv as interval_code,
  a.ca as concept_a,
  a.cb as concept_b,
  a.obs,
  a.obs_fma,
  a.obs_fmb,
  a.obs_fmab,
  a.obs_fmab_inc,
  a.obs_clear,
  a.obs_same_visit,
  a.obs_sq,
  a.pers,
  a.pers_fma,
  a.pers_fmb,
  a.pers_fmab,
  a.pers_fmab_inc,
  a.pers_same_visit,
  a.lag_sum,
  a.lag_abs_sum,
  a.lag_sq,
  a.util_sum,
  a.util_n,
  a.fm_intake_days_a,
  a.fm_intake_days_b
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s30_cum' as table_name, 19 as step, @now_expr as step_datetime;

-- 1061 anchor 1 -- all anchors, near intervals
with w as ( -- aggregate per interval, then threshold on the PAIR total: an
-- interval is smallest exactly when a relationship is strongest, so it must
-- never be filtered away on its own
select
  z.ca,
  z.cb,
  z.iv,
  sum(z.ev_obs) as obs,
  sum(z.ev_obs_fma) as obs_fma,
  sum(z.ev_obs_fmb) as obs_fmb,
  sum(z.ev_obs_fmab) as obs_fmab,
  sum(z.ev_obs_fmab_inc) as obs_fmab_inc,
  sum(z.ev_obs_clear) as obs_clear,
  sum(z.ev_obs_same_visit) as obs_same_visit,
  sum(z.ev_obs * z.ev_obs) as obs_sq,
  count(*) as pers,
  sum(z.hp_pers_fma) as pers_fma,
  sum(z.hp_pers_fmb) as pers_fmb,
  sum(z.hp_pers_fmab) as pers_fmab,
  sum(z.hp_pers_fmab_inc) as pers_fmab_inc,
  sum(z.hp_pers_same_visit) as pers_same_visit,
  sum(z.lag_s) as lag_sum,
  sum(z.lag_a) as lag_abs_sum,
  sum(z.lag_q) as lag_sq,
  sum(z.util_pp) as util_sum,
  sum(case when z.util_pp is null then 0 else 1 end) as util_n,
  min(z.fmi_a) as fm_intake_days_a,
  min(z.fmi_b) as fm_intake_days_b,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end as iv,
    sum(cast(1 as bigint)) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fma,
    sum(cast(case when b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmb,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmab,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end as bigint)) as ev_obs_fmab_inc,
    sum(cast(case when a.visit_clear_period = 1 and b.visit_clear_period = 1 then 1 else 0 end as bigint)) as ev_obs_clear,
    sum(cast(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end as bigint)) as ev_obs_same_visit,
    max(case when a.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fma,
    max(case when b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmb,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmab,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end) as hp_pers_fmab_inc,
    max(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end) as hp_pers_same_visit,
    sum(cast(b.start_bucket - a.start_bucket as bigint)) as lag_s,
    sum(abs(cast(b.start_bucket - a.start_bucket as bigint))) as lag_a,
    sum(cast(b.start_bucket - a.start_bucket as bigint) * cast(b.start_bucket - a.start_bucket as bigint)) as lag_q,
    max(coalesce(a.util_score, b.util_score)) as util_pp,
    min(case when a.concept_fm_flag = 1 then a.fm_days_from_intake else null end) as fmi_a,
    min(case when b.concept_fm_flag = 1 then b.fm_days_from_intake else null end) as fmi_b
  from @results_database_schema.cab_s02_condition a
    inner join @results_database_schema.cab_s07_measurement b on a.person_id = b.person_id and b.start_bucket - a.start_bucket between -@window_days and @window_days
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end
) z
where z.iv is not null
group by z.ca, z.cb, z.iv
)
insert into @results_database_schema.cab_s30_cum
select
  @batch_number as batch_number,
  1061 as pair_type,
  1 as anchor_code,
  a.iv as interval_code,
  a.ca as concept_a,
  a.cb as concept_b,
  a.obs,
  a.obs_fma,
  a.obs_fmb,
  a.obs_fmab,
  a.obs_fmab_inc,
  a.obs_clear,
  a.obs_same_visit,
  a.obs_sq,
  a.pers,
  a.pers_fma,
  a.pers_fmb,
  a.pers_fmab,
  a.pers_fmab_inc,
  a.pers_same_visit,
  a.lag_sum,
  a.lag_abs_sum,
  a.lag_sq,
  a.util_sum,
  a.util_n,
  a.fm_intake_days_a,
  a.fm_intake_days_b
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s30_cum' as table_name, 20 as step, @now_expr as step_datetime;

-- 2051 anchor 1 -- all anchors, near intervals
with w as ( -- aggregate per interval, then threshold on the PAIR total: an
-- interval is smallest exactly when a relationship is strongest, so it must
-- never be filtered away on its own
select
  z.ca,
  z.cb,
  z.iv,
  sum(z.ev_obs) as obs,
  sum(z.ev_obs_fma) as obs_fma,
  sum(z.ev_obs_fmb) as obs_fmb,
  sum(z.ev_obs_fmab) as obs_fmab,
  sum(z.ev_obs_fmab_inc) as obs_fmab_inc,
  sum(z.ev_obs_clear) as obs_clear,
  sum(z.ev_obs_same_visit) as obs_same_visit,
  sum(z.ev_obs * z.ev_obs) as obs_sq,
  count(*) as pers,
  sum(z.hp_pers_fma) as pers_fma,
  sum(z.hp_pers_fmb) as pers_fmb,
  sum(z.hp_pers_fmab) as pers_fmab,
  sum(z.hp_pers_fmab_inc) as pers_fmab_inc,
  sum(z.hp_pers_same_visit) as pers_same_visit,
  sum(z.lag_s) as lag_sum,
  sum(z.lag_a) as lag_abs_sum,
  sum(z.lag_q) as lag_sq,
  sum(z.util_pp) as util_sum,
  sum(case when z.util_pp is null then 0 else 1 end) as util_n,
  min(z.fmi_a) as fm_intake_days_a,
  min(z.fmi_b) as fm_intake_days_b,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end as iv,
    sum(cast(1 as bigint)) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fma,
    sum(cast(case when b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmb,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmab,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end as bigint)) as ev_obs_fmab_inc,
    sum(cast(case when a.visit_clear_period = 1 and b.visit_clear_period = 1 then 1 else 0 end as bigint)) as ev_obs_clear,
    sum(cast(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end as bigint)) as ev_obs_same_visit,
    max(case when a.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fma,
    max(case when b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmb,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmab,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end) as hp_pers_fmab_inc,
    max(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end) as hp_pers_same_visit,
    sum(cast(b.start_bucket - a.start_bucket as bigint)) as lag_s,
    sum(abs(cast(b.start_bucket - a.start_bucket as bigint))) as lag_a,
    sum(cast(b.start_bucket - a.start_bucket as bigint) * cast(b.start_bucket - a.start_bucket as bigint)) as lag_q,
    max(coalesce(a.util_score, b.util_score)) as util_pp,
    min(case when a.concept_fm_flag = 1 then a.fm_days_from_intake else null end) as fmi_a,
    min(case when b.concept_fm_flag = 1 then b.fm_days_from_intake else null end) as fmi_b
  from @results_database_schema.cab_s03_procedure a
    inner join @results_database_schema.cab_s06_observation b on a.person_id = b.person_id and b.start_bucket - a.start_bucket between -@window_days and @window_days
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end
) z
where z.iv is not null
group by z.ca, z.cb, z.iv
)
insert into @results_database_schema.cab_s30_cum
select
  @batch_number as batch_number,
  2051 as pair_type,
  1 as anchor_code,
  a.iv as interval_code,
  a.ca as concept_a,
  a.cb as concept_b,
  a.obs,
  a.obs_fma,
  a.obs_fmb,
  a.obs_fmab,
  a.obs_fmab_inc,
  a.obs_clear,
  a.obs_same_visit,
  a.obs_sq,
  a.pers,
  a.pers_fma,
  a.pers_fmb,
  a.pers_fmab,
  a.pers_fmab_inc,
  a.pers_same_visit,
  a.lag_sum,
  a.lag_abs_sum,
  a.lag_sq,
  a.util_sum,
  a.util_n,
  a.fm_intake_days_a,
  a.fm_intake_days_b
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s30_cum' as table_name, 21 as step, @now_expr as step_datetime;

-- 2061 anchor 1 -- all anchors, near intervals
with w as ( -- aggregate per interval, then threshold on the PAIR total: an
-- interval is smallest exactly when a relationship is strongest, so it must
-- never be filtered away on its own
select
  z.ca,
  z.cb,
  z.iv,
  sum(z.ev_obs) as obs,
  sum(z.ev_obs_fma) as obs_fma,
  sum(z.ev_obs_fmb) as obs_fmb,
  sum(z.ev_obs_fmab) as obs_fmab,
  sum(z.ev_obs_fmab_inc) as obs_fmab_inc,
  sum(z.ev_obs_clear) as obs_clear,
  sum(z.ev_obs_same_visit) as obs_same_visit,
  sum(z.ev_obs * z.ev_obs) as obs_sq,
  count(*) as pers,
  sum(z.hp_pers_fma) as pers_fma,
  sum(z.hp_pers_fmb) as pers_fmb,
  sum(z.hp_pers_fmab) as pers_fmab,
  sum(z.hp_pers_fmab_inc) as pers_fmab_inc,
  sum(z.hp_pers_same_visit) as pers_same_visit,
  sum(z.lag_s) as lag_sum,
  sum(z.lag_a) as lag_abs_sum,
  sum(z.lag_q) as lag_sq,
  sum(z.util_pp) as util_sum,
  sum(case when z.util_pp is null then 0 else 1 end) as util_n,
  min(z.fmi_a) as fm_intake_days_a,
  min(z.fmi_b) as fm_intake_days_b,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end as iv,
    sum(cast(1 as bigint)) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fma,
    sum(cast(case when b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmb,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmab,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end as bigint)) as ev_obs_fmab_inc,
    sum(cast(case when a.visit_clear_period = 1 and b.visit_clear_period = 1 then 1 else 0 end as bigint)) as ev_obs_clear,
    sum(cast(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end as bigint)) as ev_obs_same_visit,
    max(case when a.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fma,
    max(case when b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmb,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmab,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end) as hp_pers_fmab_inc,
    max(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end) as hp_pers_same_visit,
    sum(cast(b.start_bucket - a.start_bucket as bigint)) as lag_s,
    sum(abs(cast(b.start_bucket - a.start_bucket as bigint))) as lag_a,
    sum(cast(b.start_bucket - a.start_bucket as bigint) * cast(b.start_bucket - a.start_bucket as bigint)) as lag_q,
    max(coalesce(a.util_score, b.util_score)) as util_pp,
    min(case when a.concept_fm_flag = 1 then a.fm_days_from_intake else null end) as fmi_a,
    min(case when b.concept_fm_flag = 1 then b.fm_days_from_intake else null end) as fmi_b
  from @results_database_schema.cab_s03_procedure a
    inner join @results_database_schema.cab_s07_measurement b on a.person_id = b.person_id and b.start_bucket - a.start_bucket between -@window_days and @window_days
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end
) z
where z.iv is not null
group by z.ca, z.cb, z.iv
)
insert into @results_database_schema.cab_s30_cum
select
  @batch_number as batch_number,
  2061 as pair_type,
  1 as anchor_code,
  a.iv as interval_code,
  a.ca as concept_a,
  a.cb as concept_b,
  a.obs,
  a.obs_fma,
  a.obs_fmb,
  a.obs_fmab,
  a.obs_fmab_inc,
  a.obs_clear,
  a.obs_same_visit,
  a.obs_sq,
  a.pers,
  a.pers_fma,
  a.pers_fmb,
  a.pers_fmab,
  a.pers_fmab_inc,
  a.pers_same_visit,
  a.lag_sum,
  a.lag_abs_sum,
  a.lag_sq,
  a.util_sum,
  a.util_n,
  a.fm_intake_days_a,
  a.fm_intake_days_b
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s30_cum' as table_name, 22 as step, @now_expr as step_datetime;

-- 3051 anchor 1 -- all anchors, near intervals
with w as ( -- aggregate per interval, then threshold on the PAIR total: an
-- interval is smallest exactly when a relationship is strongest, so it must
-- never be filtered away on its own
select
  z.ca,
  z.cb,
  z.iv,
  sum(z.ev_obs) as obs,
  sum(z.ev_obs_fma) as obs_fma,
  sum(z.ev_obs_fmb) as obs_fmb,
  sum(z.ev_obs_fmab) as obs_fmab,
  sum(z.ev_obs_fmab_inc) as obs_fmab_inc,
  sum(z.ev_obs_clear) as obs_clear,
  sum(z.ev_obs_same_visit) as obs_same_visit,
  sum(z.ev_obs * z.ev_obs) as obs_sq,
  count(*) as pers,
  sum(z.hp_pers_fma) as pers_fma,
  sum(z.hp_pers_fmb) as pers_fmb,
  sum(z.hp_pers_fmab) as pers_fmab,
  sum(z.hp_pers_fmab_inc) as pers_fmab_inc,
  sum(z.hp_pers_same_visit) as pers_same_visit,
  sum(z.lag_s) as lag_sum,
  sum(z.lag_a) as lag_abs_sum,
  sum(z.lag_q) as lag_sq,
  sum(z.util_pp) as util_sum,
  sum(case when z.util_pp is null then 0 else 1 end) as util_n,
  min(z.fmi_a) as fm_intake_days_a,
  min(z.fmi_b) as fm_intake_days_b,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end as iv,
    sum(cast(1 as bigint)) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fma,
    sum(cast(case when b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmb,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmab,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end as bigint)) as ev_obs_fmab_inc,
    sum(cast(case when a.visit_clear_period = 1 and b.visit_clear_period = 1 then 1 else 0 end as bigint)) as ev_obs_clear,
    sum(cast(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end as bigint)) as ev_obs_same_visit,
    max(case when a.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fma,
    max(case when b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmb,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmab,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end) as hp_pers_fmab_inc,
    max(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end) as hp_pers_same_visit,
    sum(cast(b.start_bucket - a.start_bucket as bigint)) as lag_s,
    sum(abs(cast(b.start_bucket - a.start_bucket as bigint))) as lag_a,
    sum(cast(b.start_bucket - a.start_bucket as bigint) * cast(b.start_bucket - a.start_bucket as bigint)) as lag_q,
    max(coalesce(a.util_score, b.util_score)) as util_pp,
    min(case when a.concept_fm_flag = 1 then a.fm_days_from_intake else null end) as fmi_a,
    min(case when b.concept_fm_flag = 1 then b.fm_days_from_intake else null end) as fmi_b
  from @results_database_schema.cab_s04_device a
    inner join @results_database_schema.cab_s06_observation b on a.person_id = b.person_id and b.start_bucket - a.start_bucket between -@window_days and @window_days
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end
) z
where z.iv is not null
group by z.ca, z.cb, z.iv
)
insert into @results_database_schema.cab_s30_cum
select
  @batch_number as batch_number,
  3051 as pair_type,
  1 as anchor_code,
  a.iv as interval_code,
  a.ca as concept_a,
  a.cb as concept_b,
  a.obs,
  a.obs_fma,
  a.obs_fmb,
  a.obs_fmab,
  a.obs_fmab_inc,
  a.obs_clear,
  a.obs_same_visit,
  a.obs_sq,
  a.pers,
  a.pers_fma,
  a.pers_fmb,
  a.pers_fmab,
  a.pers_fmab_inc,
  a.pers_same_visit,
  a.lag_sum,
  a.lag_abs_sum,
  a.lag_sq,
  a.util_sum,
  a.util_n,
  a.fm_intake_days_a,
  a.fm_intake_days_b
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s30_cum' as table_name, 23 as step, @now_expr as step_datetime;

-- 3061 anchor 1 -- all anchors, near intervals
with w as ( -- aggregate per interval, then threshold on the PAIR total: an
-- interval is smallest exactly when a relationship is strongest, so it must
-- never be filtered away on its own
select
  z.ca,
  z.cb,
  z.iv,
  sum(z.ev_obs) as obs,
  sum(z.ev_obs_fma) as obs_fma,
  sum(z.ev_obs_fmb) as obs_fmb,
  sum(z.ev_obs_fmab) as obs_fmab,
  sum(z.ev_obs_fmab_inc) as obs_fmab_inc,
  sum(z.ev_obs_clear) as obs_clear,
  sum(z.ev_obs_same_visit) as obs_same_visit,
  sum(z.ev_obs * z.ev_obs) as obs_sq,
  count(*) as pers,
  sum(z.hp_pers_fma) as pers_fma,
  sum(z.hp_pers_fmb) as pers_fmb,
  sum(z.hp_pers_fmab) as pers_fmab,
  sum(z.hp_pers_fmab_inc) as pers_fmab_inc,
  sum(z.hp_pers_same_visit) as pers_same_visit,
  sum(z.lag_s) as lag_sum,
  sum(z.lag_a) as lag_abs_sum,
  sum(z.lag_q) as lag_sq,
  sum(z.util_pp) as util_sum,
  sum(case when z.util_pp is null then 0 else 1 end) as util_n,
  min(z.fmi_a) as fm_intake_days_a,
  min(z.fmi_b) as fm_intake_days_b,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end as iv,
    sum(cast(1 as bigint)) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fma,
    sum(cast(case when b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmb,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmab,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end as bigint)) as ev_obs_fmab_inc,
    sum(cast(case when a.visit_clear_period = 1 and b.visit_clear_period = 1 then 1 else 0 end as bigint)) as ev_obs_clear,
    sum(cast(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end as bigint)) as ev_obs_same_visit,
    max(case when a.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fma,
    max(case when b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmb,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmab,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end) as hp_pers_fmab_inc,
    max(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end) as hp_pers_same_visit,
    sum(cast(b.start_bucket - a.start_bucket as bigint)) as lag_s,
    sum(abs(cast(b.start_bucket - a.start_bucket as bigint))) as lag_a,
    sum(cast(b.start_bucket - a.start_bucket as bigint) * cast(b.start_bucket - a.start_bucket as bigint)) as lag_q,
    max(coalesce(a.util_score, b.util_score)) as util_pp,
    min(case when a.concept_fm_flag = 1 then a.fm_days_from_intake else null end) as fmi_a,
    min(case when b.concept_fm_flag = 1 then b.fm_days_from_intake else null end) as fmi_b
  from @results_database_schema.cab_s04_device a
    inner join @results_database_schema.cab_s07_measurement b on a.person_id = b.person_id and b.start_bucket - a.start_bucket between -@window_days and @window_days
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end
) z
where z.iv is not null
group by z.ca, z.cb, z.iv
)
insert into @results_database_schema.cab_s30_cum
select
  @batch_number as batch_number,
  3061 as pair_type,
  1 as anchor_code,
  a.iv as interval_code,
  a.ca as concept_a,
  a.cb as concept_b,
  a.obs,
  a.obs_fma,
  a.obs_fmb,
  a.obs_fmab,
  a.obs_fmab_inc,
  a.obs_clear,
  a.obs_same_visit,
  a.obs_sq,
  a.pers,
  a.pers_fma,
  a.pers_fmb,
  a.pers_fmab,
  a.pers_fmab_inc,
  a.pers_same_visit,
  a.lag_sum,
  a.lag_abs_sum,
  a.lag_sq,
  a.util_sum,
  a.util_n,
  a.fm_intake_days_a,
  a.fm_intake_days_b
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s30_cum' as table_name, 24 as step, @now_expr as step_datetime;

-- 4051 anchor 1 -- all anchors, near intervals
with w as ( -- aggregate per interval, then threshold on the PAIR total: an
-- interval is smallest exactly when a relationship is strongest, so it must
-- never be filtered away on its own
select
  z.ca,
  z.cb,
  z.iv,
  sum(z.ev_obs) as obs,
  sum(z.ev_obs_fma) as obs_fma,
  sum(z.ev_obs_fmb) as obs_fmb,
  sum(z.ev_obs_fmab) as obs_fmab,
  sum(z.ev_obs_fmab_inc) as obs_fmab_inc,
  sum(z.ev_obs_clear) as obs_clear,
  sum(z.ev_obs_same_visit) as obs_same_visit,
  sum(z.ev_obs * z.ev_obs) as obs_sq,
  count(*) as pers,
  sum(z.hp_pers_fma) as pers_fma,
  sum(z.hp_pers_fmb) as pers_fmb,
  sum(z.hp_pers_fmab) as pers_fmab,
  sum(z.hp_pers_fmab_inc) as pers_fmab_inc,
  sum(z.hp_pers_same_visit) as pers_same_visit,
  sum(z.lag_s) as lag_sum,
  sum(z.lag_a) as lag_abs_sum,
  sum(z.lag_q) as lag_sq,
  sum(z.util_pp) as util_sum,
  sum(case when z.util_pp is null then 0 else 1 end) as util_n,
  min(z.fmi_a) as fm_intake_days_a,
  min(z.fmi_b) as fm_intake_days_b,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end as iv,
    sum(cast(1 as bigint)) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fma,
    sum(cast(case when b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmb,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmab,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end as bigint)) as ev_obs_fmab_inc,
    sum(cast(case when a.visit_clear_period = 1 and b.visit_clear_period = 1 then 1 else 0 end as bigint)) as ev_obs_clear,
    sum(cast(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end as bigint)) as ev_obs_same_visit,
    max(case when a.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fma,
    max(case when b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmb,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmab,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end) as hp_pers_fmab_inc,
    max(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end) as hp_pers_same_visit,
    sum(cast(b.start_bucket - a.start_bucket as bigint)) as lag_s,
    sum(abs(cast(b.start_bucket - a.start_bucket as bigint))) as lag_a,
    sum(cast(b.start_bucket - a.start_bucket as bigint) * cast(b.start_bucket - a.start_bucket as bigint)) as lag_q,
    max(coalesce(a.util_score, b.util_score)) as util_pp,
    min(case when a.concept_fm_flag = 1 then a.fm_days_from_intake else null end) as fmi_a,
    min(case when b.concept_fm_flag = 1 then b.fm_days_from_intake else null end) as fmi_b
  from @results_database_schema.cab_s05_drug a
    inner join @results_database_schema.cab_s06_observation b on a.person_id = b.person_id and b.start_bucket - a.start_bucket between -@window_days and @window_days
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end
) z
where z.iv is not null
group by z.ca, z.cb, z.iv
)
insert into @results_database_schema.cab_s30_cum
select
  @batch_number as batch_number,
  4051 as pair_type,
  1 as anchor_code,
  a.iv as interval_code,
  a.ca as concept_a,
  a.cb as concept_b,
  a.obs,
  a.obs_fma,
  a.obs_fmb,
  a.obs_fmab,
  a.obs_fmab_inc,
  a.obs_clear,
  a.obs_same_visit,
  a.obs_sq,
  a.pers,
  a.pers_fma,
  a.pers_fmb,
  a.pers_fmab,
  a.pers_fmab_inc,
  a.pers_same_visit,
  a.lag_sum,
  a.lag_abs_sum,
  a.lag_sq,
  a.util_sum,
  a.util_n,
  a.fm_intake_days_a,
  a.fm_intake_days_b
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s30_cum' as table_name, 25 as step, @now_expr as step_datetime;

-- 4061 anchor 1 -- all anchors, near intervals
with w as ( -- aggregate per interval, then threshold on the PAIR total: an
-- interval is smallest exactly when a relationship is strongest, so it must
-- never be filtered away on its own
select
  z.ca,
  z.cb,
  z.iv,
  sum(z.ev_obs) as obs,
  sum(z.ev_obs_fma) as obs_fma,
  sum(z.ev_obs_fmb) as obs_fmb,
  sum(z.ev_obs_fmab) as obs_fmab,
  sum(z.ev_obs_fmab_inc) as obs_fmab_inc,
  sum(z.ev_obs_clear) as obs_clear,
  sum(z.ev_obs_same_visit) as obs_same_visit,
  sum(z.ev_obs * z.ev_obs) as obs_sq,
  count(*) as pers,
  sum(z.hp_pers_fma) as pers_fma,
  sum(z.hp_pers_fmb) as pers_fmb,
  sum(z.hp_pers_fmab) as pers_fmab,
  sum(z.hp_pers_fmab_inc) as pers_fmab_inc,
  sum(z.hp_pers_same_visit) as pers_same_visit,
  sum(z.lag_s) as lag_sum,
  sum(z.lag_a) as lag_abs_sum,
  sum(z.lag_q) as lag_sq,
  sum(z.util_pp) as util_sum,
  sum(case when z.util_pp is null then 0 else 1 end) as util_n,
  min(z.fmi_a) as fm_intake_days_a,
  min(z.fmi_b) as fm_intake_days_b,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end as iv,
    sum(cast(1 as bigint)) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fma,
    sum(cast(case when b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmb,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmab,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end as bigint)) as ev_obs_fmab_inc,
    sum(cast(case when a.visit_clear_period = 1 and b.visit_clear_period = 1 then 1 else 0 end as bigint)) as ev_obs_clear,
    sum(cast(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end as bigint)) as ev_obs_same_visit,
    max(case when a.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fma,
    max(case when b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmb,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmab,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end) as hp_pers_fmab_inc,
    max(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end) as hp_pers_same_visit,
    sum(cast(b.start_bucket - a.start_bucket as bigint)) as lag_s,
    sum(abs(cast(b.start_bucket - a.start_bucket as bigint))) as lag_a,
    sum(cast(b.start_bucket - a.start_bucket as bigint) * cast(b.start_bucket - a.start_bucket as bigint)) as lag_q,
    max(coalesce(a.util_score, b.util_score)) as util_pp,
    min(case when a.concept_fm_flag = 1 then a.fm_days_from_intake else null end) as fmi_a,
    min(case when b.concept_fm_flag = 1 then b.fm_days_from_intake else null end) as fmi_b
  from @results_database_schema.cab_s05_drug a
    inner join @results_database_schema.cab_s07_measurement b on a.person_id = b.person_id and b.start_bucket - a.start_bucket between -@window_days and @window_days
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
    end
) z
where z.iv is not null
group by z.ca, z.cb, z.iv
)
insert into @results_database_schema.cab_s30_cum
select
  @batch_number as batch_number,
  4061 as pair_type,
  1 as anchor_code,
  a.iv as interval_code,
  a.ca as concept_a,
  a.cb as concept_b,
  a.obs,
  a.obs_fma,
  a.obs_fmb,
  a.obs_fmab,
  a.obs_fmab_inc,
  a.obs_clear,
  a.obs_same_visit,
  a.obs_sq,
  a.pers,
  a.pers_fma,
  a.pers_fmb,
  a.pers_fmab,
  a.pers_fmab_inc,
  a.pers_same_visit,
  a.lag_sum,
  a.lag_abs_sum,
  a.lag_sq,
  a.util_sum,
  a.util_n,
  a.fm_intake_days_a,
  a.fm_intake_days_b
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s30_cum' as table_name, 26 as step, @now_expr as step_datetime;

-- 2010 anchor 2 -- trigger anchors
with w as ( -- aggregate per interval, then threshold on the PAIR total: an
-- interval is smallest exactly when a relationship is strongest, so it must
-- never be filtered away on its own
select
  z.ca,
  z.cb,
  z.iv,
  sum(z.ev_obs) as obs,
  sum(z.ev_obs_fma) as obs_fma,
  sum(z.ev_obs_fmb) as obs_fmb,
  sum(z.ev_obs_fmab) as obs_fmab,
  sum(z.ev_obs_fmab_inc) as obs_fmab_inc,
  sum(z.ev_obs_clear) as obs_clear,
  sum(z.ev_obs_same_visit) as obs_same_visit,
  sum(z.ev_obs * z.ev_obs) as obs_sq,
  count(*) as pers,
  sum(z.hp_pers_fma) as pers_fma,
  sum(z.hp_pers_fmb) as pers_fmb,
  sum(z.hp_pers_fmab) as pers_fmab,
  sum(z.hp_pers_fmab_inc) as pers_fmab_inc,
  sum(z.hp_pers_same_visit) as pers_same_visit,
  sum(z.lag_s) as lag_sum,
  sum(z.lag_a) as lag_abs_sum,
  sum(z.lag_q) as lag_sq,
  sum(z.util_pp) as util_sum,
  sum(case when z.util_pp is null then 0 else 1 end) as util_n,
  min(z.fmi_a) as fm_intake_days_a,
  min(z.fmi_b) as fm_intake_days_b,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
      when b.start_bucket - a.start_bucket between @window_days + 1 and 2 * @window_days then 6
    end as iv,
    sum(cast(1 as bigint)) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fma,
    sum(cast(case when b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmb,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmab,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end as bigint)) as ev_obs_fmab_inc,
    sum(cast(case when a.visit_clear_period = 1 and b.visit_clear_period = 1 then 1 else 0 end as bigint)) as ev_obs_clear,
    sum(cast(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end as bigint)) as ev_obs_same_visit,
    max(case when a.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fma,
    max(case when b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmb,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmab,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end) as hp_pers_fmab_inc,
    max(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end) as hp_pers_same_visit,
    sum(cast(b.start_bucket - a.start_bucket as bigint)) as lag_s,
    sum(abs(cast(b.start_bucket - a.start_bucket as bigint))) as lag_a,
    sum(cast(b.start_bucket - a.start_bucket as bigint) * cast(b.start_bucket - a.start_bucket as bigint)) as lag_q,
    max(coalesce(a.util_score, b.util_score)) as util_pp,
    min(case when a.concept_fm_flag = 1 then a.fm_days_from_intake else null end) as fmi_a,
    min(case when b.concept_fm_flag = 1 then b.fm_days_from_intake else null end) as fmi_b
  from @results_database_schema.cab_s03_procedure a
    inner join @results_database_schema.cab_s02_condition b on a.person_id = b.person_id and b.start_bucket - a.start_bucket between -@window_days and 2 * @window_days
  where a.trigger_flag = 1
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
      when b.start_bucket - a.start_bucket between @window_days + 1 and 2 * @window_days then 6
    end
) z
where z.iv is not null
group by z.ca, z.cb, z.iv
)
insert into @results_database_schema.cab_s30_cum
select
  @batch_number as batch_number,
  2010 as pair_type,
  2 as anchor_code,
  a.iv as interval_code,
  a.ca as concept_a,
  a.cb as concept_b,
  a.obs,
  a.obs_fma,
  a.obs_fmb,
  a.obs_fmab,
  a.obs_fmab_inc,
  a.obs_clear,
  a.obs_same_visit,
  a.obs_sq,
  a.pers,
  a.pers_fma,
  a.pers_fmb,
  a.pers_fmab,
  a.pers_fmab_inc,
  a.pers_same_visit,
  a.lag_sum,
  a.lag_abs_sum,
  a.lag_sq,
  a.util_sum,
  a.util_n,
  a.fm_intake_days_a,
  a.fm_intake_days_b
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s30_cum' as table_name, 27 as step, @now_expr as step_datetime;

-- 2020 anchor 2 -- trigger anchors
with w as ( -- aggregate per interval, then threshold on the PAIR total: an
-- interval is smallest exactly when a relationship is strongest, so it must
-- never be filtered away on its own
select
  z.ca,
  z.cb,
  z.iv,
  sum(z.ev_obs) as obs,
  sum(z.ev_obs_fma) as obs_fma,
  sum(z.ev_obs_fmb) as obs_fmb,
  sum(z.ev_obs_fmab) as obs_fmab,
  sum(z.ev_obs_fmab_inc) as obs_fmab_inc,
  sum(z.ev_obs_clear) as obs_clear,
  sum(z.ev_obs_same_visit) as obs_same_visit,
  sum(z.ev_obs * z.ev_obs) as obs_sq,
  count(*) as pers,
  sum(z.hp_pers_fma) as pers_fma,
  sum(z.hp_pers_fmb) as pers_fmb,
  sum(z.hp_pers_fmab) as pers_fmab,
  sum(z.hp_pers_fmab_inc) as pers_fmab_inc,
  sum(z.hp_pers_same_visit) as pers_same_visit,
  sum(z.lag_s) as lag_sum,
  sum(z.lag_a) as lag_abs_sum,
  sum(z.lag_q) as lag_sq,
  sum(z.util_pp) as util_sum,
  sum(case when z.util_pp is null then 0 else 1 end) as util_n,
  min(z.fmi_a) as fm_intake_days_a,
  min(z.fmi_b) as fm_intake_days_b,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
      when b.start_bucket - a.start_bucket between @window_days + 1 and 2 * @window_days then 6
    end as iv,
    sum(cast(1 as bigint)) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fma,
    sum(cast(case when b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmb,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmab,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end as bigint)) as ev_obs_fmab_inc,
    sum(cast(case when a.visit_clear_period = 1 and b.visit_clear_period = 1 then 1 else 0 end as bigint)) as ev_obs_clear,
    sum(cast(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end as bigint)) as ev_obs_same_visit,
    max(case when a.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fma,
    max(case when b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmb,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmab,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end) as hp_pers_fmab_inc,
    max(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end) as hp_pers_same_visit,
    sum(cast(b.start_bucket - a.start_bucket as bigint)) as lag_s,
    sum(abs(cast(b.start_bucket - a.start_bucket as bigint))) as lag_a,
    sum(cast(b.start_bucket - a.start_bucket as bigint) * cast(b.start_bucket - a.start_bucket as bigint)) as lag_q,
    max(coalesce(a.util_score, b.util_score)) as util_pp,
    min(case when a.concept_fm_flag = 1 then a.fm_days_from_intake else null end) as fmi_a,
    min(case when b.concept_fm_flag = 1 then b.fm_days_from_intake else null end) as fmi_b
  from @results_database_schema.cab_s03_procedure a
    inner join @results_database_schema.cab_s03_procedure b on a.person_id = b.person_id and b.start_bucket - a.start_bucket between -@window_days and 2 * @window_days
     and a.concept_id <> b.concept_id
  where a.trigger_flag = 1
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
      when b.start_bucket - a.start_bucket between @window_days + 1 and 2 * @window_days then 6
    end
) z
where z.iv is not null
group by z.ca, z.cb, z.iv
)
insert into @results_database_schema.cab_s30_cum
select
  @batch_number as batch_number,
  2020 as pair_type,
  2 as anchor_code,
  a.iv as interval_code,
  a.ca as concept_a,
  a.cb as concept_b,
  a.obs,
  a.obs_fma,
  a.obs_fmb,
  a.obs_fmab,
  a.obs_fmab_inc,
  a.obs_clear,
  a.obs_same_visit,
  a.obs_sq,
  a.pers,
  a.pers_fma,
  a.pers_fmb,
  a.pers_fmab,
  a.pers_fmab_inc,
  a.pers_same_visit,
  a.lag_sum,
  a.lag_abs_sum,
  a.lag_sq,
  a.util_sum,
  a.util_n,
  a.fm_intake_days_a,
  a.fm_intake_days_b
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s30_cum' as table_name, 28 as step, @now_expr as step_datetime;

-- 2030 anchor 2 -- trigger anchors
with w as ( -- aggregate per interval, then threshold on the PAIR total: an
-- interval is smallest exactly when a relationship is strongest, so it must
-- never be filtered away on its own
select
  z.ca,
  z.cb,
  z.iv,
  sum(z.ev_obs) as obs,
  sum(z.ev_obs_fma) as obs_fma,
  sum(z.ev_obs_fmb) as obs_fmb,
  sum(z.ev_obs_fmab) as obs_fmab,
  sum(z.ev_obs_fmab_inc) as obs_fmab_inc,
  sum(z.ev_obs_clear) as obs_clear,
  sum(z.ev_obs_same_visit) as obs_same_visit,
  sum(z.ev_obs * z.ev_obs) as obs_sq,
  count(*) as pers,
  sum(z.hp_pers_fma) as pers_fma,
  sum(z.hp_pers_fmb) as pers_fmb,
  sum(z.hp_pers_fmab) as pers_fmab,
  sum(z.hp_pers_fmab_inc) as pers_fmab_inc,
  sum(z.hp_pers_same_visit) as pers_same_visit,
  sum(z.lag_s) as lag_sum,
  sum(z.lag_a) as lag_abs_sum,
  sum(z.lag_q) as lag_sq,
  sum(z.util_pp) as util_sum,
  sum(case when z.util_pp is null then 0 else 1 end) as util_n,
  min(z.fmi_a) as fm_intake_days_a,
  min(z.fmi_b) as fm_intake_days_b,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
      when b.start_bucket - a.start_bucket between @window_days + 1 and 2 * @window_days then 6
    end as iv,
    sum(cast(1 as bigint)) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fma,
    sum(cast(case when b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmb,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmab,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end as bigint)) as ev_obs_fmab_inc,
    sum(cast(case when a.visit_clear_period = 1 and b.visit_clear_period = 1 then 1 else 0 end as bigint)) as ev_obs_clear,
    sum(cast(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end as bigint)) as ev_obs_same_visit,
    max(case when a.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fma,
    max(case when b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmb,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmab,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end) as hp_pers_fmab_inc,
    max(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end) as hp_pers_same_visit,
    sum(cast(b.start_bucket - a.start_bucket as bigint)) as lag_s,
    sum(abs(cast(b.start_bucket - a.start_bucket as bigint))) as lag_a,
    sum(cast(b.start_bucket - a.start_bucket as bigint) * cast(b.start_bucket - a.start_bucket as bigint)) as lag_q,
    max(coalesce(a.util_score, b.util_score)) as util_pp,
    min(case when a.concept_fm_flag = 1 then a.fm_days_from_intake else null end) as fmi_a,
    min(case when b.concept_fm_flag = 1 then b.fm_days_from_intake else null end) as fmi_b
  from @results_database_schema.cab_s03_procedure a
    inner join @results_database_schema.cab_s04_device b on a.person_id = b.person_id and b.start_bucket - a.start_bucket between -@window_days and 2 * @window_days
  where a.trigger_flag = 1
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
      when b.start_bucket - a.start_bucket between @window_days + 1 and 2 * @window_days then 6
    end
) z
where z.iv is not null
group by z.ca, z.cb, z.iv
)
insert into @results_database_schema.cab_s30_cum
select
  @batch_number as batch_number,
  2030 as pair_type,
  2 as anchor_code,
  a.iv as interval_code,
  a.ca as concept_a,
  a.cb as concept_b,
  a.obs,
  a.obs_fma,
  a.obs_fmb,
  a.obs_fmab,
  a.obs_fmab_inc,
  a.obs_clear,
  a.obs_same_visit,
  a.obs_sq,
  a.pers,
  a.pers_fma,
  a.pers_fmb,
  a.pers_fmab,
  a.pers_fmab_inc,
  a.pers_same_visit,
  a.lag_sum,
  a.lag_abs_sum,
  a.lag_sq,
  a.util_sum,
  a.util_n,
  a.fm_intake_days_a,
  a.fm_intake_days_b
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s30_cum' as table_name, 29 as step, @now_expr as step_datetime;

-- 2040 anchor 2 -- trigger anchors
with w as ( -- aggregate per interval, then threshold on the PAIR total: an
-- interval is smallest exactly when a relationship is strongest, so it must
-- never be filtered away on its own
select
  z.ca,
  z.cb,
  z.iv,
  sum(z.ev_obs) as obs,
  sum(z.ev_obs_fma) as obs_fma,
  sum(z.ev_obs_fmb) as obs_fmb,
  sum(z.ev_obs_fmab) as obs_fmab,
  sum(z.ev_obs_fmab_inc) as obs_fmab_inc,
  sum(z.ev_obs_clear) as obs_clear,
  sum(z.ev_obs_same_visit) as obs_same_visit,
  sum(z.ev_obs * z.ev_obs) as obs_sq,
  count(*) as pers,
  sum(z.hp_pers_fma) as pers_fma,
  sum(z.hp_pers_fmb) as pers_fmb,
  sum(z.hp_pers_fmab) as pers_fmab,
  sum(z.hp_pers_fmab_inc) as pers_fmab_inc,
  sum(z.hp_pers_same_visit) as pers_same_visit,
  sum(z.lag_s) as lag_sum,
  sum(z.lag_a) as lag_abs_sum,
  sum(z.lag_q) as lag_sq,
  sum(z.util_pp) as util_sum,
  sum(case when z.util_pp is null then 0 else 1 end) as util_n,
  min(z.fmi_a) as fm_intake_days_a,
  min(z.fmi_b) as fm_intake_days_b,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
      when b.start_bucket - a.start_bucket between @window_days + 1 and 2 * @window_days then 6
    end as iv,
    sum(cast(1 as bigint)) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fma,
    sum(cast(case when b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmb,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmab,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end as bigint)) as ev_obs_fmab_inc,
    sum(cast(case when a.visit_clear_period = 1 and b.visit_clear_period = 1 then 1 else 0 end as bigint)) as ev_obs_clear,
    sum(cast(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end as bigint)) as ev_obs_same_visit,
    max(case when a.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fma,
    max(case when b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmb,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmab,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end) as hp_pers_fmab_inc,
    max(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end) as hp_pers_same_visit,
    sum(cast(b.start_bucket - a.start_bucket as bigint)) as lag_s,
    sum(abs(cast(b.start_bucket - a.start_bucket as bigint))) as lag_a,
    sum(cast(b.start_bucket - a.start_bucket as bigint) * cast(b.start_bucket - a.start_bucket as bigint)) as lag_q,
    max(coalesce(a.util_score, b.util_score)) as util_pp,
    min(case when a.concept_fm_flag = 1 then a.fm_days_from_intake else null end) as fmi_a,
    min(case when b.concept_fm_flag = 1 then b.fm_days_from_intake else null end) as fmi_b
  from @results_database_schema.cab_s03_procedure a
    inner join @results_database_schema.cab_s05_drug b on a.person_id = b.person_id and b.start_bucket - a.start_bucket between -@window_days and 2 * @window_days
  where a.trigger_flag = 1
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    case
      when b.start_bucket - a.start_bucket = 0 then 1
      when b.start_bucket - a.start_bucket between 1 and @window_days then 2
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 3
      when b.start_bucket - a.start_bucket between @window_days + 1 and 2 * @window_days then 6
    end
) z
where z.iv is not null
group by z.ca, z.cb, z.iv
)
insert into @results_database_schema.cab_s30_cum
select
  @batch_number as batch_number,
  2040 as pair_type,
  2 as anchor_code,
  a.iv as interval_code,
  a.ca as concept_a,
  a.cb as concept_b,
  a.obs,
  a.obs_fma,
  a.obs_fmb,
  a.obs_fmab,
  a.obs_fmab_inc,
  a.obs_clear,
  a.obs_same_visit,
  a.obs_sq,
  a.pers,
  a.pers_fma,
  a.pers_fmb,
  a.pers_fmab,
  a.pers_fmab_inc,
  a.pers_same_visit,
  a.lag_sum,
  a.lag_abs_sum,
  a.lag_sq,
  a.util_sum,
  a.util_n,
  a.fm_intake_days_a,
  a.fm_intake_days_b
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s30_cum' as table_name, 30 as step, @now_expr as step_datetime;














-- =========================================================
-- CHRONIC-CONDITION ONSET COHORT  (src 11, anchor 4)
--
-- The +/-@window_days window asks whether A and B occurred close together. For
-- a chronic condition that is the wrong question: it is a state, not an event.
-- At IU a condition concept is recorded 2.55 times per person on average across
-- years, so a complication 120 days after diagnosis falls within @window_days
-- of nothing and is counted nowhere.
--
-- The anchor here is a PERIOD -- first mention of the chronic condition to the
-- end of observation -- and the expected comes from person-days at risk rather
-- than a window width. The denominator is the anchor 4 rows in
-- cab_s20_marginal_cum. Observed over expected per interval is a hazard curve:
-- elevated early and falling is treatment, flat and elevated is ongoing
-- management, rising is a complication.
--
-- Intervals, each @window_days wide: 9 = before first mention, 10 = onset day,
-- 11..20 = bands 1..10 after, out to +10*@window_days.
--
-- A is chronic and first-mention only. B is every concept in its domain,
-- chronic or not, since a sequela can be a finding or a disorder. Measurement
-- is excluded: a chronic condition raises the rate of nearly every lab because
-- those patients are monitored.
--
-- src 10 is unchanged and still contains every condition including chronic
-- ones. src 11 is purely additive.
-- =========================================================

-- 1110 anchor 4 -- chronic condition onset, B per interval after first mention
with w as ( -- aggregate per interval, then threshold on the PAIR total: an
-- interval is smallest exactly when a relationship is strongest, so it must
-- never be filtered away on its own
select
  z.ca,
  z.cb,
  z.iv,
  sum(z.ev_obs) as obs,
  sum(z.ev_obs_fma) as obs_fma,
  sum(z.ev_obs_fmb) as obs_fmb,
  sum(z.ev_obs_fmab) as obs_fmab,
  sum(z.ev_obs_fmab_inc) as obs_fmab_inc,
  sum(z.ev_obs_clear) as obs_clear,
  sum(z.ev_obs_same_visit) as obs_same_visit,
  sum(z.ev_obs * z.ev_obs) as obs_sq,
  count(*) as pers,
  sum(z.hp_pers_fma) as pers_fma,
  sum(z.hp_pers_fmb) as pers_fmb,
  sum(z.hp_pers_fmab) as pers_fmab,
  sum(z.hp_pers_fmab_inc) as pers_fmab_inc,
  sum(z.hp_pers_same_visit) as pers_same_visit,
  sum(z.lag_s) as lag_sum,
  sum(z.lag_a) as lag_abs_sum,
  sum(z.lag_q) as lag_sq,
  sum(z.util_pp) as util_sum,
  sum(case when z.util_pp is null then 0 else 1 end) as util_n,
  min(z.fmi_a) as fm_intake_days_a,
  min(z.fmi_b) as fm_intake_days_b,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    case
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 9
      when b.start_bucket - a.start_bucket = 0 then 10
      else 11 + (b.start_bucket - a.start_bucket - 1) / @window_days
    end as iv,
    sum(cast(1 as bigint)) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fma,
    sum(cast(case when b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmb,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmab,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end as bigint)) as ev_obs_fmab_inc,
    sum(cast(case when a.visit_clear_period = 1 and b.visit_clear_period = 1 then 1 else 0 end as bigint)) as ev_obs_clear,
    sum(cast(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end as bigint)) as ev_obs_same_visit,
    max(case when a.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fma,
    max(case when b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmb,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmab,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end) as hp_pers_fmab_inc,
    max(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end) as hp_pers_same_visit,
    sum(cast(b.start_bucket - a.start_bucket as bigint)) as lag_s,
    sum(abs(cast(b.start_bucket - a.start_bucket as bigint))) as lag_a,
    sum(cast(b.start_bucket - a.start_bucket as bigint) * cast(b.start_bucket - a.start_bucket as bigint)) as lag_q,
    max(coalesce(a.util_score, b.util_score)) as util_pp,
    min(case when a.concept_fm_flag = 1 then a.fm_days_from_intake else null end) as fmi_a,
    min(case when b.concept_fm_flag = 1 then b.fm_days_from_intake else null end) as fmi_b
  from @results_database_schema.cab_s02_condition a
    inner join @results_database_schema.cab_s02_condition b on a.person_id = b.person_id and b.start_bucket - a.start_bucket between -@window_days and 10 * @window_days
     and a.concept_id <> b.concept_id
  where a.chronic_flag = 1
    and a.concept_fm_flag = 1
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    case
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 9
      when b.start_bucket - a.start_bucket = 0 then 10
      else 11 + (b.start_bucket - a.start_bucket - 1) / @window_days
    end
) z
where z.iv is not null
group by z.ca, z.cb, z.iv
)
insert into @results_database_schema.cab_s30_cum
select
  @batch_number as batch_number,
  1110 as pair_type,
  4 as anchor_code,
  a.iv as interval_code,
  a.ca as concept_a,
  a.cb as concept_b,
  a.obs,
  a.obs_fma,
  a.obs_fmb,
  a.obs_fmab,
  a.obs_fmab_inc,
  a.obs_clear,
  a.obs_same_visit,
  a.obs_sq,
  a.pers,
  a.pers_fma,
  a.pers_fmb,
  a.pers_fmab,
  a.pers_fmab_inc,
  a.pers_same_visit,
  a.lag_sum,
  a.lag_abs_sum,
  a.lag_sq,
  a.util_sum,
  a.util_n,
  a.fm_intake_days_a,
  a.fm_intake_days_b
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s30_cum' as table_name, 43 as step, @now_expr as step_datetime;

-- 1120 anchor 4 -- chronic condition onset, B per interval after first mention
with w as ( -- aggregate per interval, then threshold on the PAIR total: an
-- interval is smallest exactly when a relationship is strongest, so it must
-- never be filtered away on its own
select
  z.ca,
  z.cb,
  z.iv,
  sum(z.ev_obs) as obs,
  sum(z.ev_obs_fma) as obs_fma,
  sum(z.ev_obs_fmb) as obs_fmb,
  sum(z.ev_obs_fmab) as obs_fmab,
  sum(z.ev_obs_fmab_inc) as obs_fmab_inc,
  sum(z.ev_obs_clear) as obs_clear,
  sum(z.ev_obs_same_visit) as obs_same_visit,
  sum(z.ev_obs * z.ev_obs) as obs_sq,
  count(*) as pers,
  sum(z.hp_pers_fma) as pers_fma,
  sum(z.hp_pers_fmb) as pers_fmb,
  sum(z.hp_pers_fmab) as pers_fmab,
  sum(z.hp_pers_fmab_inc) as pers_fmab_inc,
  sum(z.hp_pers_same_visit) as pers_same_visit,
  sum(z.lag_s) as lag_sum,
  sum(z.lag_a) as lag_abs_sum,
  sum(z.lag_q) as lag_sq,
  sum(z.util_pp) as util_sum,
  sum(case when z.util_pp is null then 0 else 1 end) as util_n,
  min(z.fmi_a) as fm_intake_days_a,
  min(z.fmi_b) as fm_intake_days_b,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    case
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 9
      when b.start_bucket - a.start_bucket = 0 then 10
      else 11 + (b.start_bucket - a.start_bucket - 1) / @window_days
    end as iv,
    sum(cast(1 as bigint)) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fma,
    sum(cast(case when b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmb,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmab,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end as bigint)) as ev_obs_fmab_inc,
    sum(cast(case when a.visit_clear_period = 1 and b.visit_clear_period = 1 then 1 else 0 end as bigint)) as ev_obs_clear,
    sum(cast(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end as bigint)) as ev_obs_same_visit,
    max(case when a.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fma,
    max(case when b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmb,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmab,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end) as hp_pers_fmab_inc,
    max(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end) as hp_pers_same_visit,
    sum(cast(b.start_bucket - a.start_bucket as bigint)) as lag_s,
    sum(abs(cast(b.start_bucket - a.start_bucket as bigint))) as lag_a,
    sum(cast(b.start_bucket - a.start_bucket as bigint) * cast(b.start_bucket - a.start_bucket as bigint)) as lag_q,
    max(coalesce(a.util_score, b.util_score)) as util_pp,
    min(case when a.concept_fm_flag = 1 then a.fm_days_from_intake else null end) as fmi_a,
    min(case when b.concept_fm_flag = 1 then b.fm_days_from_intake else null end) as fmi_b
  from @results_database_schema.cab_s02_condition a
    inner join @results_database_schema.cab_s03_procedure b on a.person_id = b.person_id and b.start_bucket - a.start_bucket between -@window_days and 10 * @window_days
  where a.chronic_flag = 1
    and a.concept_fm_flag = 1
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    case
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 9
      when b.start_bucket - a.start_bucket = 0 then 10
      else 11 + (b.start_bucket - a.start_bucket - 1) / @window_days
    end
) z
where z.iv is not null
group by z.ca, z.cb, z.iv
)
insert into @results_database_schema.cab_s30_cum
select
  @batch_number as batch_number,
  1120 as pair_type,
  4 as anchor_code,
  a.iv as interval_code,
  a.ca as concept_a,
  a.cb as concept_b,
  a.obs,
  a.obs_fma,
  a.obs_fmb,
  a.obs_fmab,
  a.obs_fmab_inc,
  a.obs_clear,
  a.obs_same_visit,
  a.obs_sq,
  a.pers,
  a.pers_fma,
  a.pers_fmb,
  a.pers_fmab,
  a.pers_fmab_inc,
  a.pers_same_visit,
  a.lag_sum,
  a.lag_abs_sum,
  a.lag_sq,
  a.util_sum,
  a.util_n,
  a.fm_intake_days_a,
  a.fm_intake_days_b
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s30_cum' as table_name, 44 as step, @now_expr as step_datetime;

-- 1130 anchor 4 -- chronic condition onset, B per interval after first mention
with w as ( -- aggregate per interval, then threshold on the PAIR total: an
-- interval is smallest exactly when a relationship is strongest, so it must
-- never be filtered away on its own
select
  z.ca,
  z.cb,
  z.iv,
  sum(z.ev_obs) as obs,
  sum(z.ev_obs_fma) as obs_fma,
  sum(z.ev_obs_fmb) as obs_fmb,
  sum(z.ev_obs_fmab) as obs_fmab,
  sum(z.ev_obs_fmab_inc) as obs_fmab_inc,
  sum(z.ev_obs_clear) as obs_clear,
  sum(z.ev_obs_same_visit) as obs_same_visit,
  sum(z.ev_obs * z.ev_obs) as obs_sq,
  count(*) as pers,
  sum(z.hp_pers_fma) as pers_fma,
  sum(z.hp_pers_fmb) as pers_fmb,
  sum(z.hp_pers_fmab) as pers_fmab,
  sum(z.hp_pers_fmab_inc) as pers_fmab_inc,
  sum(z.hp_pers_same_visit) as pers_same_visit,
  sum(z.lag_s) as lag_sum,
  sum(z.lag_a) as lag_abs_sum,
  sum(z.lag_q) as lag_sq,
  sum(z.util_pp) as util_sum,
  sum(case when z.util_pp is null then 0 else 1 end) as util_n,
  min(z.fmi_a) as fm_intake_days_a,
  min(z.fmi_b) as fm_intake_days_b,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    case
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 9
      when b.start_bucket - a.start_bucket = 0 then 10
      else 11 + (b.start_bucket - a.start_bucket - 1) / @window_days
    end as iv,
    sum(cast(1 as bigint)) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fma,
    sum(cast(case when b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmb,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmab,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end as bigint)) as ev_obs_fmab_inc,
    sum(cast(case when a.visit_clear_period = 1 and b.visit_clear_period = 1 then 1 else 0 end as bigint)) as ev_obs_clear,
    sum(cast(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end as bigint)) as ev_obs_same_visit,
    max(case when a.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fma,
    max(case when b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmb,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmab,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end) as hp_pers_fmab_inc,
    max(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end) as hp_pers_same_visit,
    sum(cast(b.start_bucket - a.start_bucket as bigint)) as lag_s,
    sum(abs(cast(b.start_bucket - a.start_bucket as bigint))) as lag_a,
    sum(cast(b.start_bucket - a.start_bucket as bigint) * cast(b.start_bucket - a.start_bucket as bigint)) as lag_q,
    max(coalesce(a.util_score, b.util_score)) as util_pp,
    min(case when a.concept_fm_flag = 1 then a.fm_days_from_intake else null end) as fmi_a,
    min(case when b.concept_fm_flag = 1 then b.fm_days_from_intake else null end) as fmi_b
  from @results_database_schema.cab_s02_condition a
    inner join @results_database_schema.cab_s04_device b on a.person_id = b.person_id and b.start_bucket - a.start_bucket between -@window_days and 10 * @window_days
  where a.chronic_flag = 1
    and a.concept_fm_flag = 1
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    case
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 9
      when b.start_bucket - a.start_bucket = 0 then 10
      else 11 + (b.start_bucket - a.start_bucket - 1) / @window_days
    end
) z
where z.iv is not null
group by z.ca, z.cb, z.iv
)
insert into @results_database_schema.cab_s30_cum
select
  @batch_number as batch_number,
  1130 as pair_type,
  4 as anchor_code,
  a.iv as interval_code,
  a.ca as concept_a,
  a.cb as concept_b,
  a.obs,
  a.obs_fma,
  a.obs_fmb,
  a.obs_fmab,
  a.obs_fmab_inc,
  a.obs_clear,
  a.obs_same_visit,
  a.obs_sq,
  a.pers,
  a.pers_fma,
  a.pers_fmb,
  a.pers_fmab,
  a.pers_fmab_inc,
  a.pers_same_visit,
  a.lag_sum,
  a.lag_abs_sum,
  a.lag_sq,
  a.util_sum,
  a.util_n,
  a.fm_intake_days_a,
  a.fm_intake_days_b
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s30_cum' as table_name, 45 as step, @now_expr as step_datetime;

-- 1140 anchor 4 -- chronic condition onset, B per interval after first mention
with w as ( -- aggregate per interval, then threshold on the PAIR total: an
-- interval is smallest exactly when a relationship is strongest, so it must
-- never be filtered away on its own
select
  z.ca,
  z.cb,
  z.iv,
  sum(z.ev_obs) as obs,
  sum(z.ev_obs_fma) as obs_fma,
  sum(z.ev_obs_fmb) as obs_fmb,
  sum(z.ev_obs_fmab) as obs_fmab,
  sum(z.ev_obs_fmab_inc) as obs_fmab_inc,
  sum(z.ev_obs_clear) as obs_clear,
  sum(z.ev_obs_same_visit) as obs_same_visit,
  sum(z.ev_obs * z.ev_obs) as obs_sq,
  count(*) as pers,
  sum(z.hp_pers_fma) as pers_fma,
  sum(z.hp_pers_fmb) as pers_fmb,
  sum(z.hp_pers_fmab) as pers_fmab,
  sum(z.hp_pers_fmab_inc) as pers_fmab_inc,
  sum(z.hp_pers_same_visit) as pers_same_visit,
  sum(z.lag_s) as lag_sum,
  sum(z.lag_a) as lag_abs_sum,
  sum(z.lag_q) as lag_sq,
  sum(z.util_pp) as util_sum,
  sum(case when z.util_pp is null then 0 else 1 end) as util_n,
  min(z.fmi_a) as fm_intake_days_a,
  min(z.fmi_b) as fm_intake_days_b,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    case
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 9
      when b.start_bucket - a.start_bucket = 0 then 10
      else 11 + (b.start_bucket - a.start_bucket - 1) / @window_days
    end as iv,
    sum(cast(1 as bigint)) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fma,
    sum(cast(case when b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmb,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_obs_fmab,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end as bigint)) as ev_obs_fmab_inc,
    sum(cast(case when a.visit_clear_period = 1 and b.visit_clear_period = 1 then 1 else 0 end as bigint)) as ev_obs_clear,
    sum(cast(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end as bigint)) as ev_obs_same_visit,
    max(case when a.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fma,
    max(case when b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmb,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end) as hp_pers_fmab,
    max(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 and a.fm_early_flag = 0 and b.fm_early_flag = 0 then 1 else 0 end) as hp_pers_fmab_inc,
    max(case when a.visit_occurrence_id = b.visit_occurrence_id and a.visit_occurrence_id > 0 then 1 else 0 end) as hp_pers_same_visit,
    sum(cast(b.start_bucket - a.start_bucket as bigint)) as lag_s,
    sum(abs(cast(b.start_bucket - a.start_bucket as bigint))) as lag_a,
    sum(cast(b.start_bucket - a.start_bucket as bigint) * cast(b.start_bucket - a.start_bucket as bigint)) as lag_q,
    max(coalesce(a.util_score, b.util_score)) as util_pp,
    min(case when a.concept_fm_flag = 1 then a.fm_days_from_intake else null end) as fmi_a,
    min(case when b.concept_fm_flag = 1 then b.fm_days_from_intake else null end) as fmi_b
  from @results_database_schema.cab_s02_condition a
    inner join @results_database_schema.cab_s05_drug b on a.person_id = b.person_id and b.start_bucket - a.start_bucket between -@window_days and 10 * @window_days
  where a.chronic_flag = 1
    and a.concept_fm_flag = 1
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    case
      when b.start_bucket - a.start_bucket between -@window_days and -1 then 9
      when b.start_bucket - a.start_bucket = 0 then 10
      else 11 + (b.start_bucket - a.start_bucket - 1) / @window_days
    end
) z
where z.iv is not null
group by z.ca, z.cb, z.iv
)
insert into @results_database_schema.cab_s30_cum
select
  @batch_number as batch_number,
  1140 as pair_type,
  4 as anchor_code,
  a.iv as interval_code,
  a.ca as concept_a,
  a.cb as concept_b,
  a.obs,
  a.obs_fma,
  a.obs_fmb,
  a.obs_fmab,
  a.obs_fmab_inc,
  a.obs_clear,
  a.obs_same_visit,
  a.obs_sq,
  a.pers,
  a.pers_fma,
  a.pers_fmb,
  a.pers_fmab,
  a.pers_fmab_inc,
  a.pers_same_visit,
  a.lag_sum,
  a.lag_abs_sum,
  a.lag_sq,
  a.util_sum,
  a.util_n,
  a.fm_intake_days_a,
  a.fm_intake_days_b
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s30_cum' as table_name, 46 as step, @now_expr as step_datetime;



-- =========================================================
-- VISIT-SETTING PAIRS  (src 01, pair types 0110 .. 0160)
--
-- Pairs the visit_concept_id a record was captured at against the record's own
-- concept. Asks: of the times this concept is recorded, how often is it in this
-- care setting rather than another. Inpatient versus outpatient versus ED is
-- information the pipeline has carried on every staging row since V50 and has
-- never used.
--
-- NO JOIN. visit_concept_id is already a column on every staging table, so each
-- block below is a group-by over a scan that already happens. This is the
-- cheapest family in the pipeline.
--
-- interval_code is 1 for every row. A visit and the record inside it are
-- simultaneous by construction, so there is no window and no lag; every pair is
-- same-day by definition.
--
-- READ THIS BEFORE USING THE OUTPUT.
--
-- The lift that finalize computes for these rows IS WRONG. Finalize applies
--     obs_a * obs_b * win_w / total_person_days
-- which asks how often two independent event streams would land within a window
-- across person-days. That question is meaningless here: the visit is not a
-- separate event that happened to occur nearby, it is where the record was
-- written. The correct expected is a share comparison over record counts,
--     obs_visit * obs_concept / obs_total
-- with no window term and record counts in place of person-days.
--
-- Everything needed to compute that correctly is captured, so the output is
-- correctable without rerunning batch:
--     obs           the pair count, in cab_s30_cum below
--     obs_concept   the concept marginal, already in cab_s20_marginal_cum
--                   under src 10..60, anchor 1, interval 0
--     obs_visit     the visit marginal, written by the block below under
--                   anchor_code 5
--     obs_total     sum of the anchor 1 marginals within that src
--
-- So the fix is a finalize-only change whenever it is made. Until then, ignore
-- obs_lift and every derived statistic on pair types 0110 through 0160.
--
-- COLUMNS THAT ARE ZERO, not null: lag_sum, lag_abs_sum, lag_sq (no lag
-- exists), obs_clear and obs_same_visit (every pair is by definition at the
-- same visit, so the flag carries no information), util_sum and util_n, and
-- the fm_intake_days columns. Zeros rather than nulls so the finalize
-- aggregations do not produce nulls that propagate.
--
-- POPULATED: obs, pers, obs_fmb, pers_fmb. The first-mention variants are
-- meaningful on the concept side -- was this the patient's first record of the
-- concept, and in which setting -- and cost nothing to carry. The A-side fm
-- columns are zero: a visit type has no first mention.
-- =========================================================

-- visit marginal: records per (visit_concept_id, src), the obs_visit term.
-- anchor_code 5 marks these as visit marginals rather than an anchor family.
-- Nothing joins to them yet; they exist so the lift can be computed later.
with s0 as ( -- -99 is the no-linked-visit sentinel. Staging carries
-- visit_concept_id straight from a left join to cab_s01_visit and leaves it
-- null when a record has no visit link -- except cab_s06_observation and
-- cab_s07_measurement, which already coalesce to -99. Using -99 here makes all
-- six consistent rather than adding a third convention, and it cannot be
-- confused with a real concept id the way 0 could: 0 is a genuine OMOP concept
-- meaning "no matching concept", which is a mapping failure, not a linkage one.
--
-- These records are kept as their own category rather than dropped. The share
-- with no usable visit is a data quality fact worth seeing and it differs by
-- source. Excluding them later is a filter; excluding them here would be
-- unrecoverable.
select
  10 as src,
  case when a.visit_concept_id > 0 then a.visit_concept_id else -99 end as visit_concept_id,
  a.person_id
from @results_database_schema.cab_s02_condition a
union all
select
  20,
  case when a.visit_concept_id > 0 then a.visit_concept_id else -99 end,
  a.person_id
from @results_database_schema.cab_s03_procedure a
union all
select
  30,
  case when a.visit_concept_id > 0 then a.visit_concept_id else -99 end,
  a.person_id
from @results_database_schema.cab_s04_device a
union all
select
  40,
  case when a.visit_concept_id > 0 then a.visit_concept_id else -99 end,
  a.person_id
from @results_database_schema.cab_s05_drug a
union all
select
  50,
  case when a.visit_concept_id > 0 then a.visit_concept_id else -99 end,
  a.person_id
from @results_database_schema.cab_s06_observation a
union all
select
  60,
  case when a.visit_concept_id > 0 then a.visit_concept_id else -99 end,
  a.person_id
from @results_database_schema.cab_s07_measurement a
)
insert into @results_database_schema.cab_s20_marginal_cum
  (batch_number, concept_id, src, anchor_code, interval_code, n_obs_batch, n_persons_batch, n_obs_fm_batch, n_persons_fm_batch, max_per_person, n_obs_sq_batch, n_obs_clear_batch, n_util_sum_batch, n_persons_fm_incident_batch, person_days_at_risk)
select
  @batch_number,
  a.visit_concept_id,
  a.src,
  5,
  0,
  cast(count(*) as bigint),
  cast(count(distinct a.person_id) as bigint),
  0,
  0,
  0,
  0,
  0,
  null,
  0,
  null
from s0 a
group by
  a.src,
  a.visit_concept_id;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s20_marginal_cum' as table_name, 11 as step, @now_expr as step_datetime;

-- 110 visit | condition
with w as (
select
  case when a.visit_concept_id > 0 then a.visit_concept_id else -99 end as ca,
  a.concept_id as cb,
  cast(count(*) as bigint) as obs,
  sum(cast(a.concept_fm_flag as bigint)) as obs_fmb,
  cast(count(distinct a.person_id) as bigint) as pers,
  cast(count(distinct case when a.concept_fm_flag = 1 then a.person_id else null end) as bigint) as pers_fmb
from @results_database_schema.cab_s02_condition a
group by
  case when a.visit_concept_id > 0 then a.visit_concept_id else -99 end,
  a.concept_id
)
insert into @results_database_schema.cab_s30_cum
select
  @batch_number as batch_number,
  110 as pair_type,
  1 as anchor_code,
  1 as interval_code,
  a.ca as concept_a,
  a.cb as concept_b,
  a.obs,
  0,
  a.obs_fmb,
  0,
  0,
  0,
  0,
  a.obs * a.obs,
  a.pers,
  0,
  a.pers_fmb,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  null,
  null
from w a
where a.obs > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s30_cum' as table_name, 31 as step, @now_expr as step_datetime;

-- 120 visit | procedure
with w as (
select
  case when a.visit_concept_id > 0 then a.visit_concept_id else -99 end as ca,
  a.concept_id as cb,
  cast(count(*) as bigint) as obs,
  sum(cast(a.concept_fm_flag as bigint)) as obs_fmb,
  cast(count(distinct a.person_id) as bigint) as pers,
  cast(count(distinct case when a.concept_fm_flag = 1 then a.person_id else null end) as bigint) as pers_fmb
from @results_database_schema.cab_s03_procedure a
group by
  case when a.visit_concept_id > 0 then a.visit_concept_id else -99 end,
  a.concept_id
)
insert into @results_database_schema.cab_s30_cum
select
  @batch_number as batch_number,
  120 as pair_type,
  1 as anchor_code,
  1 as interval_code,
  a.ca as concept_a,
  a.cb as concept_b,
  a.obs,
  0,
  a.obs_fmb,
  0,
  0,
  0,
  0,
  a.obs * a.obs,
  a.pers,
  0,
  a.pers_fmb,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  null,
  null
from w a
where a.obs > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s30_cum' as table_name, 32 as step, @now_expr as step_datetime;

-- 130 visit | device
with w as (
select
  case when a.visit_concept_id > 0 then a.visit_concept_id else -99 end as ca,
  a.concept_id as cb,
  cast(count(*) as bigint) as obs,
  sum(cast(a.concept_fm_flag as bigint)) as obs_fmb,
  cast(count(distinct a.person_id) as bigint) as pers,
  cast(count(distinct case when a.concept_fm_flag = 1 then a.person_id else null end) as bigint) as pers_fmb
from @results_database_schema.cab_s04_device a
group by
  case when a.visit_concept_id > 0 then a.visit_concept_id else -99 end,
  a.concept_id
)
insert into @results_database_schema.cab_s30_cum
select
  @batch_number as batch_number,
  130 as pair_type,
  1 as anchor_code,
  1 as interval_code,
  a.ca as concept_a,
  a.cb as concept_b,
  a.obs,
  0,
  a.obs_fmb,
  0,
  0,
  0,
  0,
  a.obs * a.obs,
  a.pers,
  0,
  a.pers_fmb,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  null,
  null
from w a
where a.obs > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s30_cum' as table_name, 33 as step, @now_expr as step_datetime;

-- 140 visit | drug
with w as (
select
  case when a.visit_concept_id > 0 then a.visit_concept_id else -99 end as ca,
  a.concept_id as cb,
  cast(count(*) as bigint) as obs,
  sum(cast(a.concept_fm_flag as bigint)) as obs_fmb,
  cast(count(distinct a.person_id) as bigint) as pers,
  cast(count(distinct case when a.concept_fm_flag = 1 then a.person_id else null end) as bigint) as pers_fmb
from @results_database_schema.cab_s05_drug a
group by
  case when a.visit_concept_id > 0 then a.visit_concept_id else -99 end,
  a.concept_id
)
insert into @results_database_schema.cab_s30_cum
select
  @batch_number as batch_number,
  140 as pair_type,
  1 as anchor_code,
  1 as interval_code,
  a.ca as concept_a,
  a.cb as concept_b,
  a.obs,
  0,
  a.obs_fmb,
  0,
  0,
  0,
  0,
  a.obs * a.obs,
  a.pers,
  0,
  a.pers_fmb,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  null,
  null
from w a
where a.obs > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s30_cum' as table_name, 34 as step, @now_expr as step_datetime;

-- 150 visit | obs test
with w as (
select
  case when a.visit_concept_id > 0 then a.visit_concept_id else -99 end as ca,
  a.concept_id as cb,
  cast(count(*) as bigint) as obs,
  sum(cast(a.concept_fm_flag as bigint)) as obs_fmb,
  cast(count(distinct a.person_id) as bigint) as pers,
  cast(count(distinct case when a.concept_fm_flag = 1 then a.person_id else null end) as bigint) as pers_fmb
from @results_database_schema.cab_s06_observation a
group by
  case when a.visit_concept_id > 0 then a.visit_concept_id else -99 end,
  a.concept_id
)
insert into @results_database_schema.cab_s30_cum
select
  @batch_number as batch_number,
  150 as pair_type,
  1 as anchor_code,
  1 as interval_code,
  a.ca as concept_a,
  a.cb as concept_b,
  a.obs,
  0,
  a.obs_fmb,
  0,
  0,
  0,
  0,
  a.obs * a.obs,
  a.pers,
  0,
  a.pers_fmb,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  null,
  null
from w a
where a.obs > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s30_cum' as table_name, 35 as step, @now_expr as step_datetime;

-- 160 visit | meas test
with w as (
select
  case when a.visit_concept_id > 0 then a.visit_concept_id else -99 end as ca,
  a.concept_id as cb,
  cast(count(*) as bigint) as obs,
  sum(cast(a.concept_fm_flag as bigint)) as obs_fmb,
  cast(count(distinct a.person_id) as bigint) as pers,
  cast(count(distinct case when a.concept_fm_flag = 1 then a.person_id else null end) as bigint) as pers_fmb
from @results_database_schema.cab_s07_measurement a
group by
  case when a.visit_concept_id > 0 then a.visit_concept_id else -99 end,
  a.concept_id
)
insert into @results_database_schema.cab_s30_cum
select
  @batch_number as batch_number,
  160 as pair_type,
  1 as anchor_code,
  1 as interval_code,
  a.ca as concept_a,
  a.cb as concept_b,
  a.obs,
  0,
  a.obs_fmb,
  0,
  0,
  0,
  0,
  a.obs * a.obs,
  a.pers,
  0,
  a.pers_fmb,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  null,
  null
from w a
where a.obs > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s30_cum' as table_name, 36 as step, @now_expr as step_datetime;


-- =========================================================
-- CONCEPT RECORDING PATTERN  (cab_s39_pattern_cum)
--
-- Descriptive only -- feeds nothing in cab_s40/cab_s50. It exists so that
-- post-processing can tell which lift variant applies to a pair, from measured
-- recording behaviour rather than assumption.
--
-- Five patterns. mentions_per_person, which cab_s20 already supplies,
-- separates punctate (about 1) and chronic (8 or more) but reads about the
-- same for clustered, recurrent and episodic -- and those three need different
-- handling. Three films for one ankle injury are ONE event recorded three
-- times, so all-mention lift triple counts it. Three separate UTIs are THREE
-- events, so collapsing to a first mention discards two of them. The gap
-- between consecutive mentions is what tells them apart:
--   clustered  gaps pile up at 1 to 14 days, then nothing
--   recurrent  gaps spread across 90 to 365 days
--   chronic    gaps regular at 20 to 120 days, indefinitely
--   episodic   BIMODAL -- mass at both ends, little in between
--
-- A histogram is stored rather than a mean and SD because episodic is bimodal
-- and a mean lands in the empty middle between its two modes.
--
-- Six staging tables. The two result tables are excluded: a result key is its
-- test concept plus a value, so its recording timing is the test's timing.
-- Gated to batch_number <= @data_profile_batch_limit.
--
-- The work is a lag() partitioned by person and concept, which needs a sort
-- the staging indexes do not provide. On cab_s09_measurement_test that is the
-- expensive part, which is why this runs on a sample.
-- =========================================================

-- cab_s02_condition: gap -- days since this person's previous mention of this concept
with s0 as (
select
  a.concept_id,
  a.person_id,
  a.start_bucket - lag(a.start_bucket) over (partition by a.person_id, a.concept_id order by a.start_bucket) as gap_days
from @results_database_schema.cab_s02_condition a
where @batch_number <= @data_profile_batch_limit
), s1 as ( -- bucketed once so the group by does not repeat the case
select
  a.concept_id,
  a.person_id,
  case
    when a.gap_days = 0 then 0
    when a.gap_days <= 3 then 3
    when a.gap_days <= 7 then 7
    when a.gap_days <= 14 then 14
    when a.gap_days <= 30 then 30
    when a.gap_days <= 60 then 60
    when a.gap_days <= 90 then 90
    when a.gap_days <= 180 then 180
    when a.gap_days <= 365 then 365
    when a.gap_days <= 730 then 730
    else 999
  end as bucket
from s0 a
where a.gap_days is not null
)
insert into @results_database_schema.cab_s39_pattern_cum
select
  @batch_number,
  'gap',
  10,
  a.concept_id,
  a.bucket,
  cast(count(*) as bigint),
  cast(count(distinct a.person_id) as bigint)
from s1 a
group by
  a.concept_id,
  a.bucket;

-- cab_s02_condition: span -- first to last mention of this concept within one person
with s2 as (
select
  a.concept_id,
  a.person_id,
  max(a.start_bucket) - min(a.start_bucket) as span_days
from @results_database_schema.cab_s02_condition a
where @batch_number <= @data_profile_batch_limit
group by
  a.concept_id,
  a.person_id
), s3 as (
select
  a.concept_id,
  case
    when a.span_days = 0 then 0
    when a.span_days <= 7 then 7
    when a.span_days <= 30 then 30
    when a.span_days <= 90 then 90
    when a.span_days <= 180 then 180
    when a.span_days <= 365 then 365
    when a.span_days <= 730 then 730
    when a.span_days <= 1460 then 1460
    else 999
  end as bucket
from s2 a
)
insert into @results_database_schema.cab_s39_pattern_cum
select
  @batch_number,
  'span',
  10,
  a.concept_id,
  a.bucket,
  cast(count(*) as bigint),
  cast(count(*) as bigint)
from s3 a
group by
  a.concept_id,
  a.bucket;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s39_pattern_cum' as table_name, 1 as step, @now_expr as step_datetime;

-- cab_s03_procedure: gap -- days since this person's previous mention of this concept
with s0 as (
select
  a.concept_id,
  a.person_id,
  a.start_bucket - lag(a.start_bucket) over (partition by a.person_id, a.concept_id order by a.start_bucket) as gap_days
from @results_database_schema.cab_s03_procedure a
where @batch_number <= @data_profile_batch_limit
), s1 as ( -- bucketed once so the group by does not repeat the case
select
  a.concept_id,
  a.person_id,
  case
    when a.gap_days = 0 then 0
    when a.gap_days <= 3 then 3
    when a.gap_days <= 7 then 7
    when a.gap_days <= 14 then 14
    when a.gap_days <= 30 then 30
    when a.gap_days <= 60 then 60
    when a.gap_days <= 90 then 90
    when a.gap_days <= 180 then 180
    when a.gap_days <= 365 then 365
    when a.gap_days <= 730 then 730
    else 999
  end as bucket
from s0 a
where a.gap_days is not null
)
insert into @results_database_schema.cab_s39_pattern_cum
select
  @batch_number,
  'gap',
  20,
  a.concept_id,
  a.bucket,
  cast(count(*) as bigint),
  cast(count(distinct a.person_id) as bigint)
from s1 a
group by
  a.concept_id,
  a.bucket;

-- cab_s03_procedure: span -- first to last mention of this concept within one person
with s2 as (
select
  a.concept_id,
  a.person_id,
  max(a.start_bucket) - min(a.start_bucket) as span_days
from @results_database_schema.cab_s03_procedure a
where @batch_number <= @data_profile_batch_limit
group by
  a.concept_id,
  a.person_id
), s3 as (
select
  a.concept_id,
  case
    when a.span_days = 0 then 0
    when a.span_days <= 7 then 7
    when a.span_days <= 30 then 30
    when a.span_days <= 90 then 90
    when a.span_days <= 180 then 180
    when a.span_days <= 365 then 365
    when a.span_days <= 730 then 730
    when a.span_days <= 1460 then 1460
    else 999
  end as bucket
from s2 a
)
insert into @results_database_schema.cab_s39_pattern_cum
select
  @batch_number,
  'span',
  20,
  a.concept_id,
  a.bucket,
  cast(count(*) as bigint),
  cast(count(*) as bigint)
from s3 a
group by
  a.concept_id,
  a.bucket;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s39_pattern_cum' as table_name, 2 as step, @now_expr as step_datetime;

-- cab_s04_device: gap -- days since this person's previous mention of this concept
with s0 as (
select
  a.concept_id,
  a.person_id,
  a.start_bucket - lag(a.start_bucket) over (partition by a.person_id, a.concept_id order by a.start_bucket) as gap_days
from @results_database_schema.cab_s04_device a
where @batch_number <= @data_profile_batch_limit
), s1 as ( -- bucketed once so the group by does not repeat the case
select
  a.concept_id,
  a.person_id,
  case
    when a.gap_days = 0 then 0
    when a.gap_days <= 3 then 3
    when a.gap_days <= 7 then 7
    when a.gap_days <= 14 then 14
    when a.gap_days <= 30 then 30
    when a.gap_days <= 60 then 60
    when a.gap_days <= 90 then 90
    when a.gap_days <= 180 then 180
    when a.gap_days <= 365 then 365
    when a.gap_days <= 730 then 730
    else 999
  end as bucket
from s0 a
where a.gap_days is not null
)
insert into @results_database_schema.cab_s39_pattern_cum
select
  @batch_number,
  'gap',
  30,
  a.concept_id,
  a.bucket,
  cast(count(*) as bigint),
  cast(count(distinct a.person_id) as bigint)
from s1 a
group by
  a.concept_id,
  a.bucket;

-- cab_s04_device: span -- first to last mention of this concept within one person
with s2 as (
select
  a.concept_id,
  a.person_id,
  max(a.start_bucket) - min(a.start_bucket) as span_days
from @results_database_schema.cab_s04_device a
where @batch_number <= @data_profile_batch_limit
group by
  a.concept_id,
  a.person_id
), s3 as (
select
  a.concept_id,
  case
    when a.span_days = 0 then 0
    when a.span_days <= 7 then 7
    when a.span_days <= 30 then 30
    when a.span_days <= 90 then 90
    when a.span_days <= 180 then 180
    when a.span_days <= 365 then 365
    when a.span_days <= 730 then 730
    when a.span_days <= 1460 then 1460
    else 999
  end as bucket
from s2 a
)
insert into @results_database_schema.cab_s39_pattern_cum
select
  @batch_number,
  'span',
  30,
  a.concept_id,
  a.bucket,
  cast(count(*) as bigint),
  cast(count(*) as bigint)
from s3 a
group by
  a.concept_id,
  a.bucket;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s39_pattern_cum' as table_name, 3 as step, @now_expr as step_datetime;

-- cab_s05_drug: gap -- days since this person's previous mention of this concept
with s0 as (
select
  a.concept_id,
  a.person_id,
  a.start_bucket - lag(a.start_bucket) over (partition by a.person_id, a.concept_id order by a.start_bucket) as gap_days
from @results_database_schema.cab_s05_drug a
where @batch_number <= @data_profile_batch_limit
), s1 as ( -- bucketed once so the group by does not repeat the case
select
  a.concept_id,
  a.person_id,
  case
    when a.gap_days = 0 then 0
    when a.gap_days <= 3 then 3
    when a.gap_days <= 7 then 7
    when a.gap_days <= 14 then 14
    when a.gap_days <= 30 then 30
    when a.gap_days <= 60 then 60
    when a.gap_days <= 90 then 90
    when a.gap_days <= 180 then 180
    when a.gap_days <= 365 then 365
    when a.gap_days <= 730 then 730
    else 999
  end as bucket
from s0 a
where a.gap_days is not null
)
insert into @results_database_schema.cab_s39_pattern_cum
select
  @batch_number,
  'gap',
  40,
  a.concept_id,
  a.bucket,
  cast(count(*) as bigint),
  cast(count(distinct a.person_id) as bigint)
from s1 a
group by
  a.concept_id,
  a.bucket;

-- cab_s05_drug: span -- first to last mention of this concept within one person
with s2 as (
select
  a.concept_id,
  a.person_id,
  max(a.start_bucket) - min(a.start_bucket) as span_days
from @results_database_schema.cab_s05_drug a
where @batch_number <= @data_profile_batch_limit
group by
  a.concept_id,
  a.person_id
), s3 as (
select
  a.concept_id,
  case
    when a.span_days = 0 then 0
    when a.span_days <= 7 then 7
    when a.span_days <= 30 then 30
    when a.span_days <= 90 then 90
    when a.span_days <= 180 then 180
    when a.span_days <= 365 then 365
    when a.span_days <= 730 then 730
    when a.span_days <= 1460 then 1460
    else 999
  end as bucket
from s2 a
)
insert into @results_database_schema.cab_s39_pattern_cum
select
  @batch_number,
  'span',
  40,
  a.concept_id,
  a.bucket,
  cast(count(*) as bigint),
  cast(count(*) as bigint)
from s3 a
group by
  a.concept_id,
  a.bucket;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s39_pattern_cum' as table_name, 4 as step, @now_expr as step_datetime;

-- cab_s08_observation_test: gap -- days since this person's previous mention of this concept
with s0 as (
select
  a.concept_id,
  a.person_id,
  a.start_bucket - lag(a.start_bucket) over (partition by a.person_id, a.concept_id order by a.start_bucket) as gap_days
from @results_database_schema.cab_s08_observation_test a
where @batch_number <= @data_profile_batch_limit
), s1 as ( -- bucketed once so the group by does not repeat the case
select
  a.concept_id,
  a.person_id,
  case
    when a.gap_days = 0 then 0
    when a.gap_days <= 3 then 3
    when a.gap_days <= 7 then 7
    when a.gap_days <= 14 then 14
    when a.gap_days <= 30 then 30
    when a.gap_days <= 60 then 60
    when a.gap_days <= 90 then 90
    when a.gap_days <= 180 then 180
    when a.gap_days <= 365 then 365
    when a.gap_days <= 730 then 730
    else 999
  end as bucket
from s0 a
where a.gap_days is not null
)
insert into @results_database_schema.cab_s39_pattern_cum
select
  @batch_number,
  'gap',
  50,
  a.concept_id,
  a.bucket,
  cast(count(*) as bigint),
  cast(count(distinct a.person_id) as bigint)
from s1 a
group by
  a.concept_id,
  a.bucket;

-- cab_s08_observation_test: span -- first to last mention of this concept within one person
with s2 as (
select
  a.concept_id,
  a.person_id,
  max(a.start_bucket) - min(a.start_bucket) as span_days
from @results_database_schema.cab_s08_observation_test a
where @batch_number <= @data_profile_batch_limit
group by
  a.concept_id,
  a.person_id
), s3 as (
select
  a.concept_id,
  case
    when a.span_days = 0 then 0
    when a.span_days <= 7 then 7
    when a.span_days <= 30 then 30
    when a.span_days <= 90 then 90
    when a.span_days <= 180 then 180
    when a.span_days <= 365 then 365
    when a.span_days <= 730 then 730
    when a.span_days <= 1460 then 1460
    else 999
  end as bucket
from s2 a
)
insert into @results_database_schema.cab_s39_pattern_cum
select
  @batch_number,
  'span',
  50,
  a.concept_id,
  a.bucket,
  cast(count(*) as bigint),
  cast(count(*) as bigint)
from s3 a
group by
  a.concept_id,
  a.bucket;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s39_pattern_cum' as table_name, 5 as step, @now_expr as step_datetime;

-- cab_s09_measurement_test: gap -- days since this person's previous mention of this concept
with s0 as (
select
  a.concept_id,
  a.person_id,
  a.start_bucket - lag(a.start_bucket) over (partition by a.person_id, a.concept_id order by a.start_bucket) as gap_days
from @results_database_schema.cab_s09_measurement_test a
where @batch_number <= @data_profile_batch_limit
), s1 as ( -- bucketed once so the group by does not repeat the case
select
  a.concept_id,
  a.person_id,
  case
    when a.gap_days = 0 then 0
    when a.gap_days <= 3 then 3
    when a.gap_days <= 7 then 7
    when a.gap_days <= 14 then 14
    when a.gap_days <= 30 then 30
    when a.gap_days <= 60 then 60
    when a.gap_days <= 90 then 90
    when a.gap_days <= 180 then 180
    when a.gap_days <= 365 then 365
    when a.gap_days <= 730 then 730
    else 999
  end as bucket
from s0 a
where a.gap_days is not null
)
insert into @results_database_schema.cab_s39_pattern_cum
select
  @batch_number,
  'gap',
  60,
  a.concept_id,
  a.bucket,
  cast(count(*) as bigint),
  cast(count(distinct a.person_id) as bigint)
from s1 a
group by
  a.concept_id,
  a.bucket;

-- cab_s09_measurement_test: span -- first to last mention of this concept within one person
with s2 as (
select
  a.concept_id,
  a.person_id,
  max(a.start_bucket) - min(a.start_bucket) as span_days
from @results_database_schema.cab_s09_measurement_test a
where @batch_number <= @data_profile_batch_limit
group by
  a.concept_id,
  a.person_id
), s3 as (
select
  a.concept_id,
  case
    when a.span_days = 0 then 0
    when a.span_days <= 7 then 7
    when a.span_days <= 30 then 30
    when a.span_days <= 90 then 90
    when a.span_days <= 180 then 180
    when a.span_days <= 365 then 365
    when a.span_days <= 730 then 730
    when a.span_days <= 1460 then 1460
    else 999
  end as bucket
from s2 a
)
insert into @results_database_schema.cab_s39_pattern_cum
select
  @batch_number,
  'span',
  60,
  a.concept_id,
  a.bucket,
  cast(count(*) as bigint),
  cast(count(*) as bigint)
from s3 a
group by
  a.concept_id,
  a.bucket;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s39_pattern_cum' as table_name, 6 as step, @now_expr as step_datetime;


-- =========================================================
-- DESIGN PROFILING  (cab_s37_lag_cum, cab_s38_profile_cum)
--
-- Like s35/s36 these feed nothing in the statistics pipeline. They exist to
-- ground the design choices that are currently guesses, so the next version
-- can be built on IU's actual distributions instead of on Synthea's, which
-- differs from real data in exactly the ways that matter here. Both are gated
-- to batch_number <= 2 -- a 10% random sample, since persons are randomly
-- partitioned, is far more than enough to characterise a distribution.
--
-- cab_s37: LAG DECAY. The +/-@window_days near window and the 182 and 365 day
--   reference offsets were chosen without data. A histogram of delta out to
--   ~400 days shows where co-occurrence density flattens to baseline. If
--   density at day 182 is already flat the 6-month reference is clean; if it
--   is still elevated the reference is contaminated by real signal and the
--   next version should push it further out. This is the one profiling item
--   with real cost -- a 400-day-wide join -- so it runs on five pair types
--   only, and only in the profiling batches.
--
-- cab_s38: four small distributions in one table, keyed by metric:
--   'eligible'  what fraction of A events survive the >= 365 + @window_days
--               follow-up filter a long forward reach would need. At 90%
--               nearly unbiased; at 55% the next version wants a shorter
--               reference so the filter bites less.
--   'visitlink' fraction of records carrying a visit_occurrence_id, by domain.
--               same_visit_frac was among the better discriminators but is
--               blind wherever linkage is missing, and Synthea's condition
--               records have none at all.
--   'obsspan'   observation-period length and span count per person. Both the
--               eligibility filter and fm_early_flag assume things about
--               enrollment that Synthea cannot test, since its records start
--               at birth.
--   'intake'    days from enrollment to a concept's first mention. Says
--               whether fm_early_flag's 30-day cut is right or should be 90.
-- =========================================================

-- cab_s37: lag decay, five pair types, profiling batches only

insert into @results_database_schema.cab_s37_lag_cum
select
  @batch_number as batch_number,
  1010 as pair_type,
  z.lag_bucket,
  sum(z.n_events) as n_events,
  count(*) as n_pairs
from (
  select
    case
      when b.start_bucket - a.start_bucket < -400 then -999
      when b.start_bucket - a.start_bucket > 400 then 999
      else (b.start_bucket - a.start_bucket) / 10
    end as lag_bucket,
    a.concept_id as ca,
    b.concept_id as cb,
    cast(count(*) as bigint) as n_events
  from @results_database_schema.cab_s02_condition a
    inner join @results_database_schema.cab_person_batch p on a.person_id = p.person_id and @batch_number <= @data_profile_batch_limit
    inner join @results_database_schema.cab_s02_condition b on a.person_id = b.person_id and b.start_bucket - a.start_bucket between -400 and 400
     and a.concept_id < b.concept_id
  group by
    case
      when b.start_bucket - a.start_bucket < -400 then -999
      when b.start_bucket - a.start_bucket > 400 then 999
      else (b.start_bucket - a.start_bucket) / 10
    end,
    a.concept_id,
    b.concept_id
) z
group by z.lag_bucket;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s37_lag_cum' as table_name, 1 as step, @now_expr as step_datetime;

insert into @results_database_schema.cab_s37_lag_cum
select
  @batch_number as batch_number,
  1020 as pair_type,
  z.lag_bucket,
  sum(z.n_events) as n_events,
  count(*) as n_pairs
from (
  select
    case
      when b.start_bucket - a.start_bucket < -400 then -999
      when b.start_bucket - a.start_bucket > 400 then 999
      else (b.start_bucket - a.start_bucket) / 10
    end as lag_bucket,
    a.concept_id as ca,
    b.concept_id as cb,
    cast(count(*) as bigint) as n_events
  from @results_database_schema.cab_s02_condition a
    inner join @results_database_schema.cab_person_batch p on a.person_id = p.person_id and @batch_number <= @data_profile_batch_limit
    inner join @results_database_schema.cab_s03_procedure b on a.person_id = b.person_id and b.start_bucket - a.start_bucket between -400 and 400
  group by
    case
      when b.start_bucket - a.start_bucket < -400 then -999
      when b.start_bucket - a.start_bucket > 400 then 999
      else (b.start_bucket - a.start_bucket) / 10
    end,
    a.concept_id,
    b.concept_id
) z
group by z.lag_bucket;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s37_lag_cum' as table_name, 2 as step, @now_expr as step_datetime;

insert into @results_database_schema.cab_s37_lag_cum
select
  @batch_number as batch_number,
  1040 as pair_type,
  z.lag_bucket,
  sum(z.n_events) as n_events,
  count(*) as n_pairs
from (
  select
    case
      when b.start_bucket - a.start_bucket < -400 then -999
      when b.start_bucket - a.start_bucket > 400 then 999
      else (b.start_bucket - a.start_bucket) / 10
    end as lag_bucket,
    a.concept_id as ca,
    b.concept_id as cb,
    cast(count(*) as bigint) as n_events
  from @results_database_schema.cab_s02_condition a
    inner join @results_database_schema.cab_person_batch p on a.person_id = p.person_id and @batch_number <= @data_profile_batch_limit
    inner join @results_database_schema.cab_s05_drug b on a.person_id = b.person_id and b.start_bucket - a.start_bucket between -400 and 400
  group by
    case
      when b.start_bucket - a.start_bucket < -400 then -999
      when b.start_bucket - a.start_bucket > 400 then 999
      else (b.start_bucket - a.start_bucket) / 10
    end,
    a.concept_id,
    b.concept_id
) z
group by z.lag_bucket;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s37_lag_cum' as table_name, 3 as step, @now_expr as step_datetime;

insert into @results_database_schema.cab_s37_lag_cum
select
  @batch_number as batch_number,
  2040 as pair_type,
  z.lag_bucket,
  sum(z.n_events) as n_events,
  count(*) as n_pairs
from (
  select
    case
      when b.start_bucket - a.start_bucket < -400 then -999
      when b.start_bucket - a.start_bucket > 400 then 999
      else (b.start_bucket - a.start_bucket) / 10
    end as lag_bucket,
    a.concept_id as ca,
    b.concept_id as cb,
    cast(count(*) as bigint) as n_events
  from @results_database_schema.cab_s03_procedure a
    inner join @results_database_schema.cab_person_batch p on a.person_id = p.person_id and @batch_number <= @data_profile_batch_limit
    inner join @results_database_schema.cab_s05_drug b on a.person_id = b.person_id and b.start_bucket - a.start_bucket between -400 and 400
  group by
    case
      when b.start_bucket - a.start_bucket < -400 then -999
      when b.start_bucket - a.start_bucket > 400 then 999
      else (b.start_bucket - a.start_bucket) / 10
    end,
    a.concept_id,
    b.concept_id
) z
group by z.lag_bucket;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s37_lag_cum' as table_name, 4 as step, @now_expr as step_datetime;

insert into @results_database_schema.cab_s37_lag_cum
select
  @batch_number as batch_number,
  4040 as pair_type,
  z.lag_bucket,
  sum(z.n_events) as n_events,
  count(*) as n_pairs
from (
  select
    case
      when b.start_bucket - a.start_bucket < -400 then -999
      when b.start_bucket - a.start_bucket > 400 then 999
      else (b.start_bucket - a.start_bucket) / 10
    end as lag_bucket,
    a.concept_id as ca,
    b.concept_id as cb,
    cast(count(*) as bigint) as n_events
  from @results_database_schema.cab_s05_drug a
    inner join @results_database_schema.cab_person_batch p on a.person_id = p.person_id and @batch_number <= @data_profile_batch_limit
    inner join @results_database_schema.cab_s05_drug b on a.person_id = b.person_id and b.start_bucket - a.start_bucket between -400 and 400
     and a.concept_id < b.concept_id
  group by
    case
      when b.start_bucket - a.start_bucket < -400 then -999
      when b.start_bucket - a.start_bucket > 400 then 999
      else (b.start_bucket - a.start_bucket) / 10
    end,
    a.concept_id,
    b.concept_id
) z
group by z.lag_bucket;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s37_lag_cum' as table_name, 5 as step, @now_expr as step_datetime;


-- cab_s38: four small distributions, profiling batches only

-- s38 'eligible': share of A events with at least 365 + @window_days days of
-- follow-up remaining. Descriptive only now that the eligible-anchor family is
-- gone; kept because it measures how much of the record is right-censored. src 10
insert into @results_database_schema.cab_s38_profile_cum
select
  @batch_number as batch_number,
  'eligible' as metric,
  10 as src,
  case when datediff(day, a.start_date, c.obs_epi_end_date) >= 365 + @window_days then 1 else 0 end as bucket,
  cast(count(*) as bigint) as n_records,
  cast(count(distinct a.person_id) as bigint) as n_persons
from @results_database_schema.cab_s02_condition a
  inner join @results_database_schema.cab_s00_obs_period c on a.person_id = c.person_id and a.start_date between c.observation_period_start_date and c.observation_period_end_date
where @batch_number <= @data_profile_batch_limit
group by case when datediff(day, a.start_date, c.obs_epi_end_date) >= 365 + @window_days then 1 else 0 end;

-- s38 'eligible': share of A events with at least 365 + @window_days days of
-- follow-up remaining. Descriptive only now that the eligible-anchor family is
-- gone; kept because it measures how much of the record is right-censored. src 20
insert into @results_database_schema.cab_s38_profile_cum
select
  @batch_number as batch_number,
  'eligible' as metric,
  20 as src,
  case when datediff(day, a.start_date, c.obs_epi_end_date) >= 365 + @window_days then 1 else 0 end as bucket,
  cast(count(*) as bigint) as n_records,
  cast(count(distinct a.person_id) as bigint) as n_persons
from @results_database_schema.cab_s03_procedure a
  inner join @results_database_schema.cab_s00_obs_period c on a.person_id = c.person_id and a.start_date between c.observation_period_start_date and c.observation_period_end_date
where @batch_number <= @data_profile_batch_limit
group by case when datediff(day, a.start_date, c.obs_epi_end_date) >= 365 + @window_days then 1 else 0 end;

-- s38 'eligible': share of A events with at least 365 + @window_days days of
-- follow-up remaining. Descriptive only now that the eligible-anchor family is
-- gone; kept because it measures how much of the record is right-censored. src 30
insert into @results_database_schema.cab_s38_profile_cum
select
  @batch_number as batch_number,
  'eligible' as metric,
  30 as src,
  case when datediff(day, a.start_date, c.obs_epi_end_date) >= 365 + @window_days then 1 else 0 end as bucket,
  cast(count(*) as bigint) as n_records,
  cast(count(distinct a.person_id) as bigint) as n_persons
from @results_database_schema.cab_s04_device a
  inner join @results_database_schema.cab_s00_obs_period c on a.person_id = c.person_id and a.start_date between c.observation_period_start_date and c.observation_period_end_date
where @batch_number <= @data_profile_batch_limit
group by case when datediff(day, a.start_date, c.obs_epi_end_date) >= 365 + @window_days then 1 else 0 end;

-- s38 'eligible': share of A events with at least 365 + @window_days days of
-- follow-up remaining. Descriptive only now that the eligible-anchor family is
-- gone; kept because it measures how much of the record is right-censored. src 40
insert into @results_database_schema.cab_s38_profile_cum
select
  @batch_number as batch_number,
  'eligible' as metric,
  40 as src,
  case when datediff(day, a.start_date, c.obs_epi_end_date) >= 365 + @window_days then 1 else 0 end as bucket,
  cast(count(*) as bigint) as n_records,
  cast(count(distinct a.person_id) as bigint) as n_persons
from @results_database_schema.cab_s05_drug a
  inner join @results_database_schema.cab_s00_obs_period c on a.person_id = c.person_id and a.start_date between c.observation_period_start_date and c.observation_period_end_date
where @batch_number <= @data_profile_batch_limit
group by case when datediff(day, a.start_date, c.obs_epi_end_date) >= 365 + @window_days then 1 else 0 end;

-- s38 'visitlink': visit_occurrence_id coverage, src 10
insert into @results_database_schema.cab_s38_profile_cum
select
  @batch_number,
  'visitlink',
  10,
  case when a.visit_occurrence_id is null or a.visit_occurrence_id = 0 then 0 else 1 end,
  cast(count(*) as bigint),
  cast(count(distinct a.person_id) as bigint)
from @results_database_schema.cab_s02_condition a
where @batch_number <= @data_profile_batch_limit
group by case when a.visit_occurrence_id is null or a.visit_occurrence_id = 0 then 0 else 1 end;

-- s38 'visitlink': visit_occurrence_id coverage, src 20
insert into @results_database_schema.cab_s38_profile_cum
select
  @batch_number,
  'visitlink',
  20,
  case when a.visit_occurrence_id is null or a.visit_occurrence_id = 0 then 0 else 1 end,
  cast(count(*) as bigint),
  cast(count(distinct a.person_id) as bigint)
from @results_database_schema.cab_s03_procedure a
where @batch_number <= @data_profile_batch_limit
group by case when a.visit_occurrence_id is null or a.visit_occurrence_id = 0 then 0 else 1 end;

-- s38 'visitlink': visit_occurrence_id coverage, src 30
insert into @results_database_schema.cab_s38_profile_cum
select
  @batch_number,
  'visitlink',
  30,
  case when a.visit_occurrence_id is null or a.visit_occurrence_id = 0 then 0 else 1 end,
  cast(count(*) as bigint),
  cast(count(distinct a.person_id) as bigint)
from @results_database_schema.cab_s04_device a
where @batch_number <= @data_profile_batch_limit
group by case when a.visit_occurrence_id is null or a.visit_occurrence_id = 0 then 0 else 1 end;

-- s38 'visitlink': visit_occurrence_id coverage, src 40
insert into @results_database_schema.cab_s38_profile_cum
select
  @batch_number,
  'visitlink',
  40,
  case when a.visit_occurrence_id is null or a.visit_occurrence_id = 0 then 0 else 1 end,
  cast(count(*) as bigint),
  cast(count(distinct a.person_id) as bigint)
from @results_database_schema.cab_s05_drug a
where @batch_number <= @data_profile_batch_limit
group by case when a.visit_occurrence_id is null or a.visit_occurrence_id = 0 then 0 else 1 end;

-- s38 'visitlink': visit_occurrence_id coverage, src 50
insert into @results_database_schema.cab_s38_profile_cum
select
  @batch_number,
  'visitlink',
  50,
  case when a.visit_occurrence_id is null or a.visit_occurrence_id = 0 then 0 else 1 end,
  cast(count(*) as bigint),
  cast(count(distinct a.person_id) as bigint)
from @results_database_schema.cab_s08_observation_test a
where @batch_number <= @data_profile_batch_limit
group by case when a.visit_occurrence_id is null or a.visit_occurrence_id = 0 then 0 else 1 end;

-- s38 'visitlink': visit_occurrence_id coverage, src 60
insert into @results_database_schema.cab_s38_profile_cum
select
  @batch_number,
  'visitlink',
  60,
  case when a.visit_occurrence_id is null or a.visit_occurrence_id = 0 then 0 else 1 end,
  cast(count(*) as bigint),
  cast(count(distinct a.person_id) as bigint)
from @results_database_schema.cab_s09_measurement_test a
where @batch_number <= @data_profile_batch_limit
group by case when a.visit_occurrence_id is null or a.visit_occurrence_id = 0 then 0 else 1 end;

-- s38 'intake': days from enrollment to first mention, 30-day buckets, src 10
insert into @results_database_schema.cab_s38_profile_cum
select
  @batch_number,
  'intake',
  10,
  case when a.fm_days_from_intake > 1080 then 999 else a.fm_days_from_intake / 30 end,
  cast(count(*) as bigint),
  cast(count(distinct a.person_id) as bigint)
from @results_database_schema.cab_s02_condition a
where a.concept_fm_flag = 1
  and a.fm_days_from_intake is not null
  and @batch_number <= @data_profile_batch_limit
group by case when a.fm_days_from_intake > 1080 then 999 else a.fm_days_from_intake / 30 end;

-- s38 'intake': days from enrollment to first mention, 30-day buckets, src 20
insert into @results_database_schema.cab_s38_profile_cum
select
  @batch_number,
  'intake',
  20,
  case when a.fm_days_from_intake > 1080 then 999 else a.fm_days_from_intake / 30 end,
  cast(count(*) as bigint),
  cast(count(distinct a.person_id) as bigint)
from @results_database_schema.cab_s03_procedure a
where a.concept_fm_flag = 1
  and a.fm_days_from_intake is not null
  and @batch_number <= @data_profile_batch_limit
group by case when a.fm_days_from_intake > 1080 then 999 else a.fm_days_from_intake / 30 end;

-- s38 'intake': days from enrollment to first mention, 30-day buckets, src 30
insert into @results_database_schema.cab_s38_profile_cum
select
  @batch_number,
  'intake',
  30,
  case when a.fm_days_from_intake > 1080 then 999 else a.fm_days_from_intake / 30 end,
  cast(count(*) as bigint),
  cast(count(distinct a.person_id) as bigint)
from @results_database_schema.cab_s04_device a
where a.concept_fm_flag = 1
  and a.fm_days_from_intake is not null
  and @batch_number <= @data_profile_batch_limit
group by case when a.fm_days_from_intake > 1080 then 999 else a.fm_days_from_intake / 30 end;

-- s38 'intake': days from enrollment to first mention, 30-day buckets, src 40
insert into @results_database_schema.cab_s38_profile_cum
select
  @batch_number,
  'intake',
  40,
  case when a.fm_days_from_intake > 1080 then 999 else a.fm_days_from_intake / 30 end,
  cast(count(*) as bigint),
  cast(count(distinct a.person_id) as bigint)
from @results_database_schema.cab_s05_drug a
where a.concept_fm_flag = 1
  and a.fm_days_from_intake is not null
  and @batch_number <= @data_profile_batch_limit
group by case when a.fm_days_from_intake > 1080 then 999 else a.fm_days_from_intake / 30 end;

-- s38 'intake': days from enrollment to first mention, 30-day buckets, src 50
insert into @results_database_schema.cab_s38_profile_cum
select
  @batch_number,
  'intake',
  50,
  case when a.fm_days_from_intake > 1080 then 999 else a.fm_days_from_intake / 30 end,
  cast(count(*) as bigint),
  cast(count(distinct a.person_id) as bigint)
from @results_database_schema.cab_s08_observation_test a
where a.concept_fm_flag = 1
  and a.fm_days_from_intake is not null
  and @batch_number <= @data_profile_batch_limit
group by case when a.fm_days_from_intake > 1080 then 999 else a.fm_days_from_intake / 30 end;

-- s38 'intake': days from enrollment to first mention, 30-day buckets, src 60
insert into @results_database_schema.cab_s38_profile_cum
select
  @batch_number,
  'intake',
  60,
  case when a.fm_days_from_intake > 1080 then 999 else a.fm_days_from_intake / 30 end,
  cast(count(*) as bigint),
  cast(count(distinct a.person_id) as bigint)
from @results_database_schema.cab_s09_measurement_test a
where a.concept_fm_flag = 1
  and a.fm_days_from_intake is not null
  and @batch_number <= @data_profile_batch_limit
group by case when a.fm_days_from_intake > 1080 then 999 else a.fm_days_from_intake / 30 end;

-- s38 'obsspan': observation-period length and span count per person
insert into @results_database_schema.cab_s38_profile_cum
select
  @batch_number,
  'obsspan',
  0,
  case when z.total_days > 7200 then 999 else z.total_days / 180 end,
  cast(count(*) as bigint),
  cast(count(*) as bigint)
from (
  select
    a.person_id,
    sum(datediff(day, a.observation_period_start_date, a.observation_period_end_date) + 1) as total_days
  from @source_cdm_schema.observation_period a
    inner join @results_database_schema.cab_person_batch p on a.person_id = p.person_id
  where @batch_number <= @data_profile_batch_limit
  group by a.person_id
) z
group by case when z.total_days > 7200 then 999 else z.total_days / 180 end;

insert into @results_database_schema.cab_s38_profile_cum
select
  @batch_number,
  'nspans',
  0,
  case when z.n_spans > 20 then 999 else z.n_spans end,
  cast(count(*) as bigint),
  cast(count(*) as bigint)
from (
  select
    a.person_id,
    count(*) as n_spans
  from @source_cdm_schema.observation_period a
    inner join @results_database_schema.cab_person_batch p on a.person_id = p.person_id
  where @batch_number <= @data_profile_batch_limit
  group by a.person_id
) z
group by case when z.n_spans > 20 then 999 else z.n_spans end;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s38_profile_cum' as table_name, 1 as step, @now_expr as step_datetime;


-- =========================================================
-- STRATIFIED COUNTS  (cab_s13 / cab_s23 / cab_s33)
--
-- WHY. Sick people accumulate more of everything, so any two clinical
-- concepts co-occur above the independence baseline whether or not they are
-- related. The expected count in cab_s40 uses ONE population-average rate
-- per concept, which assumes concept A is as likely in a healthy person as
-- in a heavy utilizer. It is not, and because both concepts are elevated in
-- the same people, the product understates the expected and lift comes out
-- inflated with no relationship present.
--
-- WHAT. The same counts as cab_s10 / cab_s20 / cab_s30, broken out by the
-- person's utilization decile. finalize can then build the expected INSIDE
-- each decile, using that decile's own rates and person-days, and sum:
--   E_k = obs_a_k * obs_b_k * win_w / person_days_k
--   adjusted expected = sum(E_k)     adjusted lift = obs_ab_act / sum(E_k)
-- The observed is never split: sum(obs_ab_k) equals obs_ab_act exactly, so
-- the adjusted lift has the same precision as the unadjusted one. Only the
-- denominator changes. Pooling only works in this direction -- sum the
-- marginals first and you get today's confounded number back.
--
-- COUNTS ONLY, NO ESTIMATOR. These tables store raw stratified counts, so
-- finalize is free to compute Mantel-Haenszel, a stratified odds ratio,
-- direct standardisation, or any reweighting, and to be rewritten later
-- without re-harvesting. Nothing here commits to a particular method.
--
-- cab_s33 covers the ten non-measurement pair types. The measurement and
-- result families are excluded on cost -- they are 90% of cab_s30 runtime.
--
-- The threshold is applied to the PAIR TOTAL via a window, not per decile.
-- Per-decile filtering would delete a pair whose events are spread thinly
-- across deciles -- 8 events over 8 deciles averages 1 each and the pair
-- would vanish entirely.
-- =========================================================

-- cab_s13: persons and person-days by decile -- the denominator of E_k
insert into @results_database_schema.cab_s13_strat_cum
select
  @batch_number as batch_number,
  z.util_decile,
  count(*) as persons_in_decile,
  sum(z.person_days) as person_days_in_decile
from (
  select
    a.person_id,
    b.util_decile,
    sum(cast(datediff(day, a.observation_period_start_date, a.observation_period_end_date) + 1 as bigint)) as person_days
  from @source_cdm_schema.observation_period a
    inner join @results_database_schema.cab_person_attr b on a.person_id = b.person_id
  group by
    a.person_id,
    b.util_decile
) z
group by z.util_decile;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s13_strat_cum' as table_name, 1 as step, @now_expr as step_datetime;


-- cab_s23 src 10: concept marginals by decile
with s0 as (
select
  a.concept_id,
  a.util_decile,
  a.person_id,
  cast(count(*) as bigint) as n_person,
  sum(cast(a.concept_fm_flag as bigint)) as n_person_fm
from @results_database_schema.cab_s02_condition a
group by
  a.concept_id,
  a.util_decile,
  a.person_id
)
insert into @results_database_schema.cab_s23_strat_cum
select
  @batch_number,
  concept_id,
  10,
  util_decile,
  sum(n_person),
  count(*),
  sum(n_person_fm),
  sum(case when n_person_fm > 0 then 1 else 0 end)
from s0
group by concept_id, util_decile;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s23_strat_cum' as table_name, 1 as step, @now_expr as step_datetime;

-- cab_s23 src 20: concept marginals by decile
with s0 as (
select
  a.concept_id,
  a.util_decile,
  a.person_id,
  cast(count(*) as bigint) as n_person,
  sum(cast(a.concept_fm_flag as bigint)) as n_person_fm
from @results_database_schema.cab_s03_procedure a
group by
  a.concept_id,
  a.util_decile,
  a.person_id
)
insert into @results_database_schema.cab_s23_strat_cum
select
  @batch_number,
  concept_id,
  20,
  util_decile,
  sum(n_person),
  count(*),
  sum(n_person_fm),
  sum(case when n_person_fm > 0 then 1 else 0 end)
from s0
group by concept_id, util_decile;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s23_strat_cum' as table_name, 2 as step, @now_expr as step_datetime;

-- cab_s23 src 30: concept marginals by decile
with s0 as (
select
  a.concept_id,
  a.util_decile,
  a.person_id,
  cast(count(*) as bigint) as n_person,
  sum(cast(a.concept_fm_flag as bigint)) as n_person_fm
from @results_database_schema.cab_s04_device a
group by
  a.concept_id,
  a.util_decile,
  a.person_id
)
insert into @results_database_schema.cab_s23_strat_cum
select
  @batch_number,
  concept_id,
  30,
  util_decile,
  sum(n_person),
  count(*),
  sum(n_person_fm),
  sum(case when n_person_fm > 0 then 1 else 0 end)
from s0
group by concept_id, util_decile;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s23_strat_cum' as table_name, 3 as step, @now_expr as step_datetime;

-- cab_s23 src 40: concept marginals by decile
with s0 as (
select
  a.concept_id,
  a.util_decile,
  a.person_id,
  cast(count(*) as bigint) as n_person,
  sum(cast(a.concept_fm_flag as bigint)) as n_person_fm
from @results_database_schema.cab_s05_drug a
group by
  a.concept_id,
  a.util_decile,
  a.person_id
)
insert into @results_database_schema.cab_s23_strat_cum
select
  @batch_number,
  concept_id,
  40,
  util_decile,
  sum(n_person),
  count(*),
  sum(n_person_fm),
  sum(case when n_person_fm > 0 then 1 else 0 end)
from s0
group by concept_id, util_decile;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s23_strat_cum' as table_name, 4 as step, @now_expr as step_datetime;

-- cab_s33 1010: pair co-occurrence by decile
with w as (
select
  z.ca,
  z.cb,
  z.util_decile,
  sum(z.ev_obs) as obs_ab_act,
  sum(z.ev_fmab) as obs_ab_act_fmab,
  count(*) as pers_ab,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    a.util_decile,
    cast(count(*) as bigint) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_fmab
  from @results_database_schema.cab_s02_condition a
    inner join @results_database_schema.cab_s02_condition b on a.person_id = b.person_id and a.start_bucket between b.start_bucket - @window_days and b.start_bucket + @window_days
     and a.concept_id < b.concept_id
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    a.util_decile
) z
group by z.ca, z.cb, z.util_decile
)
insert into @results_database_schema.cab_s33_strat_cum
select
  @batch_number as batch_number,
  1010 as pair_type,
  a.ca as concept_a,
  a.cb as concept_b,
  a.util_decile,
  a.obs_ab_act,
  a.obs_ab_act_fmab,
  a.pers_ab
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s33_strat_cum' as table_name, 1 as step, @now_expr as step_datetime;

-- cab_s33 1020: pair co-occurrence by decile
with w as (
select
  z.ca,
  z.cb,
  z.util_decile,
  sum(z.ev_obs) as obs_ab_act,
  sum(z.ev_fmab) as obs_ab_act_fmab,
  count(*) as pers_ab,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    a.util_decile,
    cast(count(*) as bigint) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_fmab
  from @results_database_schema.cab_s02_condition a
    inner join @results_database_schema.cab_s03_procedure b on a.person_id = b.person_id and a.start_bucket between b.start_bucket - @window_days and b.start_bucket + @window_days
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    a.util_decile
) z
group by z.ca, z.cb, z.util_decile
)
insert into @results_database_schema.cab_s33_strat_cum
select
  @batch_number as batch_number,
  1020 as pair_type,
  a.ca as concept_a,
  a.cb as concept_b,
  a.util_decile,
  a.obs_ab_act,
  a.obs_ab_act_fmab,
  a.pers_ab
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s33_strat_cum' as table_name, 2 as step, @now_expr as step_datetime;

-- cab_s33 1030: pair co-occurrence by decile
with w as (
select
  z.ca,
  z.cb,
  z.util_decile,
  sum(z.ev_obs) as obs_ab_act,
  sum(z.ev_fmab) as obs_ab_act_fmab,
  count(*) as pers_ab,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    a.util_decile,
    cast(count(*) as bigint) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_fmab
  from @results_database_schema.cab_s02_condition a
    inner join @results_database_schema.cab_s04_device b on a.person_id = b.person_id and a.start_bucket between b.start_bucket - @window_days and b.start_bucket + @window_days
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    a.util_decile
) z
group by z.ca, z.cb, z.util_decile
)
insert into @results_database_schema.cab_s33_strat_cum
select
  @batch_number as batch_number,
  1030 as pair_type,
  a.ca as concept_a,
  a.cb as concept_b,
  a.util_decile,
  a.obs_ab_act,
  a.obs_ab_act_fmab,
  a.pers_ab
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s33_strat_cum' as table_name, 3 as step, @now_expr as step_datetime;

-- cab_s33 1040: pair co-occurrence by decile
with w as (
select
  z.ca,
  z.cb,
  z.util_decile,
  sum(z.ev_obs) as obs_ab_act,
  sum(z.ev_fmab) as obs_ab_act_fmab,
  count(*) as pers_ab,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    a.util_decile,
    cast(count(*) as bigint) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_fmab
  from @results_database_schema.cab_s02_condition a
    inner join @results_database_schema.cab_s05_drug b on a.person_id = b.person_id and a.start_bucket between b.start_bucket - @window_days and b.start_bucket + @window_days
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    a.util_decile
) z
group by z.ca, z.cb, z.util_decile
)
insert into @results_database_schema.cab_s33_strat_cum
select
  @batch_number as batch_number,
  1040 as pair_type,
  a.ca as concept_a,
  a.cb as concept_b,
  a.util_decile,
  a.obs_ab_act,
  a.obs_ab_act_fmab,
  a.pers_ab
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s33_strat_cum' as table_name, 4 as step, @now_expr as step_datetime;

-- cab_s33 2020: pair co-occurrence by decile
with w as (
select
  z.ca,
  z.cb,
  z.util_decile,
  sum(z.ev_obs) as obs_ab_act,
  sum(z.ev_fmab) as obs_ab_act_fmab,
  count(*) as pers_ab,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    a.util_decile,
    cast(count(*) as bigint) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_fmab
  from @results_database_schema.cab_s03_procedure a
    inner join @results_database_schema.cab_s03_procedure b on a.person_id = b.person_id and a.start_bucket between b.start_bucket - @window_days and b.start_bucket + @window_days
     and a.concept_id < b.concept_id
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    a.util_decile
) z
group by z.ca, z.cb, z.util_decile
)
insert into @results_database_schema.cab_s33_strat_cum
select
  @batch_number as batch_number,
  2020 as pair_type,
  a.ca as concept_a,
  a.cb as concept_b,
  a.util_decile,
  a.obs_ab_act,
  a.obs_ab_act_fmab,
  a.pers_ab
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s33_strat_cum' as table_name, 5 as step, @now_expr as step_datetime;

-- cab_s33 2030: pair co-occurrence by decile
with w as (
select
  z.ca,
  z.cb,
  z.util_decile,
  sum(z.ev_obs) as obs_ab_act,
  sum(z.ev_fmab) as obs_ab_act_fmab,
  count(*) as pers_ab,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    a.util_decile,
    cast(count(*) as bigint) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_fmab
  from @results_database_schema.cab_s03_procedure a
    inner join @results_database_schema.cab_s04_device b on a.person_id = b.person_id and a.start_bucket between b.start_bucket - @window_days and b.start_bucket + @window_days
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    a.util_decile
) z
group by z.ca, z.cb, z.util_decile
)
insert into @results_database_schema.cab_s33_strat_cum
select
  @batch_number as batch_number,
  2030 as pair_type,
  a.ca as concept_a,
  a.cb as concept_b,
  a.util_decile,
  a.obs_ab_act,
  a.obs_ab_act_fmab,
  a.pers_ab
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s33_strat_cum' as table_name, 6 as step, @now_expr as step_datetime;

-- cab_s33 2040: pair co-occurrence by decile
with w as (
select
  z.ca,
  z.cb,
  z.util_decile,
  sum(z.ev_obs) as obs_ab_act,
  sum(z.ev_fmab) as obs_ab_act_fmab,
  count(*) as pers_ab,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    a.util_decile,
    cast(count(*) as bigint) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_fmab
  from @results_database_schema.cab_s03_procedure a
    inner join @results_database_schema.cab_s05_drug b on a.person_id = b.person_id and a.start_bucket between b.start_bucket - @window_days and b.start_bucket + @window_days
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    a.util_decile
) z
group by z.ca, z.cb, z.util_decile
)
insert into @results_database_schema.cab_s33_strat_cum
select
  @batch_number as batch_number,
  2040 as pair_type,
  a.ca as concept_a,
  a.cb as concept_b,
  a.util_decile,
  a.obs_ab_act,
  a.obs_ab_act_fmab,
  a.pers_ab
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s33_strat_cum' as table_name, 7 as step, @now_expr as step_datetime;

-- cab_s33 3030: pair co-occurrence by decile
with w as (
select
  z.ca,
  z.cb,
  z.util_decile,
  sum(z.ev_obs) as obs_ab_act,
  sum(z.ev_fmab) as obs_ab_act_fmab,
  count(*) as pers_ab,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    a.util_decile,
    cast(count(*) as bigint) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_fmab
  from @results_database_schema.cab_s04_device a
    inner join @results_database_schema.cab_s04_device b on a.person_id = b.person_id and a.start_bucket between b.start_bucket - @window_days and b.start_bucket + @window_days
     and a.concept_id < b.concept_id
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    a.util_decile
) z
group by z.ca, z.cb, z.util_decile
)
insert into @results_database_schema.cab_s33_strat_cum
select
  @batch_number as batch_number,
  3030 as pair_type,
  a.ca as concept_a,
  a.cb as concept_b,
  a.util_decile,
  a.obs_ab_act,
  a.obs_ab_act_fmab,
  a.pers_ab
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s33_strat_cum' as table_name, 8 as step, @now_expr as step_datetime;

-- cab_s33 3040: pair co-occurrence by decile
with w as (
select
  z.ca,
  z.cb,
  z.util_decile,
  sum(z.ev_obs) as obs_ab_act,
  sum(z.ev_fmab) as obs_ab_act_fmab,
  count(*) as pers_ab,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    a.util_decile,
    cast(count(*) as bigint) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_fmab
  from @results_database_schema.cab_s04_device a
    inner join @results_database_schema.cab_s05_drug b on a.person_id = b.person_id and a.start_bucket between b.start_bucket - @window_days and b.start_bucket + @window_days
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    a.util_decile
) z
group by z.ca, z.cb, z.util_decile
)
insert into @results_database_schema.cab_s33_strat_cum
select
  @batch_number as batch_number,
  3040 as pair_type,
  a.ca as concept_a,
  a.cb as concept_b,
  a.util_decile,
  a.obs_ab_act,
  a.obs_ab_act_fmab,
  a.pers_ab
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s33_strat_cum' as table_name, 9 as step, @now_expr as step_datetime;

-- cab_s33 4040: pair co-occurrence by decile
with w as (
select
  z.ca,
  z.cb,
  z.util_decile,
  sum(z.ev_obs) as obs_ab_act,
  sum(z.ev_fmab) as obs_ab_act_fmab,
  count(*) as pers_ab,
  sum(sum(z.ev_obs)) over (partition by z.ca, z.cb) as pair_total
from (
  select
    a.concept_id as ca,
    b.concept_id as cb,
    a.person_id as pid,
    a.util_decile,
    cast(count(*) as bigint) as ev_obs,
    sum(cast(case when a.concept_fm_flag = 1 and b.concept_fm_flag = 1 then 1 else 0 end as bigint)) as ev_fmab
  from @results_database_schema.cab_s05_drug a
    inner join @results_database_schema.cab_s05_drug b on a.person_id = b.person_id and a.start_bucket between b.start_bucket - @window_days and b.start_bucket + @window_days
     and a.concept_id < b.concept_id
  group by
    a.concept_id,
    b.concept_id,
    a.person_id,
    a.util_decile
) z
group by z.ca, z.cb, z.util_decile
)
insert into @results_database_schema.cab_s33_strat_cum
select
  @batch_number as batch_number,
  4040 as pair_type,
  a.ca as concept_a,
  a.cb as concept_b,
  a.util_decile,
  a.obs_ab_act,
  a.obs_ab_act_fmab,
  a.pers_ab
from w a
where a.pair_total > @cab_min_ab_obs;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'cab_s33_strat_cum' as table_name, 10 as step, @now_expr as step_datetime;


-- =========================================================
-- meas_obs_profile_s35_cum
-- Adjudication profile: per test concept, which result-bearing fields
-- are populated, counted by flag pattern. Descriptive only; NOT part of
-- the cab_s30 co-occurrence/statistics pipeline.
-- Two separate inserts (no union): src 50 = observation, 60 = measurement.
-- has_* = 1 means usable: concept columns not null and not 0; value/range
-- columns not null; value_as_string not null and not empty.
-- Columns absent from a domain are written NULL, not 0.
-- =========================================================

with s1 as ( -- flag each observation record in this batch
select
  a.observation_concept_id,
  case
    when a.value_as_concept_id is not null and a.value_as_concept_id <> 0 then 1
    else 0
  end as has_value_concept,
  case
    when a.value_as_number is not null then 1
    else 0
  end as has_value_number,
  case
    when a.value_as_string is not null and a.value_as_string <> '' then 1
    else 0
  end as has_value_string,
  case
    when a.unit_concept_id is not null and a.unit_concept_id <> 0 then 1
    else 0
  end as has_unit,
  case
    when a.qualifier_concept_id is not null and a.qualifier_concept_id <> 0 then 1
    else 0
  end as has_qualifier
from @source_cdm_schema.observation a
  inner join @results_database_schema.cab_person_batch b on a.person_id = b.person_id and @batch_number <= @data_profile_batch_limit
)
insert into @results_database_schema.meas_obs_profile_s35_cum
  (src, meas_obs_concept_id, has_value_concept, has_value_number, has_value_string,
  has_unit, has_qualifier, has_operator, has_range_low, has_range_high, n_records)
select
  50 as src,
  a.observation_concept_id as meas_obs_concept_id,
  a.has_value_concept,
  a.has_value_number,
  a.has_value_string,
  a.has_unit,
  a.has_qualifier,
  cast(null as int) as has_operator,
  cast(null as int) as has_range_low,
  cast(null as int) as has_range_high,
  count(*) as n_records
from s1 a
group by
  a.observation_concept_id,
  a.has_value_concept,
  a.has_value_number,
  a.has_value_string,
  a.has_unit,
  a.has_qualifier;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'meas_obs_profile_s35_cum' as table_name, 1 as step, @now_expr as step_datetime;


with s1 as ( -- flag each measurement record in this batch
select
  a.measurement_concept_id,
  case
    when a.value_as_concept_id is not null and a.value_as_concept_id <> 0 then 1
    else 0
  end as has_value_concept,
  case
    when a.value_as_number is not null then 1
    else 0
  end as has_value_number,
  case
    when a.unit_concept_id is not null and a.unit_concept_id <> 0 then 1
    else 0
  end as has_unit,
  case
    when a.operator_concept_id is not null and a.operator_concept_id <> 0 then 1
    else 0
  end as has_operator,
  case
    when a.range_low is not null then 1
    else 0
  end as has_range_low,
  case
    when a.range_high is not null then 1
    else 0
  end as has_range_high
from @source_cdm_schema.measurement a
  inner join @results_database_schema.cab_person_batch b on a.person_id = b.person_id and @batch_number <= @data_profile_batch_limit
)
insert into @results_database_schema.meas_obs_profile_s35_cum
  (src, meas_obs_concept_id, has_value_concept, has_value_number, has_value_string,
  has_unit, has_qualifier, has_operator, has_range_low, has_range_high, n_records)
select
  60 as src,
  a.measurement_concept_id as meas_obs_concept_id,
  a.has_value_concept,
  a.has_value_number,
  cast(null as int) as has_value_string,
  a.has_unit,
  cast(null as int) as has_qualifier,
  a.has_operator,
  a.has_range_low,
  a.has_range_high,
  count(*) as n_records
from s1 a
group by
  a.measurement_concept_id,
  a.has_value_concept,
  a.has_value_number,
  a.has_unit,
  a.has_operator,
  a.has_range_low,
  a.has_range_high;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'meas_obs_profile_s35_cum' as table_name, 2 as step, @now_expr as step_datetime;


-- =========================================================
-- meas_obs_attribute_s36_cum
-- Attribute detail behind the s35 flags: the actual concept ids found
-- in the result-modifying columns, per test concept, with record counts.
-- Two separate inserts (no union across domains): 50 = observation,
-- 60 = measurement. Null attribute ids excluded (s35 counts those via
-- the has_* flags); 0 retained as evidence of a failed mapping.
-- =========================================================

with s1 as ( -- observation result-modifying columns for this batch
select
  a.observation_concept_id,
  a.value_as_concept_id,
  a.unit_concept_id,
  a.qualifier_concept_id
from @source_cdm_schema.observation a
  inner join @results_database_schema.cab_person_batch b on a.person_id = b.person_id and @batch_number <= @data_profile_batch_limit
)
insert into @results_database_schema.meas_obs_attribute_s36_cum
  (src, meas_obs_concept_id, attribute, attribute_id, n_records)
select
  50 as src,
  a.observation_concept_id as meas_obs_concept_id,
  'VALUE_CONCEPT' as attribute,
  a.value_as_concept_id as attribute_id,
  count(*) as n_records
from s1 a
where a.value_as_concept_id is not null
group by
  a.observation_concept_id,
  a.value_as_concept_id
union all
select
  50 as src,
  a.observation_concept_id as meas_obs_concept_id,
  'UNIT' as attribute,
  a.unit_concept_id as attribute_id,
  count(*) as n_records
from s1 a
where a.unit_concept_id is not null
group by
  a.observation_concept_id,
  a.unit_concept_id
union all
select
  50 as src,
  a.observation_concept_id as meas_obs_concept_id,
  'QUALIFIER' as attribute,
  a.qualifier_concept_id as attribute_id,
  count(*) as n_records
from s1 a
where a.qualifier_concept_id is not null
group by
  a.observation_concept_id,
  a.qualifier_concept_id;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'meas_obs_attribute_s36_cum' as table_name, 1 as step, @now_expr as step_datetime;


with s1 as ( -- measurement result-modifying columns for this batch
select
  a.measurement_concept_id,
  a.value_as_concept_id,
  a.unit_concept_id,
  a.operator_concept_id
from @source_cdm_schema.measurement a
  inner join @results_database_schema.cab_person_batch b on a.person_id = b.person_id and @batch_number <= @data_profile_batch_limit
)
insert into @results_database_schema.meas_obs_attribute_s36_cum
  (src, meas_obs_concept_id, attribute, attribute_id, n_records)
select
  60 as src,
  a.measurement_concept_id as meas_obs_concept_id,
  'VALUE_CONCEPT' as attribute,
  a.value_as_concept_id as attribute_id,
  count(*) as n_records
from s1 a
where a.value_as_concept_id is not null
group by
  a.measurement_concept_id,
  a.value_as_concept_id
union all
select
  60 as src,
  a.measurement_concept_id as meas_obs_concept_id,
  'UNIT' as attribute,
  a.unit_concept_id as attribute_id,
  count(*) as n_records
from s1 a
where a.unit_concept_id is not null
group by
  a.measurement_concept_id,
  a.unit_concept_id
union all
select
  60 as src,
  a.measurement_concept_id as meas_obs_concept_id,
  'OPERATOR' as attribute,
  a.operator_concept_id as attribute_id,
  count(*) as n_records
from s1 a
where a.operator_concept_id is not null
group by
  a.measurement_concept_id,
  a.operator_concept_id;

insert into @results_database_schema.cab_process_log
select @batch_number as batch_number, 'meas_obs_attribute_s36_cum' as table_name, 2 as step, @now_expr as step_datetime;

