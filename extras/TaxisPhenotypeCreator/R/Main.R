# @file Main.R
#
# Copyright 2026 Observational Health Data Sciences and Informatics
#
# This file is part of TaxisPhenotypeCreator
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

#' Create and Compile Clinical Phenotype from Intent
#'
#' @description
#' High-level entry point to synthesize a computable OHDSI Circe JSON cohort definition
#' and optionally compile it into target DBMS cohort SQL.
#'
#' @param name                   Descriptive name of the clinical phenotype.
#' @param primaryConcepts        List or data frame of primary index concepts.
#' @param confirmatoryLabs       Optional list specifying confirmatory measurement concepts and thresholds.
#' @param indicatedDrugs         Optional list of indicated drug concepts.
#' @param exclusionConditions    Optional list of conflicting exclusion condition concepts.
#' @param priorObservationDays   Required continuous prior observation in days (default: 365).
#' @param compileSql             Whether to compile the synthesized Circe JSON into SQL (default: FALSE).
#' @param targetDialect          Target database dialect if compileSql is TRUE (default: "postgresql").
#' @param outputFolder           Optional directory to write the generated JSON and SQL files.
#'
#' @return A list containing the Circe JSON object and optionally the compiled SQL string.
#' @export
createPhenotype <- function(name,
                            primaryConcepts,
                            confirmatoryLabs = NULL,
                            indicatedDrugs = NULL,
                            exclusionConditions = NULL,
                            priorObservationDays = 365,
                            compileSql = FALSE,
                            targetDialect = "postgresql",
                            outputFolder = NULL) {

  message(sprintf("Synthesizing OHDSI Circe cohort for: '%s'...", name))
  circe <- synthesizeCirceCohort(
    name = name,
    primaryConcepts = primaryConcepts,
    confirmatoryLabs = confirmatoryLabs,
    indicatedDrugs = indicatedDrugs,
    exclusionConditions = exclusionConditions,
    priorObservationDays = priorObservationDays
  )

  sql <- NULL
  if (compileSql) {
    message(sprintf("Compiling cohort SQL for dialect '%s'...", targetDialect))
    sql <- compileCohortSql(circe, targetDialect = targetDialect)
  }

  if (!is.null(outputFolder)) {
    if (!dir.exists(outputFolder)) {
      dir.create(outputFolder, recursive = TRUE)
    }
    safeName <- gsub("[^A-Za-z0-9_]+", "_", name)
    jsonPath <- file.path(outputFolder, sprintf("%s.json", safeName))
    exportCirceJson(circe, jsonPath)
    message(sprintf("Exported Circe JSON to: %s", jsonPath))

    if (!is.null(sql)) {
      sqlPath <- file.path(outputFolder, sprintf("%s_%s.sql", safeName, targetDialect))
      writeLines(sql, sqlPath)
      message(sprintf("Exported Cohort SQL to: %s", sqlPath))
    }
  }

  list(circe = circe, sql = sql)
}

#' Export Circe List to Formatted JSON File
#'
#' @param circeList A list object representing an OHDSI Circe cohort definition.
#' @param filePath  Destination file path.
#' @import CirceR
#' @import SqlRender
#' @import jsonlite
#' @export
exportCirceJson <- function(circeList, filePath) {
  jsonStr <- jsonlite::toJSON(circeList, auto_unbox = TRUE, pretty = TRUE)
  writeLines(jsonStr, filePath)
  invisible(filePath)
}
