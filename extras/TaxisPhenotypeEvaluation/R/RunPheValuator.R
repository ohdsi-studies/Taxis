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

#' Create PheValuator Analysis Specifications for Phenotype Pairs
#'
#' @description
#' Creates a list of \code{pheValuatorAnalysis} objects from the study phenotype pairs configuration,
#' setting condition-appropriate feature extraction windows and excluding target condition concepts.
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
        xSpecCohortId = libraryId,
        prevalenceCohortId = libraryId,
        xSensCohortId = libraryId,
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
          xSpecCohortId = libraryId,
          prevalenceCohortId = libraryId,
          xSensCohortId = libraryId
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
#'
#' @param connectionDetails        DatabaseConnector connection details object.
#' @param cdmDatabaseSchema        Schema containing OMOP CDM v5.4 clinical data.
#' @param cohortDatabaseSchema     Schema where cohort tables reside.
#' @param cohortTable              Name of the cohort table.
#' @param workDatabaseSchema       Schema where intermediate tables are written. Defaults to cohortDatabaseSchema.
#' @param outputFolder             Local directory where evaluation outputs will be saved.
#' @param databaseId               Unique identifier for the participating database.
#' @param cdmVersion               Version of OMOP CDM (default is "5").
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
                           cdmVersion = "5") {

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
  executedSuccessfully <- FALSE

  if (requireNamespace("PheValuator", quietly = TRUE)) {
    tryCatch({
      referenceTable <- PheValuator::runPheValuatorAnalyses(
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

      summaryDf <- PheValuator::summarizePheValuatorAnalyses(
        referenceTable = referenceTable,
        outputFolder = phevalFolder
      )

      if (nrow(summaryDf) > 0) {
        for (i in seq_len(nrow(pairs))) {
          taxisId <- as.numeric(pairs$taxisCohortId[i])
          pairMatch <- summaryDf[summaryDf$cohortId == taxisId, ]
          if (nrow(pairMatch) > 0) {
            row <- pairMatch[1, ]
            resultsRows[[i]] <- data.frame(
              databaseId = databaseId,
              pairGroup = pairs$pairGroup[i],
              phenotypeName = pairs$phenotypeName[i],
              taxisCohortId = taxisId,
              libraryCohortId = as.numeric(pairs$libraryCohortId[i]),
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
              pairGroup = pairs$pairGroup[i],
              phenotypeName = pairs$phenotypeName[i],
              taxisCohortId = taxisId,
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
              status = "NO_EVALUATION_SUBJECTS",
              stringsAsFactors = FALSE
            )
          }
        }
        executedSuccessfully <- TRUE
      }
    }, error = function(e) {
      ParallelLogger::logWarn(sprintf("PheValuator pipeline run encountered an issue: %s", e$message))
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
          status = sprintf("FAILED: %s", e$message),
          stringsAsFactors = FALSE
        )
      }
    })
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
  }

  phevalSummary <- do.call(rbind, resultsRows)

  # Apply complementary cell suppression if counts are non-NA and 0 < N < 5 (DEC-GR-005)
  if (!is.null(phevalSummary$truePositives)) {
    maskIdx <- which(
      (!is.na(phevalSummary$truePositives) & phevalSummary$truePositives > 0 & phevalSummary$truePositives < 5) |
      (!is.na(phevalSummary$falsePositives) & phevalSummary$falsePositives > 0 & phevalSummary$falsePositives < 5) |
      (!is.na(phevalSummary$trueNegatives) & phevalSummary$trueNegatives > 0 & phevalSummary$trueNegatives < 5) |
      (!is.na(phevalSummary$falseNegatives) & phevalSummary$falseNegatives > 0 & phevalSummary$falseNegatives < 5)
    )
    if (length(maskIdx) > 0) {
      phevalSummary$truePositives[maskIdx] <- -1
      phevalSummary$falsePositives[maskIdx] <- -1
      phevalSummary$trueNegatives[maskIdx] <- -1
      phevalSummary$falseNegatives[maskIdx] <- -1
      phevalSummary$sensitivity[maskIdx] <- -1
      phevalSummary$ppv[maskIdx] <- -1
      phevalSummary$specificity[maskIdx] <- -1
      phevalSummary$npv[maskIdx] <- -1
      phevalSummary$f1Score[maskIdx] <- -1
    }
  }

  summaryPath <- file.path(outputFolder, sprintf("phevaluator_summary_%s.csv", databaseId))
  readr::write_csv(phevalSummary, summaryPath)
  ParallelLogger::logInfo(sprintf("PheValuator summary successfully saved to %s", summaryPath))

  return(phevalSummary)
}
