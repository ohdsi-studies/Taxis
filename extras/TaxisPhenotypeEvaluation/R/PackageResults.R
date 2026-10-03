#' Package Non-PHI Results into a Compressed Zip Archive
#'
#' @details
#' Restricts exported bundle strictly to allowlisted, aggregate summary files:
#' - cohort_counts_<databaseId>.csv
#' - cohort_overlap_summary_<databaseId>.csv
#' - phevaluator_summary_<databaseId>.csv
#' - log_<databaseId>.txt
#' - diagnostics/Results_<databaseId>.zip (standard CohortDiagnostics aggregate archive)
#'
#' Zero patient-level data, person IDs, or intermediate scratch tables are included.
#'
#' @param outputFolder Path to the study execution output directory.
#' @param databaseId Short identifier for the database.
#'
#' @export
packageResults <- function(outputFolder,
                           databaseId) {

  zipFile <- file.path(outputFolder, sprintf("Results_%s.zip", databaseId))
  if (file.exists(zipFile)) {
    unlink(zipFile)
  }

  # Strict allowlist of permitted export artifacts
  allowlistPatterns <- c(
    sprintf("^cohort_counts_%s\\.csv$", databaseId),
    sprintf("^cohort_overlap_summary_%s\\.csv$", databaseId),
    sprintf("^phevaluator_summary_%s\\.csv$", databaseId),
    sprintf("^log_%s\\.txt$", databaseId),
    "^Results_.*\\.zip$" # CohortDiagnostics export zip
  )

  allFiles <- list.files(outputFolder, full.names = TRUE, recursive = TRUE)
  relFiles <- list.files(outputFolder, full.names = FALSE, recursive = TRUE)

  keepIndices <- c()
  for (i in seq_along(relFiles)) {
    fileName <- basename(relFiles[i])
    for (pattern in allowlistPatterns) {
      if (grepl(pattern, fileName, ignore.case = TRUE)) {
        keepIndices <- c(keepIndices, i)
        break
      }
    }
  }

  filesToZip <- allFiles[keepIndices]
  filesToZip <- filesToZip[filesToZip != zipFile]

  if (length(filesToZip) == 0) {
    ParallelLogger::logWarn(sprintf("No allowlisted files found in %s to package into %s.", outputFolder, zipFile))
  } else {
    ParallelLogger::logInfo(sprintf("Compressing %d allowlisted result files into %s...", length(filesToZip), zipFile))
    utils::zip(zipfile = zipFile, files = filesToZip, flags = "-r9Xq")
    ParallelLogger::logInfo(sprintf("Successfully generated allowlisted export package: %s", zipFile))
  }

  return(zipFile)
}
