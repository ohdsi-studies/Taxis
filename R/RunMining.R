# @file RunMining.R
#
# Copyright 2026 Observational Health Data Sciences and Informatics
#
# This file is part of Taxis
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#' Run Concept AB Association Mining Pipeline
#'
#' @description
#' Executes the 3-phase OHDSI Concept AB Association Mining Pipeline (Pipeline v57):
#' 1. \code{init}: Creates cumulative tables and partitions patients into random batches.
#' 2. \code{batch}: Iterates over batches, evaluating pair co-occurrence and temporal precedence.
#' 3. \code{finalize}: Rolls up cumulative tables, applies healthcare utilization decile stratification,
#' and outputs master association metrics (crude and stratified lift, odds ratios, directionality ratios).
#'
#' @param connectionDetails        An object of type \code{connectionDetails} created using the
#'                                 \code{\link[DatabaseConnector]{createConnectionDetails}} function.
#' @param cdmDatabaseSchema        Schema name where OMOP CDM v5.4 clinical data resides.
#' @param resultsDatabaseSchema    Schema name where cumulative and final result tables will be written.
#'                                 Requires CREATE, DROP, INSERT, UPDATE, SELECT permissions.
#' @param projectReferenceSchema   Schema containing pre-loaded TAXIS reference tables (cab_vocab_all_*).
#' @param omopReferenceSchema      Schema containing standardized OMOP vocabulary tables.
#' @param batchCount               Total number of random batches to partition patients into (default: 40).
#' @param partialRunBatchLimit     Number of batches to execute this run (default: 40; set to 1 for test).
#' @param dataProfileBatchLimit    Number of batches to run descriptive profiling for (default: 2).
#' @param windowDays               Co-occurrence window width in days (default: 182).
#' @param cabMinConceptObs         Minimum per-concept event count to retain a pair (default: 10).
#' @param cabMinConditionalProb    Minimum conditional probability gate for pair retention (default: 0.001).
#' @param cabMinAbObs              Minimum A-B co-occurrence count in batch (default: 5).
#' @param createIndexDdl           Whether to emit CREATE INDEX and UPDATE STATISTICS DDL (default: TRUE).
#'                                 Must be set to FALSE for cloud columnar platforms (Snowflake, BigQuery).
#' @param dropCumTables            Whether to drop intermediate per-batch cumulative tables after finalization (default: FALSE).
#' @param maxBatchNumber           Upper batch bound for finalization rollup (default: partialRunBatchLimit).
#' @param runInit                  Whether to execute the initialization phase (default: TRUE).
#' @param runBatches               Whether to execute the iterative batch loop (default: TRUE).
#' @param runFinalize              Whether to execute the rollup and finalization phase (default: TRUE).
#' @param outputFolder             Local directory where logs and diagnostic SQL dumps will be saved.
#'
#' @export
runConceptMining <- function(connectionDetails,
                             cdmDatabaseSchema,
                             resultsDatabaseSchema,
                             projectReferenceSchema,
                             omopReferenceSchema = cdmDatabaseSchema,
                             batchCount = 40,
                             partialRunBatchLimit = 40,
                             dataProfileBatchLimit = 2,
                             windowDays = 182,
                             cabMinConceptObs = 10,
                             cabMinConditionalProb = 0.001,
                             cabMinAbObs = 5,
                             createIndexDdl = TRUE,
                             dropCumTables = FALSE,
                             maxBatchNumber = NULL,
                             runInit = TRUE,
                             runBatches = TRUE,
                             runFinalize = TRUE,
                             outputFolder = file.path(getwd(), "taxis_mining_output")) {

  if (!dir.exists(outputFolder)) {
    dir.create(outputFolder, recursive = TRUE)
  }

  logFileName <- file.path(outputFolder, "taxis_mining_execution.log")
  ParallelLogger::addDefaultFileLogger(logFileName)
  on.exit(ParallelLogger::unregisterLogger("DEFAULT_FILE_LOGGER"), add = TRUE)

  ParallelLogger::logInfo("=====================================================================")
  ParallelLogger::logInfo("TAXIS Concept AB Association Mining Engine (Pipeline v57)")
  ParallelLogger::logInfo(sprintf("Target DBMS: %s", connectionDetails$dbms))
  ParallelLogger::logInfo(sprintf("CDM Schema: %s", cdmDatabaseSchema))
  ParallelLogger::logInfo(sprintf("Results Schema: %s", resultsDatabaseSchema))
  ParallelLogger::logInfo(sprintf("Batch Count: %d | Partial Limit: %d", batchCount, partialRunBatchLimit))
  ParallelLogger::logInfo(sprintf("Create Index DDL: %s", as.character(createIndexDdl)))
  ParallelLogger::logInfo("=====================================================================")

  # Resolve SQL file locations from package resources
  initSqlPath  <- system.file("sql/sql_server", "concept_ab_init.sql", package = "Taxis")
  batchSqlPath <- system.file("sql/sql_server", "concept_ab_batch.sql", package = "Taxis")
  finSqlPath   <- system.file("sql/sql_server", "concept_ab_finalize.sql", package = "Taxis")

  if (!file.exists(initSqlPath)) {
    # Fallback to local source path if running in development mode
    initSqlPath <- file.path(getwd(), "inst", "sql", "sql_server", "concept_ab_init.sql")
    batchSqlPath <- file.path(getwd(), "inst", "sql", "sql_server", "concept_ab_batch.sql")
    finSqlPath <- file.path(getwd(), "inst", "sql", "sql_server", "concept_ab_finalize.sql")
  }

  stopifnot(file.exists(initSqlPath))
  stopifnot(file.exists(batchSqlPath))
  stopifnot(file.exists(finSqlPath))

  # Establish database connection
  conn <- DatabaseConnector::connect(connectionDetails)
  on.exit(DatabaseConnector::disconnect(conn), add = TRUE)

  # Determine dialect-appropriate timestamp expression
  nowExpr <- if (tolower(connectionDetails$dbms) == "postgresql") "clock_timestamp()" else "CURRENT_TIMESTAMP"

  # Determine finalization batch upper limit
  if (is.null(maxBatchNumber) || is.na(maxBatchNumber) || maxBatchNumber < 1L) {
    maxBatchNumber <- partialRunBatchLimit
  }

  read_sql <- function(p) paste(readLines(p, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

  # ---------------------------------------------------------
  # Phase 1: Init (Scaffolding & Population Partitioning)
  # ---------------------------------------------------------
  if (runInit) {
    ParallelLogger::logInfo("Executing Phase 1: Initialization (concept_ab_init.sql)...")
    sql <- SqlRender::render(
      read_sql(initSqlPath),
      source_cdm_schema       = cdmDatabaseSchema,
      results_database_schema = resultsDatabaseSchema,
      batch_count             = batchCount,
      create_index_ddl        = createIndexDdl
    )
    sqlFinal <- SqlRender::translate(sql, targetDialect = connectionDetails$dbms)

    tryCatch(
      DatabaseConnector::executeSql(conn, sqlFinal, progressBar = TRUE),
      error = function(e) {
        ParallelLogger::logWarn(sprintf("Init failed: %s - attempting reconnect & retry...", conditionMessage(e)))
        try(DatabaseConnector::disconnect(conn), silent = TRUE)
        conn <<- DatabaseConnector::connect(connectionDetails)
        DatabaseConnector::executeSql(conn, sqlFinal, progressBar = TRUE)
      }
    )
    ParallelLogger::logInfo("Phase 1: Initialization completed successfully.")
  }

  # ---------------------------------------------------------
  # Phase 2: Batch Processing Loop
  # ---------------------------------------------------------
  if (runBatches) {
    batchList <- 1:partialRunBatchLimit
    ParallelLogger::logInfo(sprintf("Executing Phase 2: Batch loop across %d batches...", length(batchList)))
    startTime <- proc.time()

    for (b in batchList) {
      ParallelLogger::logInfo(sprintf("Processing Batch %d of %d (total partitions: %d)...", b, partialRunBatchLimit, batchCount))
      sql <- SqlRender::render(
        read_sql(batchSqlPath),
        source_cdm_schema        = cdmDatabaseSchema,
        project_reference_schema = projectReferenceSchema,
        results_database_schema  = resultsDatabaseSchema,
        omop_reference_schema    = omopReferenceSchema,
        batch_count              = batchCount,
        batch_number             = b,
        cab_min_ab_obs           = cabMinAbObs,
        window_days              = windowDays,
        data_profile_batch_limit = dataProfileBatchLimit,
        create_index_ddl         = createIndexDdl,
        now_expr                 = nowExpr
      )
      sqlFinal <- SqlRender::translate(sql, targetDialect = connectionDetails$dbms)
      DatabaseConnector::executeSql(conn, sqlFinal, progressBar = TRUE)
    }

    elapsedSeconds <- (proc.time() - startTime)["elapsed"]
    ParallelLogger::logInfo(sprintf("Phase 2: Completed %d batches in %.2f minutes (%.2f seconds).",
                                    length(batchList), elapsedSeconds / 60, elapsedSeconds))
  }

  # ---------------------------------------------------------
  # Phase 3: Finalize (Aggregation & Stratification)
  # ---------------------------------------------------------
  if (runFinalize) {
    ParallelLogger::logInfo(sprintf("Executing Phase 3: Finalization rollup (batches 1 through %d)...", maxBatchNumber))
    sql <- SqlRender::render(
      read_sql(finSqlPath),
      project_reference_schema  = projectReferenceSchema,
      results_database_schema   = resultsDatabaseSchema,
      omop_reference_schema     = omopReferenceSchema,
      cab_min_concept_obs       = cabMinConceptObs,
      cab_min_conditional_prob  = cabMinConditionalProb,
      window_days               = windowDays,
      create_index_ddl          = createIndexDdl,
      max_batch_number          = maxBatchNumber,
      drop_cum_tables           = dropCumTables
    )
    sqlFinal <- SqlRender::translate(sql, targetDialect = connectionDetails$dbms)
    DatabaseConnector::executeSql(conn, sqlFinal, progressBar = TRUE)
    ParallelLogger::logInfo("Phase 3: Finalization completed successfully.")
  }

  ParallelLogger::logInfo("TAXIS Concept AB Association Mining Pipeline execution finished.")
  invisible(TRUE)
}
