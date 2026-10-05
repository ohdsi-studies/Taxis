# ==============================================================================
# TAXIS Network Phenotype Evaluation: Eunomia Local Sanity Check
# ==============================================================================
# Use this script to run a 2-minute zero-setup local dry run on the synthetic
# Eunomia CDM (SQLite) before running on institutional production data.
# ==============================================================================

library(TaxisPhenotypeEvaluation)
library(DatabaseConnector)

message("--> Setting up local Eunomia SQLite test environment...")
if (!requireNamespace("Eunomia", quietly = TRUE)) {
  message("Installing Eunomia for local testing...")
  remotes::install_github("OHDSI/Eunomia")
}

connectionDetails <- Eunomia::getEunomiaConnectionDetails()
cdmDatabaseSchema <- "main"
cohortDatabaseSchema <- "main"
cohortTable <- "taxis_test_cohort"
outputFolder <- file.path(tempdir(), "taxis_eunomia_test")
databaseId <- "Eunomia_Synthetic"

message("--> Executing TaxisPhenotypeEvaluation on Eunomia...")
TaxisPhenotypeEvaluation::execute(
  connectionDetails    = connectionDetails,
  cdmDatabaseSchema    = cdmDatabaseSchema,
  cohortDatabaseSchema = cohortDatabaseSchema,
  cohortTable          = cohortTable,
  outputFolder         = outputFolder,
  databaseId           = databaseId,
  runCohortGeneration  = TRUE,
  runCohortOverlap     = TRUE,
  runDiagnostics       = FALSE, # Skip heavy characterization for 2-min dry run
  runPheValuator       = FALSE, # PheValuator requires larger cohort counts
  minCellCount         = 1      # Retain all cells for local synthetic testing
)

resultsZip <- file.path(outputFolder, sprintf("Results_%s.zip", databaseId))
if (file.exists(resultsZip)) {
  message(sprintf("SUCCESS: Test complete! Output zip generated at: %s", resultsZip))
} else {
  warning("Test completed but zip archive was not found.")
}
