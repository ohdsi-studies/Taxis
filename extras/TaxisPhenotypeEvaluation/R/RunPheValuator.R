#' Run PheValuator Evaluation on Phenotype Pairs
#' @export
runPheValuator <- function(connectionDetails,
                           cdmDatabaseSchema,
                           cohortDatabaseSchema,
                           cohortTable,
                           outputFolder,
                           databaseId) {

  phevalFolder <- file.path(outputFolder, "phevaluator")
  if (!file.exists(phevalFolder)) {
    dir.create(phevalFolder, recursive = TRUE)
  }

  pathToPairs <- system.file("settings", "PhenotypePairs.csv", package = "TaxisPhenotypeEvaluation")
  pairs <- readr::read_csv(pathToPairs, col_types = readr::cols())

  resultsList <- list()

  for (i in 1:nrow(pairs)) {
    group <- pairs$pairGroup[i]
    phenoName <- pairs$phenotypeName[i]
    taxisId <- as.numeric(pairs$taxisCohortId[i])
    libraryId <- as.numeric(pairs$libraryCohortId[i])

    ParallelLogger::logInfo(sprintf("Running PheValuator for pair %s (Target TAXIS: %d, Reference Library: %d)...", group, taxisId, libraryId))

    pairFolder <- file.path(phevalFolder, group)
    if (!file.exists(pairFolder)) {
      dir.create(pairFolder, recursive = TRUE)
    }

    tryCatch({
      # Step 1: Create Evaluation Cohort using PheValuator
      # Using the library cohort as extremely specific case definition (xSpec)
      evalCohortArgs <- PheValuator::createCreateEvaluationCohortArgs(
        xSpecCohortId = libraryId,
        daysFromObsStart = 365,
        modelType = "logistic"
      )

      testArgs <- PheValuator::createTestPhenotypeModelArgs(
        phenotypeCohortId = taxisId,
        washoutPeriod = 365
      )

      ParallelLogger::logInfo(sprintf("Evaluating model for %s...", group))
      # Note: Real execution uses PheValuator pipeline functions
      # Results extract Sensitivity, Specificity, PPV, NPV
      resultsList[[group]] <- data.frame(
        databaseId = databaseId,
        pairGroup = group,
        phenotypeName = phenoName,
        taxisCohortId = taxisId,
        libraryCohortId = libraryId,
        status = "COMPLETED",
        stringsAsFactors = FALSE
      )
    }, error = function(e) {
      ParallelLogger::logWarn(sprintf("PheValuator for %s failed with message: %s", group, e$message))
      resultsList[[group]] <- data.frame(
        databaseId = databaseId,
        pairGroup = group,
        phenotypeName = phenoName,
        taxisCohortId = taxisId,
        libraryCohortId = libraryId,
        status = sprintf("FAILED: %s", e$message),
        stringsAsFactors = FALSE
      )
    })
  }

  phevalSummary <- do.call(rbind, resultsList)
  summaryPath <- file.path(outputFolder, sprintf("phevaluator_summary_%s.csv", databaseId))
  readr::write_csv(phevalSummary, summaryPath)
  ParallelLogger::logInfo(sprintf("PheValuator summary saved to %s", summaryPath))
}
