# ==============================================================================
# TAXIS Concept AB Mining Study Package: Network Execution Driver (CodeToRun.R)
# ==============================================================================
#
# Study: Temporal Association eXploration for Clinical Inference Studies (TAXIS)
# Component: Concept AB Association Mining Engine (Pipeline v57)
# Study Leadership:
#   • Stephen H. Bandeian, MD, JD - Principal Investigator, Johns Hopkins University
#   • J. Marc Overhage, MD, PhD - Co-Principal Investigator, The Overhage Group / Indiana Univ
#   • Gowtham Rao, MD, PhD - Investigator, CoReason, Inc. / OHDSI
#   • Shaun Grannis, MD, MS - Investigator, Regenstrief Institute / Indiana Univ
#
# Privacy & Governance Safeguards:
#   - Zero patient-level data leaves the partner database.
#   - All cell counts < 5 are masked to -1 (DEC-GR-005).
#   - Only aggregate tables, recording patterns, and timing logs are exported.
#   - Detailed governance: see docs/governance/TAXIS_NETWORK_DATA_USE_TERM_SHEET.md
# ==============================================================================

# --- Step 0: Install Study Package --------------------------------------------
# Install directly from GitHub or from local clone:
# remotes::install_github("ohdsi-studies/Taxis")
# devtools::install_local(".")

library(Taxis)
library(DatabaseConnector)

# --- Step 1: Database Connection Configuration --------------------------------
# Configure DBMS credentials for your OMOP CDM instance
# (Supported DBMS: postgresql, redshift, sql server, snowflake, oracle, bigquery)
connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms         = Sys.getenv("DBMS", "postgresql"),
  server       = Sys.getenv("DB_SERVER", "localhost/cdm"),
  user         = Sys.getenv("DB_USER"),
  password     = Sys.getenv("DB_PASSWORD"),
  port         = as.numeric(Sys.getenv("DB_PORT", "5432")),
  pathToDriver = Sys.getenv("DATABASECONNECTOR_JAR_FOLDER", "C:/drivers"),
  extraSettings= Sys.getenv("DB_EXTRA_SETTINGS", "")
)

# --- Step 2: Database Environment & Schema Specification ----------------------
cdmDatabaseSchema      <- Sys.getenv("CDM_SCHEMA", "cdm")
resultsDatabaseSchema  <- Sys.getenv("RESULTS_SCHEMA", "taxis_results")
projectReferenceSchema <- Sys.getenv("PROJECT_REFERENCE_SCHEMA", "taxis_lookups")
omopReferenceSchema    <- Sys.getenv("OMOP_REFERENCE_SCHEMA", cdmDatabaseSchema)
databaseId             <- Sys.getenv("DATABASE_ID", "My_Site_CDM")
outputFolder           <- file.path(getwd(), sprintf("taxis_output_%s", databaseId))

# Execution parameters
batchCount             <- as.integer(Sys.getenv("CAB_BATCH_COUNT", "40"))
partialRunBatchLimit   <- as.integer(Sys.getenv("CAB_PARTIAL_RUN_BATCH_LIMIT", "40"))
# Set createIndexDdl = FALSE for cloud columnar platforms (Snowflake, BigQuery)
createIndexDdl         <- tolower(Sys.getenv("CAB_CREATE_INDEX_DDL", "true")) %in% c("true", "1", "yes")

# --- Step 3: Execute Study Package --------------------------------------------
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
  windowDays             = 182,
  cabMinConceptObs       = 10,
  cabMinConditionalProb  = 0.001,
  cabMinAbObs            = 5,
  createIndexDdl         = createIndexDdl,
  dropCumTables          = FALSE,
  runMining              = TRUE,
  packageResults         = TRUE,
  minCellCount           = 5
)

# --- Step 4: Review and Transmit Aggregate Output -----------------------------
# The resulting allowlisted archive will be located at:
#   <outputFolder>/Results_Mining_<databaseId>.zip
#
# Inspect the contents of Results_Mining_<databaseId>.zip prior to sharing to
# confirm that only non-PHI aggregate CSVs and timing logs are present.
