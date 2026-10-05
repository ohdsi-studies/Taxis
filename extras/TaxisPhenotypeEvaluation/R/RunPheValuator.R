# @file RunPheValuator.R
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

#' Apply Small-Cell Suppression to PheValuator Diagnostic Summary
#'
#' @description
#' Enforces strict non-disclosure protections (DEC-GR-005 / REC-048-1) on exported
#' PheValuator performance metrics. If any contingency cell (true positives, false positives,
#' true negatives, or false negatives) has a count that is between 1 and minCellCount - 1,
#' or if upstream PheValuator has masked counts (negative values), all contingency counts,
#' point estimates, 95% confidence intervals, F1 score, and estimated prevalence are masked to -1.
#'
#' @param phevalSummary   Data frame containing PheValuator results.
#' @param minCellCount    Minimum count threshold for cell suppression (default = 5).
#'
#' @return A data frame with small cells and algebraically dependent metrics masked to -1.
#' @export
applyPheValuatorSuppression <- function(phevalSummary, minCellCount = 5) {
  if (is.null(phevalSummary) || nrow(phevalSummary) == 0) {
    return(phevalSummary)
  }

  # Enforce mandatory privacy floor (DEC-GR-005 / REC-049-1 / REC-050-1)
  # Validate that minCellCount is a valid finite scalar integer >= 5 and <= .Machine$integer.max.
  # Sub-floor values (0, 1, 2, 3, 4), negatives, fractional, NA, NULL, non-numeric types,
  # or out-of-range integers (> .Machine$integer.max) are strictly normalized to the mandatory floor of 5.
  if (is.null(minCellCount) || length(minCellCount) != 1 || !is.numeric(minCellCount) ||
      is.na(minCellCount) || !is.finite(minCellCount) || minCellCount < 5 ||
      minCellCount > .Machine$integer.max || (minCellCount %% 1 != 0)) {
    minCellCount <- 5
  } else {
    minCellCount <- as.integer(minCellCount)
  }

  for (i in seq_len(nrow(phevalSummary))) {
    tp <- phevalSummary$truePositives[i]
    fp <- phevalSummary$falsePositives[i]
    tn <- phevalSummary$trueNegatives[i]
    fn <- phevalSummary$falseNegatives[i]

    # Evaluate whether any contingency cell triggers suppression:
    # 1. Any non-NA cell is strictly between 0 and minCellCount (e.g. 1, 2, 3, 4 when minCellCount = 5)
    # 2. Any non-NA cell is negative (upstream PheValuator suppression marker)
    isSmallCell <- function(x) {
      !is.na(x) && ((x > 0 && x < minCellCount) || x < 0)
    }

    triggerMask <- isSmallCell(tp) || isSmallCell(fp) || isSmallCell(tn) || isSmallCell(fn)

    if (triggerMask) {
      phevalSummary$truePositives[i] <- -1
      phevalSummary$falsePositives[i] <- -1
      phevalSummary$trueNegatives[i] <- -1
      phevalSummary$falseNegatives[i] <- -1
      phevalSummary$sensitivity[i] <- -1
      phevalSummary$sensitivityCi95Lb[i] <- -1
      phevalSummary$sensitivityCi95Ub[i] <- -1
      phevalSummary$ppv[i] <- -1
      phevalSummary$ppvCi95Lb[i] <- -1
      phevalSummary$ppvCi95Ub[i] <- -1
      phevalSummary$specificity[i] <- -1
      phevalSummary$specificityCi95Lb[i] <- -1
      phevalSummary$specificityCi95Ub[i] <- -1
      phevalSummary$npv[i] <- -1
      phevalSummary$npvCi95Lb[i] <- -1
      phevalSummary$npvCi95Ub[i] <- -1
      phevalSummary$f1Score[i] <- -1
      phevalSummary$estimatedPrevalence[i] <- -1
    }
  }

  return(phevalSummary)
}

#' Format Raw PheValuator Summary to Standardized Study Schema
#'
#' @description
#' Formats raw PheValuator evaluation outputs into the standardized study summary schema,
#' mapping phenotype pairs and establishing bounded status codes.
#'
#' @param summaryDf    Raw summary data frame from \code{PheValuator::summarizePheValuatorAnalyses}.
#' @param pairs        Data frame of phenotype pairs (from \code{PhenotypePairs.csv}).
#' @param databaseId   Unique identifier for the participating database.
#'
#' @return A formatted data frame matching the study output specification.
#' @export
formatPheValuatorResults <- function(summaryDf, pairs, databaseId) {
  resultsRows <- list()

  for (i in seq_len(nrow(pairs))) {
    taxisId <- as.numeric(pairs$taxisCohortId[i])
    libId <- as.numeric(pairs$libraryCohortId[i])
    group <- pairs$pairGroup[i]
    phenoName <- pairs$phenotypeName[i]

    pairMatch <- if (!is.null(summaryDf) && nrow(summaryDf) > 0 && "cohortId" %in% names(summaryDf)) {
      summaryDf[summaryDf$cohortId == taxisId, ]
    } else {
      data.frame()
    }

    if (nrow(pairMatch) > 0) {
      row <- pairMatch[1, ]
      resultsRows[[i]] <- data.frame(
        databaseId = databaseId,
        pairGroup = group,
        phenotypeName = phenoName,
        taxisCohortId = taxisId,
        libraryCohortId = libId,
        cutPoint = as.character(row$cutPoint),
        sensitivity = as.numeric(row$sensitivity),
        sensitivityCi95Lb = as.numeric(row$sensitivityCi95Lb),
        sensitivityCi95Ub = as.numeric(row$sensitivityCi95Ub),
        ppv = as.numeric(row$ppv),
        ppvCi95Lb = as.numeric(row$ppvCi95Lb),
        ppvCi95Ub = as.numeric(row$ppvCi95Ub),
        specificity = as.numeric(row$specificity),
        specificityCi95Lb = as.numeric(row$specificityCi95Lb),
        specificityCi95Ub = as.numeric(row$specificityCi95Ub),
        npv = as.numeric(row$npv),
        npvCi95Lb = as.numeric(row$npvCi95Lb),
        npvCi95Ub = as.numeric(row$npvCi95Ub),
        f1Score = as.numeric(row$f1Score),
        truePositives = as.numeric(row$truePositives),
        trueNegatives = as.numeric(row$trueNegatives),
        falsePositives = as.numeric(row$falsePositives),
        falseNegatives = as.numeric(row$falseNegatives),
        estimatedPrevalence = as.numeric(row$estimatedPrevalence),
        status = "COMPLETED",
        stringsAsFactors = FALSE
      )
    } else {
      resultsRows[[i]] <- data.frame(
        databaseId = databaseId,
        pairGroup = group,
        phenotypeName = phenoName,
        taxisCohortId = taxisId,
        libraryCohortId = libId,
        cutPoint = "Expected Value",
        sensitivity = NA_real_,
        sensitivityCi95Lb = NA_real_,
        sensitivityCi95Ub = NA_real_,
        ppv = NA_real_,
        ppvCi95Lb = NA_real_,
        ppvCi95Ub = NA_real_,
        specificity = NA_real_,
        specificityCi95Lb = NA_real_,
        specificityCi95Ub = NA_real_,
        npv = NA_real_,
        npvCi95Lb = NA_real_,
        npvCi95Ub = NA_real_,
        f1Score = NA_real_,
        truePositives = NA_real_,
        trueNegatives = NA_real_,
        falsePositives = NA_real_,
        falseNegatives = NA_real_,
        estimatedPrevalence = NA_real_,
        status = "NO_EVALUATION_SUBJECTS",
        stringsAsFactors = FALSE
      )
    }
  }

  do.call(rbind, resultsRows)
}

#' Create PheValuator Analysis Specifications for Phenotype Pairs
#'
#' @description
#' Creates a list of \code{pheValuatorAnalysis} objects from the study phenotype pairs configuration,
#' setting condition-appropriate feature extraction windows and excluding target condition concepts.
#' Supports explicit condition-specific role definitions (xSpec, xSens, prevalence) and logs
#' provisional placeholder warnings when reference library cohorts are temporarily reused.
#'
#' @param pairs Data frame of phenotype pairs (from \code{PhenotypePairs.csv}).
#'
#' @return A list of objects of class \code{pheValuatorAnalysis}.
#' @export
createPheValuatorAnalysisList <- function(pairs) {
  analysisList <- list()

  for (i in seq_len(nrow(pairs))) {
    group <- pairs$pairGroup[i]
    phenoName <- pairs$phenotypeName[i]
    taxisId <- as.numeric(pairs$taxisCohortId[i])
    libraryId <- as.numeric(pairs$libraryCohortId[i])
    condConceptId <- as.numeric(pairs$conditionConceptId[i])

    # Methodological Configuration (REC-048-3):
    # Retrieve explicit condition-specific cohort IDs for xSpec, xSens, and prevalence
    xSpecId <- if ("xSpecCohortId" %in% names(pairs) && !is.na(pairs$xSpecCohortId[i])) {
      as.numeric(pairs$xSpecCohortId[i])
    } else {
      libraryId
    }

    xSensId <- if ("xSensCohortId" %in% names(pairs) && !is.na(pairs$xSensCohortId[i])) {
      as.numeric(pairs$xSensCohortId[i])
    } else {
      libraryId
    }

    prevId <- if ("prevalenceCohortId" %in% names(pairs) && !is.na(pairs$prevalenceCohortId[i])) {
      as.numeric(pairs$prevalenceCohortId[i])
    } else {
      libraryId
    }

    # If the cohort roles use the reference library cohort as a placeholder, log an explicit warning
    if (xSpecId == libraryId && xSensId == libraryId) {
      ParallelLogger::logWarn(sprintf(
        "Provisional cohort role assignment for %s: xSpecCohortId=%d, xSensCohortId=%d, prevalenceCohortId=%d. Using reference library cohort as provisional placeholder pending dedicated clinician-adjudicated xSpec and xSens cohort definitions per Swerdel et al. (2019).",
        phenoName, xSpecId, xSensId, prevId
      ))
    }

    isAcute <- tolower(group) %in% c("hyperkalemia", "mi", "stroke", "acute")

    if (requireNamespace("PheValuator", quietly = TRUE)) {
      if (isAcute) {
        covSettings <- PheValuator::createDefaultCovariateSettings(
          excludedCovariateConceptIds = c(condConceptId),
          addDescendantsToExclude = TRUE,
          startDayWindow1 = 0,
          endDayWindow1 = 10,
          startDayWindow2 = 11,
          endDayWindow2 = 20,
          startDayWindow3 = 21,
          endDayWindow3 = 30
        )
      } else {
        covSettings <- PheValuator::createDefaultCovariateSettings(
          excludedCovariateConceptIds = c(condConceptId),
          addDescendantsToExclude = TRUE,
          startDayWindow1 = 0,
          endDayWindow1 = 30,
          startDayWindow2 = 31,
          endDayWindow2 = 180,
          startDayWindow3 = 181,
          endDayWindow3 = 365
        )
      }

      evalCohortArgs <- PheValuator::createCreateEvaluationCohortArgs(
        xSpecCohortId = xSpecId,
        prevalenceCohortId = prevId,
        xSensCohortId = xSensId,
        covariateSettings = covSettings,
        modelBaseSampleSize = 25000,
        baseSampleSize = 2000000
      )

      testArgs <- PheValuator::createTestPhenotypeAlgorithmArgs(
        phenotypeCohortId = taxisId,
        cutPoints = c("EV"),
        washoutPeriod = 0,
        splayPrior = 7,
        splayPost = 7
      )

      analysis <- PheValuator::createPheValuatorAnalysis(
        analysisId = i,
        description = sprintf(
          "PheValuator Evaluation of TAXIS %s (Cohort %d) vs Reference Library %d",
          phenoName,
          taxisId,
          libraryId
        ),
        createEvaluationCohortArgs = evalCohortArgs,
        testPhenotypeAlgorithmArgs = testArgs
      )
    } else {
      # Fallback mock analysis structure for static verification without installed package
      analysis <- list(
        analysisId = i,
        description = sprintf(
          "PheValuator Evaluation of TAXIS %s (Cohort %d) vs Reference Library %d",
          phenoName,
          taxisId,
          libraryId
        ),
        createEvaluationCohortArgs = list(
          xSpecCohortId = xSpecId,
          prevalenceCohortId = prevId,
          xSensCohortId = xSensId
        ),
        testPhenotypeAlgorithmArgs = list(
          phenotypeCohortId = taxisId,
          cutPoints = c("EV"),
          washoutPeriod = 0
        )
      )
      class(analysis) <- "pheValuatorAnalysis"
    }

    analysisList[[i]] <- analysis
  }

  return(analysisList)
}

#' Run PheValuator Evaluation on Phenotype Pairs
#'
#' @description
#' Evaluates diagnostic performance characteristics (Sensitivity, Specificity, PPV, NPV, F1 Score)
#' of TAXIS-generated phenotypes using the OHDSI \code{PheValuator} package.
#' Adheres to strict small-cell suppression (REC-048-1) and non-disclosure error hygiene (REC-048-2).
#'
#' @param connectionDetails        DatabaseConnector connection details object.
#' @param cdmDatabaseSchema        Schema containing OMOP CDM v5.4 clinical data.
#' @param cohortDatabaseSchema     Schema where cohort tables reside.
#' @param cohortTable              Name of the cohort table.
#' @param workDatabaseSchema       Schema where intermediate tables are written. Defaults to cohortDatabaseSchema.
#' @param outputFolder             Local directory where evaluation outputs will be saved.
#' @param databaseId               Unique identifier for the participating database.
#' @param cdmVersion               Version of OMOP CDM (default is "5").
#' @param minCellCount             Minimum cell count threshold for small-cell suppression (default is 5).
#' @param runAnalysesFn            Optional runner function for PheValuator analyses (used for testing and stub injection).
#' @param summarizeAnalysesFn      Optional summarizer function for PheValuator analyses (used for testing and stub injection).
#'
#' @return A data frame containing the summary of PheValuator diagnostic performance metrics.
#' @export
runPheValuator <- function(connectionDetails,
                           cdmDatabaseSchema,
                           cohortDatabaseSchema,
                           cohortTable,
                           workDatabaseSchema = cohortDatabaseSchema,
                           outputFolder,
                           databaseId,
                           cdmVersion = "5",
                           minCellCount = 5,
                           runAnalysesFn = NULL,
                           summarizeAnalysesFn = NULL) {

  # Enforce mandatory privacy floor on minCellCount (DEC-GR-005 / REC-049-1 / REC-050-1)
  if (is.null(minCellCount) || length(minCellCount) != 1 || !is.numeric(minCellCount) ||
      is.na(minCellCount) || !is.finite(minCellCount) || minCellCount < 5 ||
      minCellCount > .Machine$integer.max || (minCellCount %% 1 != 0)) {
    minCellCount <- 5
  } else {
    minCellCount <- as.integer(minCellCount)
  }

  phevalFolder <- file.path(outputFolder, "phevaluator")
  if (!file.exists(phevalFolder)) {
    dir.create(phevalFolder, recursive = TRUE)
  }

  pathToPairs <- system.file("settings", "PhenotypePairs.csv", package = "TaxisPhenotypeEvaluation")
  if (!file.exists(pathToPairs)) {
    stop("PhenotypePairs.csv configuration file not found in package settings.")
  }
  pairs <- readr::read_csv(pathToPairs, col_types = readr::cols())

  # Step 1: Create formal PheValuator analysis specifications
  ParallelLogger::logInfo("Generating PheValuator analysis specifications for phenotype pairs...")
  pheValuatorAnalysisList <- createPheValuatorAnalysisList(pairs)

  # Step 2: Save analysis list to JSON per standard HADES study protocol
  jsonPath <- file.path(phevalFolder, "pheValuatorAnalysisList.json")
  if (requireNamespace("PheValuator", quietly = TRUE)) {
    PheValuator::savePheValuatorAnalysisList(pheValuatorAnalysisList, jsonPath)
  } else {
    ParallelLogger::saveSettingsToJson(pheValuatorAnalysisList, jsonPath)
  }
  ParallelLogger::logInfo(sprintf("Saved PheValuator analysis specifications to %s", jsonPath))

  resultsRows <- list()

  # Step 3: Execute PheValuator pipeline
  ParallelLogger::logInfo("Beginning PheValuator pipeline execution across phenotype pairs...")

  hasPheValuator <- requireNamespace("PheValuator", quietly = TRUE) || !is.null(runAnalysesFn)

  if (hasPheValuator) {
    summaryDf <- tryCatch({
      runner <- if (!is.null(runAnalysesFn)) runAnalysesFn else PheValuator::runPheValuatorAnalyses

      referenceTable <- runner(
        phenotype = "TAXIS_5_Phenotypes",
        analysisName = "TAXIS_Phenotype_Evaluation",
        connectionDetails = connectionDetails,
        cdmDatabaseSchema = cdmDatabaseSchema,
        cohortDatabaseSchema = cohortDatabaseSchema,
        cohortTable = cohortTable,
        workDatabaseSchema = workDatabaseSchema,
        databaseId = databaseId,
        cdmVersion = cdmVersion,
        outputFolder = phevalFolder,
        pheValuatorAnalysisList = pheValuatorAnalysisList
      )

      # Resolve summarizer lazily after runner succeeds (REC-050-2)
      summarizer <- if (!is.null(summarizeAnalysesFn)) summarizeAnalysesFn else PheValuator::summarizePheValuatorAnalyses
      summarizer(
        referenceTable = referenceTable,
        outputFolder = phevalFolder
      )
    }, error = function(e) {
      # Log full diagnostic details exclusively to private site-local log (REC-048-2)
      ParallelLogger::logError(sprintf("PheValuator execution failed for database %s: %s", databaseId, e$message))
      NULL
    })

    if (!is.null(summaryDf) && nrow(summaryDf) > 0) {
      phevalSummary <- formatPheValuatorResults(summaryDf, pairs, databaseId)
    } else {
      # Build execution failure fallback with strictly bounded status code (zero raw error text)
      for (i in seq_len(nrow(pairs))) {
        resultsRows[[i]] <- data.frame(
          databaseId = databaseId,
          pairGroup = pairs$pairGroup[i],
          phenotypeName = pairs$phenotypeName[i],
          taxisCohortId = as.numeric(pairs$taxisCohortId[i]),
          libraryCohortId = as.numeric(pairs$libraryCohortId[i]),
          cutPoint = "Expected Value",
          sensitivity = NA_real_,
          sensitivityCi95Lb = NA_real_,
          sensitivityCi95Ub = NA_real_,
          ppv = NA_real_,
          ppvCi95Lb = NA_real_,
          ppvCi95Ub = NA_real_,
          specificity = NA_real_,
          specificityCi95Lb = NA_real_,
          specificityCi95Ub = NA_real_,
          npv = NA_real_,
          npvCi95Lb = NA_real_,
          npvCi95Ub = NA_real_,
          f1Score = NA_real_,
          truePositives = NA_real_,
          trueNegatives = NA_real_,
          falsePositives = NA_real_,
          falseNegatives = NA_real_,
          estimatedPrevalence = NA_real_,
          status = "EXECUTION_FAILED",
          stringsAsFactors = FALSE
        )
      }
      phevalSummary <- do.call(rbind, resultsRows)
    }
  } else {
    ParallelLogger::logWarn("PheValuator package not installed; generating unexecuted placeholder summary.")
    for (i in seq_len(nrow(pairs))) {
      resultsRows[[i]] <- data.frame(
        databaseId = databaseId,
        pairGroup = pairs$pairGroup[i],
        phenotypeName = pairs$phenotypeName[i],
        taxisCohortId = as.numeric(pairs$taxisCohortId[i]),
        libraryCohortId = as.numeric(pairs$libraryCohortId[i]),
        cutPoint = "Expected Value",
        sensitivity = NA_real_,
        sensitivityCi95Lb = NA_real_,
        sensitivityCi95Ub = NA_real_,
        ppv = NA_real_,
        ppvCi95Lb = NA_real_,
        ppvCi95Ub = NA_real_,
        specificity = NA_real_,
        specificityCi95Lb = NA_real_,
        specificityCi95Ub = NA_real_,
        npv = NA_real_,
        npvCi95Lb = NA_real_,
        npvCi95Ub = NA_real_,
        f1Score = NA_real_,
        truePositives = NA_real_,
        trueNegatives = NA_real_,
        falsePositives = NA_real_,
        falseNegatives = NA_real_,
        estimatedPrevalence = NA_real_,
        status = "PACKAGE_NOT_INSTALLED",
        stringsAsFactors = FALSE
      )
    }
    phevalSummary <- do.call(rbind, resultsRows)
  }

  # Step 4: Apply strict complementary cell suppression (REC-048-1 / DEC-GR-005)
  phevalSummary <- applyPheValuatorSuppression(phevalSummary, minCellCount = minCellCount)

  summaryPath <- file.path(outputFolder, sprintf("phevaluator_summary_%s.csv", databaseId))
  readr::write_csv(phevalSummary, summaryPath)
  ParallelLogger::logInfo(sprintf("PheValuator summary successfully saved to %s", summaryPath))

  return(phevalSummary)
}
