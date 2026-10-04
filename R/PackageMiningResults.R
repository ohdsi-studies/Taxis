# @file PackageMiningResults.R
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

#' Package Concept AB Association Mining Results
#'
#' @description
#' Extracts non-PHI aggregate mining summary tables from the results schema, applies
#' mandatory small-cell suppression (< 5 masked to -1 per DEC-GR-005), and packages
#' them into an allowlisted zip archive for network sharing.
#'
#' @param connectionDetails        Database connection details object.
#' @param resultsDatabaseSchema    Schema where final mining output tables reside.
#' @param outputFolder             Local directory where Results_<databaseId>.zip will be written.
#' @param databaseId               Unique identifier for the participating database (e.g. "INPC", "JNJ").
#' @param minCellCount             Minimum cell count threshold for disclosure suppression (default: 5).
#'
#' @export
packageMiningResults <- function(connectionDetails,
                                 resultsDatabaseSchema,
                                 outputFolder,
                                 databaseId,
                                 minCellCount = 5) {

  ParallelLogger::logInfo("=====================================================================")
  ParallelLogger::logInfo("Packaging TAXIS Concept AB Mining Results")
  ParallelLogger::logInfo(sprintf("Database ID: %s", databaseId))
  ParallelLogger::logInfo(sprintf("Results Schema: %s", resultsDatabaseSchema))
  ParallelLogger::logInfo(sprintf("Small-Cell Suppression Threshold: %d", minCellCount))
  ParallelLogger::logInfo("=====================================================================")

  exportDir <- file.path(outputFolder, sprintf("export_%s", databaseId))
  if (!dir.exists(exportDir)) {
    dir.create(exportDir, recursive = TRUE)
  }

  conn <- DatabaseConnector::connect(connectionDetails)
  on.exit(DatabaseConnector::disconnect(conn), add = TRUE)

  # Small-cell suppression helper function
  suppressSmallCells <- function(df, countColumns, threshold = minCellCount) {
    for (col in countColumns) {
      if (col %in% colnames(df)) {
        df[[col]] <- ifelse(df[[col]] > 0 & df[[col]] < threshold, -1, df[[col]])
      }
    }
    return(df)
  }

  # Allowlisted aggregate tables to extract
  tablesToExport <- list(
    list(name = "cab_process_log", countCols = c()),
    list(name = "cab_s54_grain_guide", countCols = c("n_records", "n_events")),
    list(name = "cab_s39_pattern_all", countCols = c("count_val", "n_events")),
    list(name = "cab_s37_lag_all", countCols = c("n_events", "n_pairs")),
    list(name = "cab_s38_profile_all", countCols = c("n_records", "n_persons")),
    list(name = "cab_s13_strat_all", countCols = c("persons_in_decile", "person_days_in_decile"))
  )

  exportedFiles <- c()

  for (tbl in tablesToExport) {
    tableName <- tbl$name
    ParallelLogger::logInfo(sprintf("Extracting aggregate table: %s...", tableName))
    sql <- sprintf("SELECT * FROM %s.%s;", resultsDatabaseSchema, tableName)
    sql <- SqlRender::translate(sql, targetDialect = connectionDetails$dbms)

    data <- tryCatch({
      DatabaseConnector::querySql(conn, sql)
    }, error = function(e) {
      ParallelLogger::logWarn(sprintf("Could not query table %s: %s", tableName, conditionMessage(e)))
      NULL
    })

    if (!is.null(data) && nrow(data) > 0) {
      colnames(data) <- tolower(colnames(data))
      dataSuppressed <- suppressSmallCells(data, tbl$countCols, threshold = minCellCount)
      csvPath <- file.path(exportDir, sprintf("%s_%s.csv", tableName, databaseId))
      readr::write_csv(dataSuppressed, csvPath)
      exportedFiles <- c(exportedFiles, csvPath)
      ParallelLogger::logInfo(sprintf("Wrote %d rows to %s (suppression applied).", nrow(dataSuppressed), basename(csvPath)))
    }
  }

  # Build study manifest metadata
  manifest <- data.frame(
    database_id = databaseId,
    dbms = connectionDetails$dbms,
    min_cell_count = minCellCount,
    execution_time = as.character(Sys.time()),
    package_version = "1.0.0",
    stringsAsFactors = FALSE
  )
  manifestPath <- file.path(exportDir, sprintf("manifest_%s.csv", databaseId))
  readr::write_csv(manifest, manifestPath)
  exportedFiles <- c(exportedFiles, manifestPath)

  # Zip the exported allowlisted aggregate files
  zipFileName <- file.path(outputFolder, sprintf("Results_Mining_%s.zip", databaseId))
  if (file.exists(zipFileName)) {
    file.remove(zipFileName)
  }

  oldWd <- setwd(exportDir)
  on.exit(setwd(oldWd), add = TRUE)

  relativeFiles <- list.files(".", full.names = FALSE)
  zip::zip(zipfile = zipFileName, files = relativeFiles)

  ParallelLogger::logInfo(sprintf("Successfully packaged aggregate results into: %s", zipFileName))
  ParallelLogger::logInfo("Zero patient-level identifiers or unmasked small cells exported.")
  return(zipFileName)
}
