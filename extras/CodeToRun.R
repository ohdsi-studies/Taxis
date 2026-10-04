# ==============================================================================
# TAXIS Study Package: Network Execution Driver (CodeToRun.R)
# ==============================================================================
#
# Study Execution Protocol: Concept AB Association Mining Pipeline (Pipeline v57)
#
# This execution script orchestrates large-scale empirical association mining
# across local OMOP Common Data Model (CDM v5.4) instances, enforces mandatory
# small-cell suppression (< 5 masked to -1), and packages non-identifiable aggregate
# summary tables into an auditable zip archive for study coordination.
#
# Authorship & Attribution:
#   All SQL scripts (init, batch, finalize), 40-batch partitioning strategies,
#   directionality formulas, and original analytic algorithms were conceived,
#   designed, and authored by Stephen H. Bandeian, MD, JD.
#
# Study Leadership:
#   • Stephen H. Bandeian, MD, JD - Principal Investigator, Johns Hopkins University School of Medicine
#   • J. Marc Overhage, MD, PhD - Co-Principal Investigator, The Overhage Group / Indiana University School of Medicine
#   • Gowtham Rao, MD, PhD - Investigator, CoReason, Inc. USA; OHDSI Phenotype Development & Evaluation Workgroup
#   • Shaun Grannis, MD, MS - Investigator, Regenstrief Institute / Indiana University School of Medicine
#
# Privacy Safeguards:
#   - Federated local execution: analytical pipelines run entirely within institutional firewalls.
#   - Zero transmission of person-level data or individual health records.
#   - Mandatory small-cell suppression (< 5 masked to -1) across all exported count fields.
#   - Only aggregate analytical tables, timing logs, and diagnostic receipts are exported.
# ==============================================================================

# --- Step 0: Load Required Libraries ------------------------------------------
# If you haven't installed Taxis yet, you can install it locally:
# devtools::install_local(".")
library(Taxis)
library(DatabaseConnector)

# Ensure DatabaseConnector handles large 64-bit integer concept IDs smoothly
options(databaseConnectorInteger64AsNumeric = FALSE)

# --- Step 1: Database Connection Setup ----------------------------------------
# Enter your database credentials below or pass them in as environment variables.
# Supported platforms: postgresql, redshift, sql server, snowflake, oracle, bigquery
connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms         = Sys.getenv("DBMS", "postgresql"),
  server       = Sys.getenv("DB_SERVER", "localhost/cdm"),
  user         = Sys.getenv("DB_USER"),
  password     = Sys.getenv("DB_PASSWORD"),
  port         = as.numeric(Sys.getenv("DB_PORT", "5432")),
  pathToDriver = Sys.getenv("DATABASECONNECTOR_JAR_FOLDER", "C:/drivers"),
  extraSettings= Sys.getenv("DB_EXTRA_SETTINGS", "")
)

# --- Step 2: Configure Your Schemas and Folders -------------------------------
cdmDatabaseSchema      <- Sys.getenv("CDM_SCHEMA", "cdm")
resultsDatabaseSchema  <- Sys.getenv("RESULTS_SCHEMA", "taxis_results")

# The schema where the 6 pre-loaded reference lookup tables live (3.51M rows total).
# (Tables: cab_vocab_all_visit_hierarchy, cab_vocab_all_procedure, cab_vocab_all_device,
#  cab_vocab_all_chronic_conditions, cab_vocab_all_meas_obs_test, cab_vocab_all_drug_ing_form)
projectReferenceSchema <- Sys.getenv("PROJECT_REFERENCE_SCHEMA", "concept_ab_vocab")
omopReferenceSchema    <- Sys.getenv("OMOP_REFERENCE_SCHEMA", cdmDatabaseSchema)

# A short name identifying your database (e.g., "OptumEHR", "CCAE", "Synthea")
databaseId             <- Sys.getenv("DATABASE_ID", "MySite")
outputFolder           <- file.path(getwd(), sprintf("taxis_output_%s", databaseId))

# Execution Parameters:
# Phased Rollout Protocol (DEC-GR-030):
#   Phase A (Local Site Verification): Set partialRunBatchLimit = 1 to perform a
#          single-partition smoke test validating JDBC connectivity, permissions,
#          and table creation in ~30 seconds prior to production execution.
#   Phase B (Full Production Run): Set partialRunBatchLimit = 40 (the default) to
#          execute the complete association mining pipeline across all 40 balanced
#          patient partitions.
batchCount             <- as.integer(Sys.getenv("CAB_BATCH_COUNT", "40"))
partialRunBatchLimit   <- as.integer(Sys.getenv("CAB_PARTIAL_RUN_BATCH_LIMIT", "1")) # Phase A verification default

# Co-occurrence risk interval (default: 182 days)
windowDays             <- as.integer(Sys.getenv("CAB_WINDOW_DAYS", "182"))

# Index creation flag (disable for columnar data warehouse platforms, e.g., Snowflake, BigQuery)
createIndexDdl         <- tolower(Sys.getenv("CAB_CREATE_INDEX_DDL", "true")) %in% c("true", "1", "yes")

# --- Step 3: Run the Mining Pipeline and Package Results ----------------------
cat("\nInitiating TAXIS pipeline execution for database:", databaseId, "...\n")

Taxis::execute(
  connectionDetails      = connectionDetails,
  cdmDatabaseSchema      = cdmDatabaseSchema,
  resultsDatabaseSchema  = resultsDatabaseSchema,
  projectReferenceSchema = projectReferenceSchema,
  omopReferenceSchema    = omopReferenceSchema,
  outputFolder           = outputFolder,
  databaseId             = databaseId,
  batchCount             = batchCount,
  partialRunBatchLimit   = partialRunBatchLimit,
  dataProfileBatchLimit  = 2,
  windowDays             = windowDays,
  cabMinConceptObs       = 10,
  cabMinConditionalProb  = 0.001,
  cabMinAbObs            = 5,
  createIndexDdl         = createIndexDdl,
  dropCumTables          = FALSE,
  runMining              = TRUE,
  packageResults         = TRUE,
  minCellCount           = 5
)

# --- Step 4: Verify Packaged Output -------------------------------------------
# Upon successful execution, the packaged archive will be located at:
#   <outputFolder>/Results_Mining_<databaseId>.zip
#
# Data partners may inspect all packaged aggregate CSV tables prior to transmission
# to the study coordination center. All exported summaries comply with aggregate-only,
# cell-suppressed (< 5) privacy standards.
cat("\nTAXIS execution completed. Output archive generated in:\n", outputFolder, "\n\n")
