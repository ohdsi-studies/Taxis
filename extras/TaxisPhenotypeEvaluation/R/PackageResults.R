#' Package Non-PHI Results into a Compressed Zip Archive
#'
#' @details
#' Restricts exported bundle strictly to allowlisted, aggregate summary files:
#' - cohort_counts_<databaseId>.csv
#' - cohort_overlap_summary_<databaseId>.csv
#' - phevaluator_summary_<databaseId>.csv
#' - diagnostics/Results_<databaseId>.zip (inspected for approved aggregate CSVs only)
#'
#' Enforces strict non-disclosure protections:
#' - Explicit relative path matching (rejects arbitrary subdirectories, scratch folders, and decoys).
#' - Rejects files from any database ID other than the specified databaseId.
#' - Excludes execution logs (.log/.txt) and raw/unfiltered patient tables.
#' - Deep-inspects any nested CohortDiagnostics zip to verify only approved aggregate CSVs are present.
#'
#' @param outputFolder Path to the study execution output directory.
#' @param databaseId Short identifier for the database.
#'
#' @return The path to the created zip file.
#' @export
packageResults <- function(outputFolder,
                           databaseId) {

  zipFile <- file.path(outputFolder, sprintf("Results_%s.zip", databaseId))
  if (file.exists(zipFile)) {
    unlink(zipFile)
  }

  # Explicit allowlist of approved relative files for this specific databaseId
  approvedTopLevelFiles <- c(
    sprintf("cohort_counts_%s.csv", databaseId),
    sprintf("cohort_overlap_summary_%s.csv", databaseId),
    sprintf("phevaluator_summary_%s.csv", databaseId)
  )

  filesToZip <- c()

  # Check top-level aggregate CSVs
  for (f in approvedTopLevelFiles) {
    fullPath <- file.path(outputFolder, f)
    if (file.exists(fullPath)) {
      filesToZip <- c(filesToZip, fullPath)
    }
  }

  # Approved CohortDiagnostics export members (aggregate-only summaries)
  approvedCohortDiagnosticsMembers <- c(
    "cohort_count.csv",
    "cohort_overlap.csv",
    "concept_counts.csv",
    "incidence_rate.csv",
    "time_distribution.csv",
    "included_source_concept.csv",
    "orphan_concept.csv",
    "index_event_breakdown.csv",
    "covariate_value.csv",
    "covariate_value_dist.csv",
    "metadata.csv"
  )

  # Check and inspect CohortDiagnostics export zip if present
  diagZipRel <- file.path("diagnostics", sprintf("Results_%s.zip", databaseId))
  diagZipFull <- file.path(outputFolder, diagZipRel)

  if (file.exists(diagZipFull)) {
    # Deep-inspect zip contents to verify only approved aggregate CSVs
    zipContents <- tryCatch({
      utils::unzip(diagZipFull, list = TRUE)$Name
    }, error = function(e) {
      ParallelLogger::logWarn(sprintf("Failed to inspect %s: %s", diagZipFull, e$message))
      character(0)
    })

    # Validate archive members: must be approved aggregate tables and free of patient identifiers
    unapprovedMembers <- zipContents[
      !tolower(basename(zipContents)) %in% approvedCohortDiagnosticsMembers |
      grepl("log|scratch|person|patient|subject", zipContents, ignore.case = TRUE)
    ]

    if (length(unapprovedMembers) > 0) {
      ParallelLogger::logWarn(sprintf(
        "Diagnostics archive %s contains %d unapproved or non-aggregate members (e.g. %s). Excluding from export bundle per data governance policy.",
        diagZipFull, length(unapprovedMembers), unapprovedMembers[1]
      ))
    } else if (length(zipContents) > 0) {
      ParallelLogger::logInfo(sprintf("Verified %d approved aggregate CSV members in %s.", length(zipContents), diagZipFull))
      filesToZip <- c(filesToZip, diagZipFull)
    }
  }

  # Safety check: ensure every file in filesToZip is strictly in the approved relative allowlist
  normOutputFolder <- normalizePath(outputFolder, winslash = "/", mustWork = FALSE)
  relFilesToZip <- gsub(paste0("^", normOutputFolder, "/?"), "",
                        normalizePath(filesToZip, winslash = "/", mustWork = FALSE))

  allowedRelPaths <- c(
    approvedTopLevelFiles,
    file.path("diagnostics", sprintf("Results_%s.zip", databaseId))
  )

  disallowed <- relFilesToZip[!relFilesToZip %in% allowedRelPaths]
  if (length(disallowed) > 0) {
    stop(sprintf("Security violation: disallowed file detected in packaging queue: %s", disallowed[1]))
  }

  if (length(filesToZip) == 0) {
    ParallelLogger::logWarn(sprintf("No allowlisted files found in %s to package into %s.", outputFolder, zipFile))
  } else {
    ParallelLogger::logInfo(sprintf("Compressing %d allowlisted result files into %s...", length(filesToZip), zipFile))
    # Create zip preserving relative paths
    currentDir <- getwd()
    setwd(outputFolder)
    on.exit(setwd(currentDir), add = TRUE)

    relFilesToZip <- gsub(paste0("^", normalizePath(outputFolder, winslash = "/"), "/?"), "",
                          normalizePath(filesToZip, winslash = "/"))

    utils::zip(zipfile = basename(zipFile), files = relFilesToZip, flags = "-r9Xq")
    ParallelLogger::logInfo(sprintf("Successfully generated allowlisted export package: %s", zipFile))
  }

  return(zipFile)
}
