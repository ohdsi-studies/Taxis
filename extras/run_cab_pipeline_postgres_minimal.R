Sys.setenv(JAVA_HOME = "C:/Program Files/DBeaver/jre")
options(databaseConnectorInteger64AsNumeric = FALSE)
library(DatabaseConnector)
library(SqlRender)
library(digest)

cat("====================================================================\n")
cat(" CONCEPT_AB Mining Engine v57 - Bounded Minimal PostgreSQL Run\n")
cat("====================================================================\n")

startTime <- Sys.time()
runId <- paste0("run_", format(Sys.time(), "%Y%m%d_%H%M%S"))

# Configuration
dbHost <- "localhost"
dbPort <- 5433
dbName <- "synthea"
dbUser <- "ohdsi_app"
dbPass <- "ohdsi_app_pass_2026"

cdmSchema <- "cdm"
projectRefSchema <- "concept_ab_vocab"
omopRefSchema <- "cdm"
resultsSchema <- "work_cab_test"

batchCount <- 1
batchNumber <- 1
partialRunBatchLimit <- 1
dataProfileBatchLimit <- 1
windowDays <- 35

jarFolder <- "c:/files/git/github/ohdsi-studies/Taxis/extras/testdata/jdbc"
sqlDir <- "c:/files/git/github/ohdsi-studies/Taxis/inst/sql/sql_server"
receiptPath <- "c:/files/git/github/ohdsi-studies/Taxis/extras/pipeline_v57_run_receipt.json"

phaseResults <- list()
tableCounts <- list()

# Calculate dynamic digests of the SQL files actually executed
initPath  <- file.path(sqlDir, "concept_ab_init.sql")
batchPath <- file.path(sqlDir, "concept_ab_batch.sql")
finPath   <- file.path(sqlDir, "concept_ab_finalize.sql")

if (!file.exists(initPath) || !file.exists(batchPath) || !file.exists(finPath)) {
  stop("FATAL: Required SQL files not found in ", sqlDir)
}

sqlHashes <- list(
  concept_ab_init_sha256     = digest::digest(file = initPath, algo = "sha256"),
  concept_ab_batch_sha256    = digest::digest(file = batchPath, algo = "sha256"),
  concept_ab_finalize_sha256 = digest::digest(file = finPath, algo = "sha256")
)

cat("--> Verified SQL digests:\n")
cat("    init.sql    :", sqlHashes$concept_ab_init_sha256, "\n")
cat("    batch.sql   :", sqlHashes$concept_ab_batch_sha256, "\n")
cat("    finalize.sql:", sqlHashes$concept_ab_finalize_sha256, "\n")

# Pre-invalidate prior success by writing an initial RUNNING receipt (REC-063-1)
preReceipt <- list(
  run_id = runId,
  run_timestamp = strftime(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  status = "RUNNING",
  total_duration_seconds = 0,
  tool_versions = list(
    r_version = R.version.string,
    sqlrender_version = as.character(packageVersion("SqlRender")),
    databaseconnector_version = as.character(packageVersion("DatabaseConnector")),
    digest_version = as.character(packageVersion("digest"))
  ),
  sql_hashes = sqlHashes,
  parameters = list(
    dbms = "postgresql",
    database = dbName,
    cdm_schema = cdmSchema,
    project_reference_schema = projectRefSchema,
    results_schema = resultsSchema,
    batch_count = batchCount,
    batch_number = batchNumber,
    window_days = windowDays,
    threshold_support_count = 10,
    threshold_support_fraction = 0.001,
    threshold_pair_count = 5
  )
)
writeLines(as.character(jsonlite::toJSON(preReceipt, pretty = TRUE, auto_unbox = TRUE)), receiptPath)
cat("--> Pre-wrote RUNNING receipt to invalidate prior state (run_id:", runId, ")\n")

# Helper function to render, translate, and execute SQL with statement-splitting
executePhase <- function(connection, phaseName, sqlFileName, paramList) {
  cat("\n--------------------------------------------------------------------\n")
  cat(" Starting Phase:", phaseName, "(", sqlFileName, ")\n")
  cat("--------------------------------------------------------------------\n")
  sqlPath <- file.path(sqlDir, sqlFileName)
  rawSql <- paste(readLines(sqlPath, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  
  cat("--> Rendering SQL with SqlRender...\n")
  renderedSql <- do.call(render, c(list(sql = rawSql), paramList))
  
  cat("--> Translating to PostgreSQL dialect...\n")
  translatedSql <- translate(renderedSql, targetDialect = "postgresql")
  
  cat("--> Splitting SQL statements and filtering empty blocks...\n")
  statements <- splitSql(translatedSql)
  statements <- statements[nchar(trimws(statements)) > 0]
  cat(sprintf("    Executing %d statements...\n", length(statements)))
  
  t0 <- Sys.time()
  pb <- txtProgressBar(min = 0, max = length(statements), style = 3)
  for (i in seq_along(statements)) {
    executeSql(connection, statements[i], progressBar = FALSE)
    setTxtProgressBar(pb, i)
  }
  close(pb)
  t1 <- Sys.time()
  elapsedSecs <- round(difftime(t1, t0, units = "secs"), 2)
  cat("    Completed Phase:", phaseName, "in", elapsedSecs, "seconds.\n")
  return(list(status = "PASS", duration_seconds = as.numeric(elapsedSecs)))
}

# Main Execution Flow wrapped completely in tryCatch
executionFailed <- FALSE
errorMessage <- ""
conn <- NULL

tryCatch({
  # Connect to PostgreSQL
  cat("--> Connecting to PostgreSQL at", paste0(dbHost, ":", dbPort, "/", dbName), "...\n")
  connectionDetails <- createConnectionDetails(
    dbms = "postgresql",
    server = paste0(dbHost, "/", dbName),
    port = dbPort,
    user = dbUser,
    password = dbPass,
    pathToDriver = jarFolder
  )
  conn <- connect(connectionDetails)
  cat("    Connected successfully.\n")

  # Ensure results schema exists
  cat("--> Ensuring results schema '", resultsSchema, "' exists...\n", sep = "")
  executeSql(conn, paste0("CREATE SCHEMA IF NOT EXISTS ", resultsSchema, ";"), progressBar = FALSE)

  # Create and bind run receipt table in results schema to track identified run
  receiptDdl <- paste0(
    "CREATE TABLE IF NOT EXISTS ", resultsSchema, ".taxis_run_receipt (\n",
    "  run_id VARCHAR(64) PRIMARY KEY,\n",
    "  run_timestamp TIMESTAMP WITH TIME ZONE,\n",
    "  status VARCHAR(32),\n",
    "  batch_count INT,\n",
    "  window_days INT,\n",
    "  init_sha256 VARCHAR(64),\n",
    "  batch_sha256 VARCHAR(64),\n",
    "  finalize_sha256 VARCHAR(64)\n",
    ");"
  )
  executeSql(conn, receiptDdl, progressBar = FALSE)

  # Insert in-flight run record
  insertReceiptSql <- sprintf(
    "INSERT INTO %s.taxis_run_receipt (run_id, run_timestamp, status, batch_count, window_days, init_sha256, batch_sha256, finalize_sha256) VALUES ('%s', clock_timestamp(), 'RUNNING', %d, %d, '%s', '%s', '%s') ON CONFLICT (run_id) DO UPDATE SET status = 'RUNNING';",
    resultsSchema, runId, batchCount, windowDays, sqlHashes$concept_ab_init_sha256, sqlHashes$concept_ab_batch_sha256, sqlHashes$concept_ab_finalize_sha256
  )
  executeSql(conn, insertReceiptSql, progressBar = FALSE)
  cat("    Bound identified run to database table:", paste0(resultsSchema, ".taxis_run_receipt"), "\n")

  # Phase 1: INIT
  resInit <- executePhase(
    connection = conn,
    phaseName = "init",
    sqlFileName = "concept_ab_init.sql",
    paramList = list(
      source_cdm_schema        = cdmSchema,
      results_database_schema  = resultsSchema,
      batch_count              = batchCount,
      window_days              = windowDays,
      data_profile_batch_limit = dataProfileBatchLimit,
      create_index_ddl         = TRUE
    )
  )
  phaseResults[["init"]] <- resInit
  
  # Phase 2: BATCH (Partition 1 of 1)
  resBatch <- executePhase(
    connection = conn,
    phaseName = "batch_1",
    sqlFileName = "concept_ab_batch.sql",
    paramList = list(
      source_cdm_schema        = cdmSchema,
      project_reference_schema = projectRefSchema,
      results_database_schema  = resultsSchema,
      omop_reference_schema    = omopRefSchema,
      batch_count              = batchCount,
      batch_number             = batchNumber,
      cab_min_ab_obs           = 0,
      window_days              = windowDays,
      data_profile_batch_limit = dataProfileBatchLimit,
      now_expr                 = "clock_timestamp()",
      create_index_ddl         = TRUE
    )
  )
  phaseResults[["batch_1"]] <- resBatch
  
  # Phase 3: FINALIZE
  resFinal <- executePhase(
    connection = conn,
    phaseName = "finalize",
    sqlFileName = "concept_ab_finalize.sql",
    paramList = list(
      project_reference_schema = projectRefSchema,
      results_database_schema  = resultsSchema,
      omop_reference_schema    = omopRefSchema,
      max_batch_number         = batchNumber,
      cab_min_concept_obs      = 0,
      cab_min_conditional_prob = 0.0,
      window_days              = windowDays,
      create_index_ddl         = TRUE,
      drop_cum_tables          = FALSE
    )
  )
  phaseResults[["finalize"]] <- resFinal
  
  cat("\n====================================================================\n")
  cat(" PIPELINE EXECUTION SUCCEEDED!\n")
  cat(" Inspecting created tables in schema:", resultsSchema, "\n")
  cat("====================================================================\n")
  
  tablesQuery <- paste0(
    "SELECT table_name FROM information_schema.tables WHERE table_schema = '",
    resultsSchema,
    "' ORDER BY table_name;"
  )
  tables <- querySql(conn, tablesQuery)
  
  for (t in tables$table_name) {
    cntQuery <- paste0("SELECT COUNT(*) AS cnt FROM ", resultsSchema, ".", t, ";")
    cnt <- querySql(conn, cntQuery)
    cntVal <- as.numeric(cnt$cnt[1])
    tableCounts[[t]] <- cntVal
    cat(sprintf("  %-35s : %10.0f rows\n", paste0(resultsSchema, ".", t), cntVal))
  }

  # Update database run receipt to SUCCESS
  updateReceiptSql <- sprintf(
    "UPDATE %s.taxis_run_receipt SET status = 'SUCCESS' WHERE run_id = '%s';",
    resultsSchema, runId
  )
  executeSql(conn, updateReceiptSql, progressBar = FALSE)
  
}, error = function(e) {
  cat("\n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n")
  cat(" EXECUTION ERROR RECEIPT:\n")
  cat("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n")
  cat("Message:\n", e$message, "\n")
  executionFailed <<- TRUE
  errorMessage <<- e$message

  if (!is.null(conn)) {
    tryCatch({
      failSql <- sprintf(
        "UPDATE %s.taxis_run_receipt SET status = 'FAILED' WHERE run_id = '%s';",
        resultsSchema, runId
      )
      executeSql(conn, failSql, progressBar = FALSE)
    }, error = function(e2) {})
  }
}, finally = {
  if (!is.null(conn)) {
    disconnect(conn)
    cat("\nConnection closed.\n")
  }
})

# Compute overall execution receipt
endTime <- Sys.time()
totalElapsed <- as.numeric(round(difftime(endTime, startTime, units = "secs"), 2))

# Write final run receipt JSON
finalReceipt <- list(
  run_id = runId,
  run_timestamp = strftime(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  status = if (executionFailed) "FAILED" else "SUCCESS",
  total_duration_seconds = totalElapsed,
  tool_versions = list(
    r_version = R.version.string,
    sqlrender_version = as.character(packageVersion("SqlRender")),
    databaseconnector_version = as.character(packageVersion("DatabaseConnector")),
    digest_version = as.character(packageVersion("digest"))
  ),
  sql_hashes = sqlHashes,
  parameters = list(
    dbms = "postgresql",
    database = dbName,
    cdm_schema = cdmSchema,
    project_reference_schema = projectRefSchema,
    results_schema = resultsSchema,
    batch_count = batchCount,
    batch_number = batchNumber,
    window_days = windowDays,
    threshold_support_count = 10,
    threshold_support_fraction = 0.001,
    threshold_pair_count = 5
  ),
  phase_results = phaseResults,
  table_count = length(tableCounts),
  table_counts = tableCounts,
  error_message = if (executionFailed) errorMessage else NULL
)

writeLines(as.character(jsonlite::toJSON(finalReceipt, pretty = TRUE, auto_unbox = TRUE)), receiptPath)
cat("Execution receipt saved to:", receiptPath, "\n")

if (executionFailed) {
  cat("\n[FATAL] Pipeline failed. Exiting with status 1.\n")
  quit(status = 1, save = "no")
} else {
  cat("\n[SUCCESS] Pipeline completed successfully. Exiting with status 0.\n")
  quit(status = 0, save = "no")
}
