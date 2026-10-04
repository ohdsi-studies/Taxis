# @file Main.R
#
# Copyright 2026 Observational Health Data Sciences and Informatics
#
# This file is part of TaxisPhenotypeEvaluation
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

#' Execute the TAXIS Phenotype Evaluation Study Package
#'
#' @details
#' Orchestrates cohort creation, overlap calculation, CohortDiagnostics, and PheValuator
#' evaluation across federated OMOP CDM partner databases.
#'
#' @param connectionDetails An object of type \code{connectionDetails} created using the
#'   \code{\link[DatabaseConnector]{createConnectionDetails}} function.
#' @param cdmDatabaseSchema The name of the database schema that contains the OMOP CDM
#'   instance. Requires read permissions to this database.
#' @param cohortDatabaseSchema The name of the database schema where the user has write
#'   permissions to create and write to the cohort table.
#' @param cohortTable The name of the cohort table to create and populate. Default is 'taxis_pheno_eval'.
#' @param workDatabaseSchema The name of the database schema where temporary tables can be created. Default is cohortDatabaseSchema.
#' @param outputFolder The path to the folder where output CSVs and ZIP archives will be saved.
#' @param databaseId A short identifier for the database (e.g. 'Site_EHR', 'Site_Claims').
#' @param runCohortGeneration Logical: should cohorts be instantiated on the CDM? Default is TRUE.
#' @param runCohortOverlap Logical: should pairwise overlap and Jaccard similarity be computed? Default is TRUE.
#' @param runDiagnostics Logical: should CohortDiagnostics be executed? Default is TRUE.
#' @param runPheValuator Logical: should PheValuator evaluation be performed? Default is TRUE.
#' @param minCellCount Minimum count threshold for cell suppression (default is 5). Counts < minCellCount are masked.
#'
#' @export
execute <- function(connectionDetails,
                    cdmDatabaseSchema,
                    cohortDatabaseSchema,
                    cohortTable = "taxis_pheno_eval",
                    workDatabaseSchema = cohortDatabaseSchema,
                    outputFolder = "output",
                    databaseId = "My_CDM",
                    runCohortGeneration = TRUE,
                    runCohortOverlap = TRUE,
                    runDiagnostics = TRUE,
                    runPheValuator = TRUE,
                    minCellCount = 5) {

  if (!file.exists(outputFolder)) {
    dir.create(outputFolder, recursive = TRUE)
  }

  logFileName <- file.path(outputFolder, sprintf("log_%s.txt", databaseId))
  ParallelLogger::addDefaultFileLogger(logFileName)
  ParallelLogger::addDefaultConsoleLogger()
  on.exit(ParallelLogger::unregisterLogger("DEFAULT_FILE_LOGGER"))
  on.exit(ParallelLogger::unregisterLogger("DEFAULT_CONSOLE_LOGGER"), add = TRUE)

  ParallelLogger::logInfo("==================================================================")
  ParallelLogger::logInfo(" Starting TAXIS Network Phenotype Evaluation Package              ")
  ParallelLogger::logInfo(sprintf(" Database ID: %s", databaseId))
  ParallelLogger::logInfo(sprintf(" Output Folder: %s", outputFolder))
  ParallelLogger::logInfo("==================================================================")

  # Step 1: Cohort Generation
  if (runCohortGeneration) {
    ParallelLogger::logInfo("--> Step 1: Instantiating Cohorts via CohortGenerator...")
    createCohorts(
      connectionDetails = connectionDetails,
      cdmDatabaseSchema = cdmDatabaseSchema,
      cohortDatabaseSchema = cohortDatabaseSchema,
      cohortTable = cohortTable,
      outputFolder = outputFolder,
      databaseId = databaseId,
      minCellCount = minCellCount
    )
  } else {
    ParallelLogger::logInfo("--> Step 1: Cohort Generation skipped by user.")
  }

  # Step 2: Cohort Overlap & Jaccard Similarity
  if (runCohortOverlap) {
    ParallelLogger::logInfo("--> Step 2: Computing Cohort Overlap and Jaccard Similarity...")
    computeCohortOverlap(
      connectionDetails = connectionDetails,
      cohortDatabaseSchema = cohortDatabaseSchema,
      cohortTable = cohortTable,
      outputFolder = outputFolder,
      databaseId = databaseId,
      minCellCount = minCellCount
    )
  }

  # Step 3: CohortDiagnostics
  if (runDiagnostics) {
    ParallelLogger::logInfo("--> Step 3: Running CohortDiagnostics...")
    tryCatch({
      runDiagnostics(
        connectionDetails = connectionDetails,
        cdmDatabaseSchema = cdmDatabaseSchema,
        cohortDatabaseSchema = cohortDatabaseSchema,
        cohortTable = cohortTable,
        outputFolder = outputFolder,
        databaseId = databaseId,
        minCellCount = minCellCount
      )
    }, error = function(e) {
      ParallelLogger::logError(sprintf("CohortDiagnostics encountered an error: %s", e$message))
    })
  }

  # Step 4: PheValuator Evaluation
  if (runPheValuator) {
    ParallelLogger::logInfo("--> Step 4: Running PheValuator Phenotype Performance Evaluation...")
    tryCatch({
      runPheValuator(
        connectionDetails = connectionDetails,
        cdmDatabaseSchema = cdmDatabaseSchema,
        cohortDatabaseSchema = cohortDatabaseSchema,
        cohortTable = cohortTable,
        workDatabaseSchema = workDatabaseSchema,
        outputFolder = outputFolder,
        databaseId = databaseId
      )
    }, error = function(e) {
      ParallelLogger::logError(sprintf("PheValuator encountered an error: %s", e$message))
    })
  }

  # Step 5: Package Results into Non-PHI Zip
  ParallelLogger::logInfo("--> Step 5: Packaging Allowlisted Results into Zip Archive...")
  zipPath <- packageResults(
    outputFolder = outputFolder,
    databaseId = databaseId
  )

  ParallelLogger::logInfo("==================================================================")
  ParallelLogger::logInfo(" TAXIS Network Phenotype Evaluation Complete!                     ")
  ParallelLogger::logInfo(sprintf(" Output Archive: %s", zipPath))
  ParallelLogger::logInfo("==================================================================")

  return(invisible(zipPath))
}
