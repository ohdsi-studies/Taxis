Sys.setenv(JAVA_HOME = "C:/Program Files/DBeaver/jre")
library(DatabaseConnector)
library(SqlRender)

cat("====================================================================\n")
cat(" CONCEPT_AB Mining Engine v57 - Bounded Minimal PostgreSQL Run\n")
cat("====================================================================\n")

startTime <- Sys.time()

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

# Connect
cat("--> Connecting to PostgreSQL at", paste0(dbHost, ":", dbPort, "/", dbName), "...\n")
connectionDetails <- createConnectionDetails(
  dbms = "postgresql",
  server = paste0(dbHost, "/", dbName),
  port = dbPort,
  user = dbUser,
  password = dbPass,
  pathToDriver = jarFolder
)

conn <- tryCatch({
  connect(connectionDetails)
}, error = function(e) {
  cat("FATAL: Failed to connect to PostgreSQL:", e$message, "\n")
  quit(status = 1, save = "no")
})
cat("    Connected successfully.\n")

# Ensure results schema exists
cat("--> Ensuring results schema '", resultsSchema, "' exists...\n", sep = "")
executeSql(conn, paste0("CREATE SCHEMA IF NOT EXISTS ", resultsSchema, ";"), progressBar = FALSE)

# Helper function to render, translate, dump, and execute SQL
executePhase <- function(phaseName, sqlFileName, paramList) {
  cat("\n--------------------------------------------------------------------\n")
  cat(" Starting Phase:", phaseName, "(", sqlFileName, ")\n")
  cat("--------------------------------------------------------------------\n")
  sqlPath <- file.path(sqlDir, sqlFileName)
  if (!file.exists(sqlPath)) {
    stop("SQL file does not exist: ", sqlPath)
  }
  
  rawSql <- paste(readLines(sqlPath, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  
  cat("--> Rendering SQL with SqlRender...\n")
  renderedSql <- do.call(render, c(list(sql = rawSql), paramList))
  
  cat("--> Translating to PostgreSQL dialect...\n")
  translatedSql <- translate(renderedSql, targetDialect = "postgresql")
  
  # Dump rendered SQL (optional debug)
  dumpDebugSql <- FALSE
  if (dumpDebugSql) {
    debugFile <- file.path("c:/files/git/github/ohdsi-studies/Taxis/extras", paste0("rendered_", phaseName, ".sql"))
    writeLines(translatedSql, debugFile)
    cat("    Saved rendered/translated SQL to:", debugFile, "\n")
  }
  
  cat("--> Splitting SQL statements and filtering empty blocks...\n")
  statements <- splitSql(translatedSql)
  statements <- statements[nchar(trimws(statements)) > 0]
  cat(sprintf("    Executing %d statements...\n", length(statements)))
  
  t0 <- Sys.time()
  pb <- txtProgressBar(min = 0, max = length(statements), style = 3)
  for (i in seq_along(statements)) {
    executeSql(conn, statements[i], progressBar = FALSE)
    setTxtProgressBar(pb, i)
  }
  close(pb)
  t1 <- Sys.time()
  elapsedSecs <- round(difftime(t1, t0, units = "secs"), 2)
  cat("    Completed Phase:", phaseName, "in", elapsedSecs, "seconds.\n")
  return(list(status = "PASS", duration_seconds = as.numeric(elapsedSecs)))
}

# Main Execution Flow
executionFailed <- FALSE
errorMessage <- ""

tryCatch({
  # Phase 1: INIT
  resInit <- executePhase(
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
    tableCounts[[t]] <- as.integer(cnt$cnt[1])
    cat(sprintf("  %-35s : %10d rows\n", paste0(resultsSchema, ".", t), cnt$cnt[1]))
  }
  
}, error = function(e) {
  cat("\n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n")
  cat(" EXECUTION ERROR RECEIPT:\n")
  cat("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n")
  cat("Message:\n", e$message, "\n")
  executionFailed <<- TRUE
  errorMessage <<- e$message
}, finally = {
  disconnect(conn)
  cat("\nConnection closed.\n")
})

# Compute overall execution receipt
endTime <- Sys.time()
totalElapsed <- as.numeric(round(difftime(endTime, startTime, units = "secs"), 2))

# Write run receipt JSON
receiptList <- list(
  run_timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ"),
  status = if (executionFailed) "FAILED" else "SUCCESS",
  total_duration_seconds = totalElapsed,
  tool_versions = list(
    r_version = R.version.string,
    sqlrender_version = as.character(packageVersion("SqlRender")),
    databaseconnector_version = as.character(packageVersion("DatabaseConnector"))
  ),
  sql_hashes = list(
    concept_ab_init_sha256 = "b6afbf6133882220d91d803ad8f51a7be8e70a58f47f2db8a2ba7433827ee595",
    concept_ab_batch_sha256 = "d4e833dccfc6eb3bd5768e146ebbb6242c730e1df07412f1db95e6834d8583fb",
    concept_ab_finalize_sha256 = "b0c5e6f2d8b63d9bd33c467aebaa2a4ec29124237198bb602c385f02bc6e71ef"
  ),
  parameters = list(
    dbms = "postgresql",
    database = dbName,
    cdm_schema = cdmSchema,
    project_reference_schema = projectRefSchema,
    results_schema = resultsSchema,
    batch_count = batchCount,
    batch_number = batchNumber,
    window_days = windowDays
  ),
  phase_results = phaseResults,
  table_count = length(tableCounts),
  table_counts = tableCounts,
  error_message = if (executionFailed) errorMessage else NULL
)

# Convert to JSON and save using jsonlite
jsonText <- jsonlite::toJSON(receiptList, pretty = TRUE, auto_unbox = TRUE)
writeLines(as.character(jsonText), receiptPath)
cat("Execution receipt saved to:", receiptPath, "\n")

if (executionFailed) {
  cat("\n[FATAL] Pipeline failed. Exiting with status 1.\n")
  quit(status = 1, save = "no")
} else {
  cat("\n[SUCCESS] Pipeline completed successfully. Exiting with status 0.\n")
  quit(status = 0, save = "no")
}
