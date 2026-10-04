-- =============================================================================
-- OMOP CDM v5.4 PostgreSQL DDL for TAXIS Synthea Evaluation
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS cdm;
CREATE SCHEMA IF NOT EXISTS cohort;
CREATE SCHEMA IF NOT EXISTS work;

-- Set search path
SET search_path TO cdm;

-- Table: PERSON
CREATE TABLE IF NOT EXISTS cdm.person (
    person_id INTEGER NOT NULL,
    gender_concept_id INTEGER NOT NULL,
    year_of_birth INTEGER NOT NULL,
    month_of_birth INTEGER,
    day_of_birth INTEGER,
    birth_datetime TIMESTAMP,
    race_concept_id INTEGER NOT NULL,
    ethnicity_concept_id INTEGER NOT NULL,
    location_id INTEGER,
    provider_id INTEGER,
    care_site_id INTEGER,
    person_source_value VARCHAR(50),
    gender_source_value VARCHAR(50),
    gender_source_concept_id INTEGER,
    race_source_value VARCHAR(50),
    race_source_concept_id INTEGER,
    ethnicity_source_value VARCHAR(50),
    ethnicity_source_concept_id INTEGER
);

-- Table: OBSERVATION_PERIOD
CREATE TABLE IF NOT EXISTS cdm.observation_period (
    observation_period_id INTEGER NOT NULL,
    person_id INTEGER NOT NULL,
    observation_period_start_date DATE NOT NULL,
    observation_period_end_date DATE NOT NULL,
    period_type_concept_id INTEGER NOT NULL
);

-- Table: CONDITION_OCCURRENCE
CREATE TABLE IF NOT EXISTS cdm.condition_occurrence (
    condition_occurrence_id INTEGER NOT NULL,
    person_id INTEGER NOT NULL,
    condition_concept_id INTEGER NOT NULL,
    condition_start_date DATE NOT NULL,
    condition_start_datetime TIMESTAMP,
    condition_end_date DATE,
    condition_end_datetime TIMESTAMP,
    condition_type_concept_id INTEGER NOT NULL,
    condition_status_concept_id INTEGER,
    stop_reason VARCHAR(20),
    provider_id INTEGER,
    visit_occurrence_id INTEGER,
    visit_detail_id INTEGER,
    condition_source_value VARCHAR(50),
    condition_source_concept_id INTEGER,
    condition_status_source_value VARCHAR(50)
);

-- Table: DRUG_EXPOSURE
CREATE TABLE IF NOT EXISTS cdm.drug_exposure (
    drug_exposure_id INTEGER NOT NULL,
    person_id INTEGER NOT NULL,
    drug_concept_id INTEGER NOT NULL,
    drug_exposure_start_date DATE NOT NULL,
    drug_exposure_start_datetime TIMESTAMP,
    drug_exposure_end_date DATE NOT NULL,
    drug_exposure_end_datetime TIMESTAMP,
    verbatim_end_date DATE,
    drug_type_concept_id INTEGER NOT NULL,
    stop_reason VARCHAR(20),
    refills INTEGER,
    quantity NUMERIC,
    days_supply INTEGER,
    sig TEXT,
    route_concept_id INTEGER,
    lot_number VARCHAR(50),
    provider_id INTEGER,
    visit_occurrence_id INTEGER,
    visit_detail_id INTEGER,
    drug_source_value VARCHAR(50),
    drug_source_concept_id INTEGER,
    route_source_value VARCHAR(50),
    dose_unit_source_value VARCHAR(50)
);

-- Table: MEASUREMENT
CREATE TABLE IF NOT EXISTS cdm.measurement (
    measurement_id INTEGER NOT NULL,
    person_id INTEGER NOT NULL,
    measurement_concept_id INTEGER NOT NULL,
    measurement_date DATE NOT NULL,
    measurement_datetime TIMESTAMP,
    measurement_time VARCHAR(10),
    measurement_type_concept_id INTEGER NOT NULL,
    operator_concept_id INTEGER,
    value_as_number NUMERIC,
    value_as_concept_id INTEGER,
    unit_concept_id INTEGER,
    range_low NUMERIC,
    range_high NUMERIC,
    provider_id INTEGER,
    visit_occurrence_id INTEGER,
    visit_detail_id INTEGER,
    measurement_source_value VARCHAR(50),
    measurement_source_concept_id INTEGER,
    unit_source_value VARCHAR(50),
    unit_source_concept_id INTEGER,
    value_source_value VARCHAR(50),
    measurement_event_id INTEGER,
    meas_event_field_concept_id INTEGER
);

-- Table: PROCEDURE_OCCURRENCE
CREATE TABLE IF NOT EXISTS cdm.procedure_occurrence (
    procedure_occurrence_id INTEGER NOT NULL,
    person_id INTEGER NOT NULL,
    procedure_concept_id INTEGER NOT NULL,
    procedure_date DATE NOT NULL,
    procedure_datetime TIMESTAMP,
    procedure_end_date DATE,
    procedure_end_datetime TIMESTAMP,
    procedure_type_concept_id INTEGER NOT NULL,
    modifier_concept_id INTEGER,
    quantity INTEGER,
    provider_id INTEGER,
    visit_occurrence_id INTEGER,
    visit_detail_id INTEGER,
    procedure_source_value VARCHAR(50),
    procedure_source_concept_id INTEGER,
    modifier_source_value VARCHAR(50)
);

-- Table: CONCEPT
CREATE TABLE IF NOT EXISTS cdm.concept (
    concept_id INTEGER NOT NULL,
    concept_name VARCHAR(255) NOT NULL,
    domain_id VARCHAR(20) NOT NULL,
    vocabulary_id VARCHAR(20) NOT NULL,
    concept_class_id VARCHAR(20) NOT NULL,
    standard_concept VARCHAR(1),
    concept_code VARCHAR(50) NOT NULL,
    valid_start_date DATE NOT NULL,
    valid_end_date DATE NOT NULL,
    invalid_reason VARCHAR(1)
);

-- Table: CONCEPT_ANCESTOR
CREATE TABLE IF NOT EXISTS cdm.concept_ancestor (
    ancestor_concept_id INTEGER NOT NULL,
    descendant_concept_id INTEGER NOT NULL,
    min_levels_of_separation INTEGER NOT NULL,
    max_levels_of_separation INTEGER NOT NULL
);

-- Standard OHDSI Cohort Table in cohort schema
CREATE TABLE IF NOT EXISTS cohort.cohort (
    cohort_definition_id BIGINT NOT NULL,
    subject_id BIGINT NOT NULL,
    cohort_start_date DATE NOT NULL,
    cohort_end_date DATE NOT NULL
);

-- Indices for performance
CREATE INDEX IF NOT EXISTS idx_person_id ON cdm.person (person_id);
CREATE INDEX IF NOT EXISTS idx_cond_person ON cdm.condition_occurrence (person_id);
CREATE INDEX IF NOT EXISTS idx_cond_concept ON cdm.condition_occurrence (condition_concept_id);
CREATE INDEX IF NOT EXISTS idx_drug_person ON cdm.drug_exposure (person_id);
CREATE INDEX IF NOT EXISTS idx_drug_concept ON cdm.drug_exposure (drug_concept_id);
CREATE INDEX IF NOT EXISTS idx_cohort_subject ON cohort.cohort (subject_id);
CREATE INDEX IF NOT EXISTS idx_cohort_def ON cohort.cohort (cohort_definition_id);
