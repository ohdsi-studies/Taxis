# @file RunDiagnostics.R
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

#' Run CohortDiagnostics on the Evaluation Cohorts
#'
#' @description
#' Executes the standard OHDSI \code{CohortDiagnostics} package across the 10
#' evaluation cohorts, generating incidence rates, cohort characterization,
#' index event breakdowns, and time distributions.
#'
#' @param connectionDetails        DatabaseConnector connection details object.
#' @param cdmDatabaseSchema        Schema containing OMOP CDM v5.4 clinical data.
#' @param cohortDatabaseSchema     Schema where cohort tables reside.
#' @param cohortTable              Name of the cohort table.
#' @param outputFolder             Local directory where diagnostics results will be saved.
#' @param databaseId               Unique identifier for the participating database.
#' @param minCellCount             Minimum cell count threshold for disclosure suppression (default: 5).
#'
#' @export
runDiagnostics <- function(connectionDetails,
                           cdmDatabaseSchema,
                           cohortDatabaseSchema,
                           cohortTable,
                           outputFolder,
                           databaseId,
                           minCellCount = 5) {

  diagFolder <- file.path(outputFolder, "diagnostics")
  if (!file.exists(diagFolder)) {
    dir.create(diagFolder, recursive = TRUE)
  }

  pathToCsv <- system.file("settings", "CohortsToCreate.csv", package = "TaxisPhenotypeEvaluation")
  cohortsToCreate <- readr::read_csv(pathToCsv, col_types = readr::cols())
  cohortTableNames <- CohortGenerator::getCohortTableNames(cohortTable = cohortTable)

  cohortDefinitionSet <- CohortGenerator::createEmptyCohortDefinitionSet()
  for (i in 1:nrow(cohortsToCreate)) {
    cid <- cohortsToCreate$cohortId[i]
    cname <- cohortsToCreate$cohortName[i]
    sqlFile <- system.file("sql", "sql_server", sprintf("%s.sql", cid), package = "TaxisPhenotypeEvaluation")
    jsonFile <- system.file("cohorts", sprintf("%s.json", cid), package = "TaxisPhenotypeEvaluation")

    cohortDefinitionSet <- rbind(
      cohortDefinitionSet,
      data.frame(
        cohortId = as.numeric(cid),
        cohortName = cname,
        sql = SqlRender::readSql(sqlFile),
        json = readr::read_file(jsonFile),
        stringsAsFactors = FALSE
      )
    )
  }

  ParallelLogger::logInfo("Executing CohortDiagnostics...")
  CohortDiagnostics::executeDiagnostics(
    cohortDefinitionSet = cohortDefinitionSet,
    connectionDetails = connectionDetails,
    cdmDatabaseSchema = cdmDatabaseSchema,
    cohortDatabaseSchema = cohortDatabaseSchema,
    cohortTable = cohortTable,
    exportFolder = diagFolder,
    databaseId = databaseId,
    runInclusionStatistics = TRUE,
    runIncludedSourceConcepts = TRUE,
    runOrphanConcepts = FALSE,
    runTimeDistributions = TRUE,
    runVisitContext = TRUE,
    runBreakdownIndexEvents = TRUE,
    runIncidenceRate = TRUE,
    runCohortOverlap = TRUE,
    runCohortCharacterization = TRUE,
    minCellCount = minCellCount
  )

  ParallelLogger::logInfo(sprintf("CohortDiagnostics export complete at %s", diagFolder))
}
