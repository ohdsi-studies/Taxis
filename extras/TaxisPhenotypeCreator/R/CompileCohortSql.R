# @file CompileCohortSql.R
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

#' Compile Circe JSON to Target Dialect Cohort SQL
#'
#' @description
#' Uses the OHDSI Circe compiler (\code{CirceR::buildCohortQuery}) to translate a
#' computable Circe JSON expression into parameterized OHDSI SQL, and translates
#' to the requested target DBMS dialect via \code{SqlRender}.
#'
#' @param circeObject    A Circe JSON string or list object.
#' @param targetDialect  Target database dialect (e.g. "postgresql", "sql server", "redshift", "snowflake").
#'
#' @return A character string containing executable OHDSI SQL for cohort instantiation.
#' @export
compileCohortSql <- function(circeObject, targetDialect = "postgresql") {
  jsonString <- if (is.character(circeObject)) {
    circeObject
  } else {
    jsonlite::toJSON(circeObject, auto_unbox = TRUE, pretty = TRUE)
  }

  # Build OHDSI SQL via CirceR compiler
  options <- CirceR::createGenerateOptions(
    cohortIdFieldName = "cohort_definition_id",
    cohortId = 1,
    cdmSchema = "@cdm_database_schema",
    targetTable = "@target_cohort_table",
    resultSchema = "@target_cohort_schema",
    generateStats = FALSE
  )

  rawSql <- CirceR::buildCohortQuery(jsonString, options = options)

  # Translate to target DBMS dialect
  translatedSql <- SqlRender::translate(rawSql, targetDialect = targetDialect)
  return(translatedSql)
}
