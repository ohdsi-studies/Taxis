Sys.setenv(JAVA_HOME = "C:/Program Files/DBeaver/jre")
library(DatabaseConnector)
library(SqlRender)

cat("====================================================================\n")
cat(" CONCEPT_AB Mining Engine v57 - Bounded Minimal PostgreSQL Run\n")
cat("====================================================================\n")

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

conn <- connect(connectionDetails)
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
  
  # Dump rendered SQL
  debugFile <- file.path("c:/files/git/github/ohdsi-studies/Taxis/extras", paste0("rendered_", phaseName, ".sql"))
  writeLines(translatedSql, debugFile)
  cat("    Saved rendered/translated SQL to:", debugFile, "\n")
  
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
  cat("    Completed Phase:", phaseName, "in", round(difftime(t1, t0, units = "secs"), 2), "seconds.\n")
}

# Execute Phases
tryCatch({
  # Phase 1: INIT
  executePhase(
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
  
  # Phase 2: BATCH (Partition 1 of 1)
  executePhase(
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
  
  # Phase 3: FINALIZE
  executePhase(
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
  print(tables)
  
  for (t in tables$table_name) {
    cntQuery <- paste0("SELECT COUNT(*) AS cnt FROM ", resultsSchema, ".", t, ";")
    cnt <- querySql(conn, cntQuery)
    cat(sprintf("  %-35s : %10d rows\n", paste0(resultsSchema, ".", t), cnt$cnt[1]))
  }
  
}, error = function(e) {
  cat("\n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n")
  cat(" EXECUTION ERROR RECEIPT:\n")
  cat("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n")
  cat("Message:\n", e$message, "\n")
  if (!is.null(e$call)) {
    cat("Call:\n")
    print(e$call)
  }
}, finally = {
  disconnect(conn)
  cat("\nConnection closed.\n")
})
