# @file Main.R
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

#' Execute TAXIS Concept AB Association Mining Study Package
#'
#' @description
#' The primary execution entry point for the TAXIS Concept AB Mining Study Package.
#' Orchestrates database initialization, partitioned batch execution, statistical finalization,
#' small-cell suppression, and packaging of aggregate results for network dissemination.
#'
#' @param connectionDetails        An object of type \code{connectionDetails} created using the
#'                                 \code{\link[DatabaseConnector]{createConnectionDetails}} function.
#' @param cdmDatabaseSchema        Schema name where OMOP CDM v5.4 clinical data resides.
#' @param resultsDatabaseSchema    Schema name where cumulative and final result tables will be written.
#'                                 Requires CREATE, DROP, INSERT, UPDATE, SELECT permissions.
#' @param projectReferenceSchema   Schema containing pre-loaded TAXIS reference tables (cab_vocab_all_*).
#' @param omopReferenceSchema      Schema containing standardized OMOP vocabulary tables (default: cdmDatabaseSchema).
#' @param outputFolder             Local directory where logs, SQL dumps, and results archives will be stored.
#' @param databaseId               Short unique identifier for the database (e.g. 'INPC', 'JNJ_CCAE').
#' @param batchCount               Total number of random batches to partition patients into (default: 40).
#' @param partialRunBatchLimit     Number of batches to execute in this run (default: 40; set to 1 for test).
#' @param dataProfileBatchLimit    Number of batches to run descriptive profiling for (default: 2).
#' @param windowDays               Co-occurrence window width in days (default: 182).
#' @param cabMinConceptObs         Minimum per-concept event count to retain a pair (default: 10).
#' @param cabMinConditionalProb    Minimum conditional probability gate for pair retention (default: 0.001).
#' @param cabMinAbObs              Minimum A-B co-occurrence count in batch (default: 5).
#' @param createIndexDdl           Whether to emit CREATE INDEX and UPDATE STATISTICS DDL (default: TRUE).
#'                                 Must be set to FALSE for cloud columnar platforms (Snowflake, BigQuery).
#' @param dropCumTables            Whether to drop intermediate cumulative working tables after finalization (default: FALSE).
#' @param maxBatchNumber           Upper batch bound for finalization rollup (default: partialRunBatchLimit).
#' @param runMining                Whether to execute the Concept AB mining pipeline (default: TRUE).
#' @param packageResults           Whether to extract and package non-PHI aggregate results (default: TRUE).
#' @param minCellCount             Minimum count threshold for small-cell suppression (< 5 masked to -1, default: 5).
#'
#' @export
execute <- function(connectionDetails,
                    cdmDatabaseSchema,
                    resultsDatabaseSchema,
                    projectReferenceSchema,
                    omopReferenceSchema = cdmDatabaseSchema,
                    outputFolder = file.path(getwd(), sprintf("taxis_output_%s", databaseId)),
                    databaseId = "My_CDM",
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
                    runMining = TRUE,
                    packageResults = TRUE,
                    minCellCount = 5) {

  if (!dir.exists(outputFolder)) {
    dir.create(outputFolder, recursive = TRUE)
  }

  logFileName <- file.path(outputFolder, sprintf("taxis_execution_%s.log", databaseId))
  ParallelLogger::addDefaultFileLogger(logFileName)
  on.exit(ParallelLogger::unregisterLogger("DEFAULT_FILE_LOGGER"), add = TRUE)

  ParallelLogger::logInfo("=====================================================================")
  ParallelLogger::logInfo("TAXIS Network Study Package: Concept AB Mining Execution")
  ParallelLogger::logInfo(sprintf("Study Package: Taxis (v1.0.0)"))
  ParallelLogger::logInfo(sprintf("Database ID: %s", databaseId))
  ParallelLogger::logInfo(sprintf("Target DBMS: %s", connectionDetails$dbms))
  ParallelLogger::logInfo(sprintf("Output Folder: %s", outputFolder))
  ParallelLogger::logInfo("=====================================================================")

  if (runMining) {
    ParallelLogger::logInfo("Step 1: Running Concept AB Association Mining Pipeline...")
    runConceptMining(
      connectionDetails        = connectionDetails,
      cdmDatabaseSchema        = cdmDatabaseSchema,
      resultsDatabaseSchema    = resultsDatabaseSchema,
      projectReferenceSchema   = projectReferenceSchema,
      omopReferenceSchema      = omopReferenceSchema,
      batchCount               = batchCount,
      partialRunBatchLimit     = partialRunBatchLimit,
      dataProfileBatchLimit    = dataProfileBatchLimit,
      windowDays               = windowDays,
      cabMinConceptObs         = cabMinConceptObs,
      cabMinConditionalProb    = cabMinConditionalProb,
      cabMinAbObs              = cabMinAbObs,
      createIndexDdl           = createIndexDdl,
      dropCumTables            = dropCumTables,
      maxBatchNumber           = maxBatchNumber,
      runInit                  = TRUE,
      runBatches               = TRUE,
      runFinalize              = TRUE,
      outputFolder             = outputFolder
    )
    ParallelLogger::logInfo("Step 1 completed.")
  }

  if (packageResults) {
    ParallelLogger::logInfo("Step 2: Packaging non-PHI aggregate mining results...")
    zipFile <- packageMiningResults(
      connectionDetails        = connectionDetails,
      resultsDatabaseSchema    = resultsDatabaseSchema,
      outputFolder             = outputFolder,
      databaseId               = databaseId,
      minCellCount             = minCellCount
    )
    ParallelLogger::logInfo(sprintf("Step 2 completed: %s", zipFile))
  }

  ParallelLogger::logInfo("=====================================================================")
  ParallelLogger::logInfo("TAXIS Execution Finished Successfully.")
  ParallelLogger::logInfo("=====================================================================")
  invisible(TRUE)
}
