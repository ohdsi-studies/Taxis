# extras/test_run_concept_mining_package.R
# Test driver exercising Taxis package exported functions:
# Taxis::runConceptMining() and Taxis::packageMiningResults()

if (Sys.getenv("JAVA_HOME") == "") {
  Sys.setenv(JAVA_HOME = "C:/Program Files/DBeaver/jre")
}
options(databaseConnectorInteger64AsNumeric = FALSE)
library(Taxis)
library(DatabaseConnector)

cat("====================================================================\n")
cat(" TESTING TAXIS R PACKAGE DRIVERS: runConceptMining & packageMiningResults\n")
cat("====================================================================\n")

pathToDriver <- file.path(getwd(), "extras/testdata/jdbc")
if (!dir.exists(pathToDriver)) {
  stop("JDBC driver directory not found: ", pathToDriver)
}

connectionDetails <- createConnectionDetails(
  dbms         = "postgresql",
  server       = "localhost/synthea",
  port         = 5433,
  user         = "ohdsi_app",
  password     = "ohdsi_app_pass_2026",
  pathToDriver = pathToDriver
)

outputFolder <- file.path(getwd(), "extras/pkg_test_output")
if (!dir.exists(outputFolder)) {
  dir.create(outputFolder, recursive = TRUE)
}

cat("\n--> Step 1: Running Taxis::runConceptMining() with 1 batch partition...\n")
t0 <- Sys.time()
Taxis::runConceptMining(
  connectionDetails      = connectionDetails,
  cdmDatabaseSchema      = "cdm",
  resultsDatabaseSchema  = "work_cab_pkg_test",
  projectReferenceSchema = "concept_ab_vocab",
  omopReferenceSchema    = "cdm",
  batchCount             = 1,
  partialRunBatchLimit   = 1,
  dataProfileBatchLimit  = 1,
  windowDays             = 35,
  cabMinConceptObs       = 10,
  cabMinConditionalProb  = 0.001,
  cabMinAbObs            = 5,
  createIndexDdl         = TRUE,
  dropCumTables          = FALSE,
  runInit                = TRUE,
  runBatches             = TRUE,
  runFinalize            = TRUE,
  outputFolder           = outputFolder
)
durationSecs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
cat(sprintf("runConceptMining completed in %.2f seconds.\n", durationSecs))

cat("\n--> Step 2: Packaging Results via Taxis::packageMiningResults()...\n")
zipFile <- Taxis::packageMiningResults(
  connectionDetails     = connectionDetails,
  resultsDatabaseSchema = "work_cab_pkg_test",
  outputFolder          = outputFolder,
  databaseId            = "synthea_pkg_test",
  minCellCount          = 5
)

cat("Successfully generated archive:", zipFile, "\n")
stopifnot(file.exists(zipFile))

# Inspect contents of the zip
zipContents <- unzip(zipFile, list = TRUE)
cat("\nZip Archive File Manifest:\n")
print(zipContents[, c("Name", "Length")])

cat("\n====================================================================\n")
cat(" [SUCCESS] All Taxis R package drivers successfully verified!\n")
cat("====================================================================\n")
