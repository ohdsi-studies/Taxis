# ==============================================================================
# TAXIS Network Phenotype Evaluation Study Package: Multi-Site Execution Driver
# ==============================================================================
#
# Target Phenotypes (TAXIS Knowledge Graph vs. OHDSI Phenotype Library):
#   1. COPD:                TAXIS 1798322 vs. Library 1263
#   2. Obesity:             TAXIS 1798323 vs. Library 1179
#   3. Chronic Kidney Dis:  TAXIS 1798324 vs. Library 1191
#   4. Hyperkalemia:        TAXIS 1798325 vs. Library 940
#   5. Type 2 Diabetes:     TAXIS 1798326 vs. Library 1032
#
# Privacy & Governance Safeguards:
#   - Zero patient-level data leaves the partner database.
#   - Only aggregate counts, masked overlap matrices, and diagnostic metrics are exported.
#   - All cell counts < 5 (and derived ratios when any cell is suppressed) are masked (-1).
#   - Concept-concept pair co-occurrence tables are NOT extracted.
#   - Detailed governance: see docs/governance/TAXIS_NETWORK_DATA_USE_TERM_SHEET.md
# ==============================================================================

# Install study package (from local directory or GitHub):
# devtools::install_local("extras/TaxisPhenotypeEvaluation")
# remotes::install_github("ohdsi-studies/Taxis", subdir = "extras/TaxisPhenotypeEvaluation")

library(TaxisPhenotypeEvaluation)
library(DatabaseConnector)

# --- 1. Database Connection Details -------------------------------------------
# Configure DBMS credentials for your OMOP CDM instance
# (Supported DBMS: postgresql, redshift, snowflake, sql server, oracle, spark)
connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms     = Sys.getenv("DBMS", "postgresql"),
  server   = Sys.getenv("DB_SERVER", "localhost/cdm"),
  user     = Sys.getenv("DB_USER"),
  password = Sys.getenv("DB_PASSWORD"),
  port     = as.numeric(Sys.getenv("DB_PORT", "5432")),
  pathToDriver = Sys.getenv("DATABASECONNECTOR_JAR_FOLDER", "C:/drivers")
)

# --- 2. Database Environment Configuration ------------------------------------
# Specify schemas and database identifier
cdmDatabaseSchema    <- Sys.getenv("CDM_SCHEMA", "cdm")
cohortDatabaseSchema <- Sys.getenv("COHORT_SCHEMA", "scratch")
cohortTable          <- "taxis_pheno_eval"
databaseId           <- Sys.getenv("DATABASE_ID", "My_Site_CDM")
outputFolder         <- file.path(getwd(), sprintf("taxis_output_%s", databaseId))

# --- 3. Execute Study Package -------------------------------------------------
# Set execution flags as appropriate for your site
TaxisPhenotypeEvaluation::execute(
  connectionDetails    = connectionDetails,
  cdmDatabaseSchema    = cdmDatabaseSchema,
  cohortDatabaseSchema = cohortDatabaseSchema,
  cohortTable          = cohortTable,
  outputFolder         = outputFolder,
  databaseId           = databaseId,
  runCohortGeneration  = TRUE,  # Step 1: Instantiates 10 cohorts via CohortGenerator
  runCohortOverlap     = TRUE,  # Step 2: Computes pairwise Jaccard index and set overlap
  runDiagnostics       = TRUE,  # Step 3: Executes CohortDiagnostics characterization
  runPheValuator       = FALSE, # Step 4: Optional PheValuator diagnostic modeling
  minCellCount         = 5      # Step 5: Enforces small-cell suppression (< 5 masked to -1)
)

# --- 4. Review and Share Aggregate Output -------------------------------------
# The resulting allowlisted archive will be located at:
#   <outputFolder>/Results_<databaseId>.zip
#
# Inspect the contents of Results_<databaseId>.zip prior to sharing to verify
# that only aggregate CSVs, diagnostic summaries, and run logs are present.
