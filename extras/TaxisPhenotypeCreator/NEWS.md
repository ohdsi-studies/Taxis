# TaxisPhenotypeCreator 1.0.0 (Data Partner Testing Release)

Official release of the TaxisPhenotypeCreator HADES study package extension.

### Features & Capabilities
* **Neuro-Symbolic Cohort Synthesis**: Transforms empirical clinical concept-pair associations and taxonomy relations into standardized OHDSI Circe JSON cohort expressions.
* **Deterministic 4-Slot Phenotype Architecture**:
  1. Primary Entry Criteria
  2. Confirmatory Laboratory Measurements
  3. Indicated First-Line Pharmacotherapies
  4. Differential Diagnosis Rule-Out Exclusions
* **Dialect SQL Compilation**: Programmatically compiles Circe cohort expressions into executable target DBMS SQL via `CirceR::buildCohortQuery()`.
* **5 Pre-Bundled Benchmark Clinical Phenotypes**:
  - Type 2 Diabetes Mellitus
  - Chronic Kidney Disease
  - Chronic Obstructive Pulmonary Disease (COPD)
  - Hyperkalemia
  - Obesity
* **Comprehensive Test Suite**: 26 unit tests covering slot-filling logic, Circe JSON validation, concept set creation, and compilation.
* **Push-Button Runner**: Execution driver pre-configured in `extras/CodeToRun.R`.
