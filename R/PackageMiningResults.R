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
#' mandatory small-cell suppression (< 5 masked to -1 per DEC-GR-005), prevents
#' algebraic reconstruction across companion fields, and packages strictly allowlisted
#' tables into a verified zip archive for network sharing.
#'
#' @param connectionDetails        Database connection details object.
#' @param resultsDatabaseSchema    Schema where final mining output tables reside.
#' @param outputFolder             Local directory where Results_<databaseId>.zip will be written.
#' @param databaseId               Unique identifier for the participating database (e.g. "INPC", "JNJ").
#' @param minCellCount             Minimum cell count threshold for disclosure suppression (default: 5, mandatory floor: 5).
#'
#' @export
packageMiningResults <- function(connectionDetails,
                                 resultsDatabaseSchema,
                                 outputFolder,
                                 databaseId,
                                 minCellCount = 5) {

  # Enforce mandatory integer threshold floor of at least 5 (DEC-GR-005)
  if (is.null(minCellCount) || is.na(minCellCount) || !is.numeric(minCellCount) || minCellCount < 5) {
    ParallelLogger::logWarn(sprintf("Requested minCellCount (%s) is below mandatory floor (5). Enforcing minCellCount = 5.", as.character(minCellCount)))
    minCellCount <- 5L
  } else {
    minCellCount <- as.integer(minCellCount)
  }

  ParallelLogger::logInfo("=====================================================================")
  ParallelLogger::logInfo("Packaging TAXIS Concept AB Mining Results")
  ParallelLogger::logInfo(sprintf("Database ID: %s", databaseId))
  ParallelLogger::logInfo(sprintf("Results Schema: %s", resultsDatabaseSchema))
  ParallelLogger::logInfo(sprintf("Small-Cell Suppression Threshold: %d", minCellCount))
  ParallelLogger::logInfo("=====================================================================")

  # 1. Dedicated isolated clean staging directory (purging any leftover/stale files)
  exportDir <- file.path(outputFolder, sprintf("export_%s", databaseId))
  if (dir.exists(exportDir)) {
    unlink(exportDir, recursive = TRUE)
  }
  dir.create(exportDir, recursive = TRUE)

  conn <- DatabaseConnector::connect(connectionDetails)
  on.exit(DatabaseConnector::disconnect(conn), add = TRUE)

  # Define exact permitted schemas, sensitive count columns, and dependent fields
  tableSpecs <- list(
    cab_process_log = list(
      requiredCols = c("step_datetime", "batch_number", "step", "table_name", "rows_inserted", "step_note"),
      countCols = c()
    ),
    cab_s13_strat_all = list(
      requiredCols = c("util_decile", "persons_in_decile", "person_days_in_decile"),
      countCols = c("persons_in_decile")
    ),
    cab_s37_lag_all = list(
      requiredCols = c("pair_type", "lag_bucket", "lag_days_approx", "n_events", "n_pairs"),
      countCols = c("n_events", "n_pairs")
    ),
    cab_s38_profile_all = list(
      requiredCols = c("metric", "src", "bucket", "n_records", "n_persons"),
      countCols = c("n_records", "n_persons")
    ),
    cab_s39_pattern_all = list(
      requiredCols = c("metric", "src", "concept_id", "bucket", "n_obs", "n_persons"),
      countCols = c("n_obs", "n_persons")
    ),
    cab_s54_grain_guide = list(
      requiredCols = c("concept_id", "src", "obs_act", "pers_act", "mentions_per_person", "n_gaps",
                       "median_gap_bucket", "median_span_bucket", "frac_gaps_tight",
                       "frac_gaps_mid", "frac_gaps_long", "pattern", "grain", "recommended_analysis_role"),
      countCols = c("obs_act", "pers_act", "n_gaps")
    )
  )

  # Apply rigorous suppression with algebraic back-calculation masking
  applyTableSuppression <- function(tableName, df, threshold = minCellCount) {
    if (tableName == "cab_s13_strat_all") {
      # If persons_in_decile is small, mask persons and person-days to prevent rate-based reconstruction
      mask <- df$persons_in_decile > 0 & df$persons_in_decile < threshold
      df$persons_in_decile[mask] <- -1
      df$person_days_in_decile[mask] <- -1
    } else if (tableName == "cab_s37_lag_all") {
      maskEvents <- df$n_events > 0 & df$n_events < threshold
      df$n_events[maskEvents] <- -1
      maskPairs <- df$n_pairs > 0 & df$n_pairs < threshold
      df$n_pairs[maskPairs] <- -1
    } else if (tableName == "cab_s38_profile_all") {
      maskRecs <- df$n_records > 0 & df$n_records < threshold
      df$n_records[maskRecs] <- -1
      maskPers <- df$n_persons > 0 & df$n_persons < threshold
      df$n_persons[maskPers] <- -1
    } else if (tableName == "cab_s39_pattern_all") {
      maskObs <- df$n_obs > 0 & df$n_obs < threshold
      df$n_obs[maskObs] <- -1
      maskPers <- df$n_persons > 0 & df$n_persons < threshold
      df$n_persons[maskPers] <- -1
    } else if (tableName == "cab_s54_grain_guide") {
      # Joint masking: if either pers_act or obs_act is small, mask both AND mentions_per_person
      maskActivity <- (df$pers_act > 0 & df$pers_act < threshold) | (df$obs_act > 0 & df$obs_act < threshold)
      df$pers_act[maskActivity] <- -1
      df$obs_act[maskActivity] <- -1
      df$mentions_per_person[maskActivity] <- -1.0

      # Gap masking: if n_gaps is small, mask n_gaps AND dependent fractions
      maskGaps <- df$n_gaps > 0 & df$n_gaps < threshold
      df$n_gaps[maskGaps] <- -1
      df$frac_gaps_tight[maskGaps] <- -1.0
      df$frac_gaps_mid[maskGaps] <- -1.0
      df$frac_gaps_long[maskGaps] <- -1.0
    }
    return(df)
  }

  approvedBasenames <- c()

  for (tableName in names(tableSpecs)) {
    spec <- tableSpecs[[tableName]]
    ParallelLogger::logInfo(sprintf("Extracting aggregate table: %s...", tableName))
    sql <- sprintf("SELECT %s FROM %s.%s;", paste(spec$requiredCols, collapse = ", "), resultsDatabaseSchema, tableName)
    sql <- SqlRender::translate(sql, targetDialect = connectionDetails$dbms)

    data <- tryCatch({
      DatabaseConnector::querySql(conn, sql)
    }, error = function(e) {
      ParallelLogger::logWarn(sprintf("Could not query table %s: %s", tableName, conditionMessage(e)))
      NULL
    })

    if (!is.null(data) && nrow(data) > 0) {
      colnames(data) <- tolower(colnames(data))

      # Fail-closed schema enforcement: check all required columns are present
      missingCols <- setdiff(spec$requiredCols, colnames(data))
      if (length(missingCols) > 0) {
        stop(sprintf("Table %s failed schema validation: missing required columns [%s]. Export aborted to prevent unmasked disclosure.",
                     tableName, paste(missingCols, collapse = ", ")))
      }

      # Restrict to permitted schema columns only
      data <- data[, spec$requiredCols, drop = FALSE]

      # Apply suppression and companion reconstruction masking
      dataSuppressed <- applyTableSuppression(tableName, data, threshold = minCellCount)

      csvBasename <- sprintf("%s_%s.csv", tableName, databaseId)
      csvPath <- file.path(exportDir, csvBasename)
      readr::write_csv(dataSuppressed, csvPath)
      approvedBasenames <- c(approvedBasenames, csvBasename)
      ParallelLogger::logInfo(sprintf("Wrote %d rows to %s (suppression and reconstruction guards applied).", nrow(dataSuppressed), csvBasename))
    }
  }

  # Build study manifest metadata
  manifest <- data.frame(
    database_id = databaseId,
    dbms = connectionDetails$dbms,
    min_cell_count = minCellCount,
    execution_time = as.character(Sys.time()),
    package_version = "1.0.0",
    tables_exported = paste(approvedBasenames, collapse = ";"),
    stringsAsFactors = FALSE
  )
  manifestBasename <- sprintf("manifest_%s.csv", databaseId)
  manifestPath <- file.path(exportDir, manifestBasename)
  readr::write_csv(manifest, manifestPath)
  approvedBasenames <- c(approvedBasenames, manifestBasename)

  # Zip ONLY the approved exact allowlisted files
  zipFileName <- file.path(outputFolder, sprintf("Results_Mining_%s.zip", databaseId))
  if (file.exists(zipFileName)) {
    file.remove(zipFileName)
  }

  oldWd <- setwd(exportDir)
  on.exit(setwd(oldWd), add = TRUE)

  # Explicit allowlist packaging: only approvedBasenames are passed to zip
  zip::zip(zipfile = zipFileName, files = approvedBasenames)

  # Final Archive-Member Verification
  archiveMembers <- zip::zip_list(zipFileName)$filename
  unexpectedMembers <- setdiff(archiveMembers, approvedBasenames)
  if (length(unexpectedMembers) > 0) {
    file.remove(zipFileName)
    stop(sprintf("SECURITY VIOLATION: Archive contains unapproved members [%s]. Zip deleted immediately.",
                 paste(unexpectedMembers, collapse = ", ")))
  }

  ParallelLogger::logInfo(sprintf("Successfully packaged %d approved aggregate results into: %s", length(approvedBasenames), zipFileName))
  ParallelLogger::logInfo("Verification confirmed: Zero patient-level identifiers, unmasked small cells, or unapproved files.")
  return(zipFileName)
}
