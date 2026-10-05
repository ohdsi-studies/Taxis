# TaxisPhenotypeEvaluation 1.0.0 (Data Partner Testing Release)

Official release of the TaxisPhenotypeEvaluation HADES study package extension.

### Features & Capabilities
* **Multi-CDM Comparative Phenotype Evaluation**: Benchmarks 5 TAXIS-derived clinical phenotypes against peer-reviewed comparator cohorts from the OHDSI Phenotype Library.
* **Pairwise Cohort Overlap Matrices**: Computes patient-level intersection counts, unique patient counts, and symmetric Jaccard similarity indices.
* **Complementary Privacy Preservation**: Enforces mathematical 2x2 contingency table cell suppression (< 5 masked to -1) to prevent subtraction attacks (`REC-038-2`).
* **HADES Diagnostics & Evaluation Integration**: Pre-configured pipelines for `CohortDiagnostics` characterization and `PheValuator` diagnostic performance evaluation.
* **Strict Path Allowlist Packaging**: Automated packaging generates `Results_Evaluation_<databaseId>.zip` containing verified non-PHI tables.
* **Push-Button Runner**: Execution driver pre-configured in `extras/CodeToRun.R`.
