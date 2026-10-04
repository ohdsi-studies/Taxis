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

test_that("TaxisPhenotypeEvaluation package exports required functions", {
  expect_true(exists("execute"))
  expect_true(exists("createCohorts"))
  expect_true(exists("computeCohortOverlap"))
  expect_true(exists("applyCohortOverlapSuppression"))
  expect_true(exists("runDiagnostics"))
  expect_true(exists("runPheValuator"))
  expect_true(exists("createPheValuatorAnalysisList"))
  expect_true(exists("packageResults"))
})

test_that("applyCohortOverlapSuppression preserves unsuppressed counts when all >= minCellCount", {
  df <- data.frame(
    databaseId = "TEST_DB",
    pairGroup = "COPD",
    phenotypeName = "COPD",
    taxisCohortId = 1798322,
    libraryCohortId = 1263,
    taxisCount = 100,
    libraryCount = 100,
    intersectionCount = 80,
    unionCount = 120,
    taxisOnlyCount = 20,
    libraryOnlyCount = 20,
    jaccardIndex = 80 / 120,
    taxisSensitivityVsLibrary = 80 / 100,
    taxisAgreementVsLibrary = 80 / 100,
    stringsAsFactors = FALSE
  )

  suppressed <- applyCohortOverlapSuppression(df, minCellCount = 5)

  expect_equal(suppressed$taxisCount, 100)
  expect_equal(suppressed$libraryCount, 100)
  expect_equal(suppressed$intersectionCount, 80)
  expect_equal(suppressed$unionCount, 120)
  expect_equal(suppressed$taxisOnlyCount, 20)
  expect_equal(suppressed$libraryOnlyCount, 20)
  expect_equal(suppressed$jaccardIndex, 80 / 120)
})

test_that("applyCohortOverlapSuppression applies complementary suppression when intersection < 5 (REC-024-1)", {
  df <- data.frame(
    databaseId = "TEST_DB",
    pairGroup = "T2DM",
    phenotypeName = "T2DM",
    taxisCohortId = 1798326,
    libraryCohortId = 1032,
    taxisCount = 100,
    libraryCount = 100,
    intersectionCount = 3,
    unionCount = 197,
    taxisOnlyCount = 97,
    libraryOnlyCount = 97,
    jaccardIndex = 3 / 197,
    taxisSensitivityVsLibrary = 3 / 100,
    taxisAgreementVsLibrary = 3 / 100,
    stringsAsFactors = FALSE
  )

  suppressed <- applyCohortOverlapSuppression(df, minCellCount = 5)

  # Marginals >= 5 preserved
  expect_equal(suppressed$taxisCount, 100)
  expect_equal(suppressed$libraryCount, 100)

  # All 4 interior partition counts masked to -1
  expect_equal(suppressed$intersectionCount, -1)
  expect_equal(suppressed$unionCount, -1)
  expect_equal(suppressed$taxisOnlyCount, -1)
  expect_equal(suppressed$libraryOnlyCount, -1)

  # All derived ratios masked to -1 to block algebraic reconstruction
  expect_equal(suppressed$jaccardIndex, -1)
  expect_equal(suppressed$taxisSensitivityVsLibrary, -1)
  expect_equal(suppressed$taxisAgreementVsLibrary, -1)
})

test_that("createPheValuatorAnalysisList creates valid analysis objects for all phenotype pairs", {
  pairs <- data.frame(
    pairGroup = c("Hyperkalemia", "T2DM"),
    phenotypeName = c("Hyperkalemia", "Type 2 diabetes mellitus"),
    conditionConceptId = c(434610, 201826),
    taxisCohortId = c(1798325, 1798326),
    taxisCohortName = c("Taxis Hyperkalemia", "Taxis T2DM"),
    libraryCohortId = c(940, 1032),
    libraryCohortName = c("OHDSI 940", "OHDSI 1032"),
    stringsAsFactors = FALSE
  )

  analyses <- createPheValuatorAnalysisList(pairs)
  expect_equal(length(analyses), 2)
  expect_equal(analyses[[1]]$analysisId, 1)
  expect_equal(analyses[[2]]$analysisId, 2)
  expect_equal(analyses[[1]]$createEvaluationCohortArgs$xSpecCohortId, 940)
  expect_equal(analyses[[2]]$createEvaluationCohortArgs$xSpecCohortId, 1032)
  expect_equal(analyses[[1]]$testPhenotypeAlgorithmArgs$phenotypeCohortId, 1798325)
  expect_equal(analyses[[2]]$testPhenotypeAlgorithmArgs$phenotypeCohortId, 1798326)
})

test_that("runPheValuator outputs standardized summary schema with PheValuator performance metrics", {
  tempDir <- tempfile("pheval_test_")
  dir.create(tempDir, recursive = TRUE)
  on.exit(unlink(tempDir, recursive = TRUE), add = TRUE)

  summaryDf <- runPheValuator(
    connectionDetails = list(),
    cdmDatabaseSchema = "cdm",
    cohortDatabaseSchema = "cohort",
    cohortTable = "cohort",
    workDatabaseSchema = "cohort",
    outputFolder = tempDir,
    databaseId = "UNIT_TEST_DB"
  )

  expect_true(is.data.frame(summaryDf))
  expect_true(nrow(summaryDf) >= 5)

  expectedCols <- c(
    "databaseId", "pairGroup", "phenotypeName", "taxisCohortId", "libraryCohortId",
    "cutPoint", "sensitivity", "sensitivityCi95Lb", "sensitivityCi95Ub",
    "ppv", "ppvCi95Lb", "ppvCi95Ub", "specificity", "specificityCi95Lb", "specificityCi95Ub",
    "npv", "npvCi95Lb", "npvCi95Ub", "f1Score", "truePositives", "trueNegatives",
    "falsePositives", "falseNegatives", "estimatedPrevalence", "status"
  )

  for (col in expectedCols) {
    expect_true(col %in% colnames(summaryDf), info = sprintf("Missing expected column: %s", col))
  }

  summaryFile <- file.path(tempDir, "phevaluator_summary_UNIT_TEST_DB.csv")
  expect_true(file.exists(summaryFile))
  persistedDf <- readr::read_csv(summaryFile, col_types = readr::cols())
  expect_equal(nrow(persistedDf), nrow(summaryDf))
})

test_that("applyPheValuatorSuppression comprehensively masks all counts, estimates, and 8 bounds (REC-048-1)", {
  # Case 1: Small-cell count (truePositives = 3, strictly < 5 and > 0)
  smallCellRow <- data.frame(
    databaseId = "TEST_DB",
    pairGroup = "T2DM",
    phenotypeName = "Type 2 diabetes mellitus",
    taxisCohortId = 1798326,
    libraryCohortId = 1032,
    cutPoint = "EV",
    sensitivity = 0.88,
    sensitivityCi95Lb = 0.82,
    sensitivityCi95Ub = 0.94,
    ppv = 0.91,
    ppvCi95Lb = 0.85,
    ppvCi95Ub = 0.96,
    specificity = 0.98,
    specificityCi95Lb = 0.96,
    specificityCi95Ub = 0.99,
    npv = 0.95,
    npvCi95Lb = 0.92,
    npvCi95Ub = 0.97,
    f1Score = 0.89,
    truePositives = 3, # Triggers suppression
    trueNegatives = 500,
    falsePositives = 10,
    falseNegatives = 12,
    estimatedPrevalence = 0.05,
    status = "COMPLETED",
    stringsAsFactors = FALSE
  )

  suppressed <- applyPheValuatorSuppression(smallCellRow, minCellCount = 5)
  expect_equal(suppressed$truePositives, -1)
  expect_equal(suppressed$falsePositives, -1)
  expect_equal(suppressed$trueNegatives, -1)
  expect_equal(suppressed$falseNegatives, -1)
  expect_equal(suppressed$sensitivity, -1)
  expect_equal(suppressed$sensitivityCi95Lb, -1)
  expect_equal(suppressed$sensitivityCi95Ub, -1)
  expect_equal(suppressed$ppv, -1)
  expect_equal(suppressed$ppvCi95Lb, -1)
  expect_equal(suppressed$ppvCi95Ub, -1)
  expect_equal(suppressed$specificity, -1)
  expect_equal(suppressed$specificityCi95Lb, -1)
  expect_equal(suppressed$specificityCi95Ub, -1)
  expect_equal(suppressed$npv, -1)
  expect_equal(suppressed$npvCi95Lb, -1)
  expect_equal(suppressed$npvCi95Ub, -1)
  expect_equal(suppressed$f1Score, -1)
  expect_equal(suppressed$estimatedPrevalence, -1)

  # Case 2: Upstream negative count trigger (negative count indicating upstream suppression)
  upstreamSuppressedRow <- smallCellRow
  upstreamSuppressedRow$truePositives <- -1
  suppressed2 <- applyPheValuatorSuppression(upstreamSuppressedRow, minCellCount = 5)
  expect_equal(suppressed2$sensitivityCi95Lb, -1)
  expect_equal(suppressed2$ppvCi95Ub, -1)
  expect_equal(suppressed2$estimatedPrevalence, -1)

  # Case 3: Unsuppressed control (all contingency counts >= 5)
  unsuppressedRow <- smallCellRow
  unsuppressedRow$truePositives <- 150
  unsuppressedRow$falsePositives <- 20
  unsuppressedRow$trueNegatives <- 800
  unsuppressedRow$falseNegatives <- 25
  clean <- applyPheValuatorSuppression(unsuppressedRow, minCellCount = 5)
  expect_equal(clean$truePositives, 150)
  expect_equal(clean$sensitivity, 0.88)
  expect_equal(clean$sensitivityCi95Lb, 0.82)
  expect_equal(clean$sensitivityCi95Ub, 0.94)
  expect_equal(clean$f1Score, 0.89)
  expect_equal(clean$estimatedPrevalence, 0.05)

  # Case 4: Missing/NA counts (preserves NAs safely without false trigger)
  naRow <- smallCellRow
  naRow$truePositives <- NA_real_
  naRow$falsePositives <- NA_real_
  naRow$trueNegatives <- NA_real_
  naRow$falseNegatives <- NA_real_
  naResult <- applyPheValuatorSuppression(naRow, minCellCount = 5)
  expect_true(is.na(naResult$truePositives))
  expect_equal(naResult$sensitivity, 0.88)
})

test_that("formatPheValuatorResults correctly maps upstream provider outputs to study schema", {
  pairs <- data.frame(
    pairGroup = c("T2DM"),
    phenotypeName = c("Type 2 diabetes mellitus"),
    conditionConceptId = c(201826),
    taxisCohortId = c(1798326),
    taxisCohortName = c("Taxis T2DM"),
    libraryCohortId = c(1032),
    libraryCohortName = c("OHDSI 1032"),
    stringsAsFactors = FALSE
  )

  upstreamSummaryDf <- data.frame(
    cohortId = 1798326,
    cutPoint = "EV",
    sensitivity = 0.895,
    sensitivityCi95Lb = 0.850,
    sensitivityCi95Ub = 0.935,
    ppv = 0.920,
    ppvCi95Lb = 0.880,
    ppvCi95Ub = 0.955,
    specificity = 0.985,
    specificityCi95Lb = 0.975,
    specificityCi95Ub = 0.992,
    npv = 0.960,
    npvCi95Lb = 0.940,
    npvCi95Ub = 0.975,
    f1Score = 0.907,
    truePositives = 200,
    trueNegatives = 1000,
    falsePositives = 25,
    falseNegatives = 30,
    estimatedPrevalence = 0.085,
    stringsAsFactors = FALSE
  )

  formatted <- formatPheValuatorResults(upstreamSummaryDf, pairs, "PROVIDER_TEST_DB")
  expect_equal(nrow(formatted), 1)
  expect_equal(formatted$status, "COMPLETED")
  expect_equal(formatted$taxisCohortId, 1798326)
  expect_equal(formatted$sensitivity, 0.895)
  expect_equal(formatted$ppv, 0.920)
  expect_equal(formatted$f1Score, 0.907)
  expect_equal(formatted$truePositives, 200)
})

test_that("applyPheValuatorSuppression strictly enforces mandatory privacy floor >= 5 (REC-049-1)", {
  smallCellRow <- data.frame(
    databaseId = "TEST_DB",
    pairGroup = "T2DM",
    phenotypeName = "Type 2 diabetes mellitus",
    taxisCohortId = 1798326,
    libraryCohortId = 1032,
    cutPoint = "EV",
    sensitivity = 0.88,
    sensitivityCi95Lb = 0.82,
    sensitivityCi95Ub = 0.94,
    ppv = 0.91,
    ppvCi95Lb = 0.85,
    ppvCi95Ub = 0.96,
    specificity = 0.98,
    specificityCi95Lb = 0.96,
    specificityCi95Ub = 0.99,
    npv = 0.95,
    npvCi95Lb = 0.92,
    npvCi95Ub = 0.97,
    f1Score = 0.89,
    truePositives = 3, # strictly < 5
    trueNegatives = 500,
    falsePositives = 10,
    falseNegatives = 12,
    estimatedPrevalence = 0.05,
    status = "COMPLETED",
    stringsAsFactors = FALSE
  )

  # Sub-floor and invalid values must all normalize to floor 5
  subFloorValues <- list(0, 1, 2, 3, 4, -10, NULL, "invalid", c(5, 10), NaN, Inf, 5.7)
  for (val in subFloorValues) {
    res <- applyPheValuatorSuppression(smallCellRow, minCellCount = val)
    expect_equal(res$truePositives, -1, info = sprintf("Failed floor enforcement for minCellCount = %s", as.character(val)))
    expect_equal(res$sensitivityCi95Lb, -1)
    expect_equal(res$estimatedPrevalence, -1)
  }

  # 4-versus-5 boundary test
  boundary4 <- smallCellRow
  boundary4$truePositives <- 4
  res4 <- applyPheValuatorSuppression(boundary4, minCellCount = 5)
  expect_equal(res4$truePositives, -1)
  expect_equal(res4$sensitivity, -1)

  boundary5 <- smallCellRow
  boundary5$truePositives <- 5
  res5 <- applyPheValuatorSuppression(boundary5, minCellCount = 5)
  expect_equal(res5$truePositives, 5)
  expect_equal(res5$sensitivity, 0.88)
  expect_equal(res5$sensitivityCi95Lb, 0.82)
})

test_that("runPheValuator production wrapper catches injected runtime errors and prevents secret leakage (REC-049-2)", {
  tempDir <- tempfile("pheval_err_test_")
  dir.create(tempDir, recursive = TRUE)
  on.exit(unlink(tempDir, recursive = TRUE), add = TRUE)

  sentinelSecret <- "SUPER_CONFIDENTIAL_DB_PASSWORD_12345"

  # Invoke real production wrapper with injected runner error containing sentinel secret
  errorRunnerStub <- function(...) {
    stop(sprintf("CRITICAL DATABASE AUTH FAILURE: user=admin secret=%s connection refused", sentinelSecret))
  }

  summaryDf <- runPheValuator(
    connectionDetails = list(),
    cdmDatabaseSchema = "cdm",
    cohortDatabaseSchema = "cohort",
    cohortTable = "cohort",
    workDatabaseSchema = "cohort",
    outputFolder = tempDir,
    databaseId = "ERR_DB",
    runAnalysesFn = errorRunnerStub
  )

  expect_true(is.data.frame(summaryDf))
  expect_true(all(summaryDf$status == "EXECUTION_FAILED"))

  # Check that wrapper-written CSV on disk has bounded status and zero sentinel secret
  csvPath <- file.path(tempDir, "phevaluator_summary_ERR_DB.csv")
  expect_true(file.exists(csvPath))
  rawCsvContent <- readr::read_file(csvPath)
  expect_false(grepl(sentinelSecret, rawCsvContent, fixed = TRUE))
  expect_true(grepl("EXECUTION_FAILED", rawCsvContent, fixed = TRUE))

  # Test packageResults integration: ensure error summary is bundled into ZIP without leaking secrets
  zipFile <- packageResults(outputFolder = tempDir, databaseId = "ERR_DB")
  expect_true(file.exists(zipFile))

  unzipDir <- file.path(tempDir, "unzipped")
  utils::unzip(zipFile, exdir = unzipDir)
  bundledCsv <- file.path(unzipDir, "phevaluator_summary_ERR_DB.csv")
  expect_true(file.exists(bundledCsv))
  bundledContent <- readr::read_file(bundledCsv)
  expect_false(grepl(sentinelSecret, bundledContent, fixed = TRUE))
})

test_that("runPheValuator production wrapper executes provider stub, normalizes floor, and masks small cells (REC-049-2)", {
  tempDir <- tempfile("pheval_stub_test_")
  dir.create(tempDir, recursive = TRUE)
  on.exit(unlink(tempDir, recursive = TRUE), add = TRUE)

  # Upstream provider result containing small cell (truePositives = 3)
  mockUpstreamSummary <- data.frame(
    cohortId = 1798326,
    cutPoint = "EV",
    sensitivity = 0.895,
    sensitivityCi95Lb = 0.850,
    sensitivityCi95Ub = 0.935,
    ppv = 0.920,
    ppvCi95Lb = 0.880,
    ppvCi95Ub = 0.955,
    specificity = 0.985,
    specificityCi95Lb = 0.975,
    specificityCi95Ub = 0.992,
    npv = 0.960,
    npvCi95Lb = 0.940,
    npvCi95Ub = 0.975,
    f1Score = 0.907,
    truePositives = 3, # Small cell!
    trueNegatives = 1000,
    falsePositives = 25,
    falseNegatives = 30,
    estimatedPrevalence = 0.085,
    stringsAsFactors = FALSE
  )

  successfulRunnerStub <- function(...) {
    list(analysisId = 1)
  }

  summarizerStub <- function(...) {
    mockUpstreamSummary
  }

  # Execute production wrapper passing minCellCount = 1 to test floor bypass prevention
  wrapperSummary <- runPheValuator(
    connectionDetails = list(),
    cdmDatabaseSchema = "cdm",
    cohortDatabaseSchema = "cohort",
    cohortTable = "cohort",
    workDatabaseSchema = "cohort",
    outputFolder = tempDir,
    databaseId = "STUB_DB",
    minCellCount = 1, # Attempted bypass -> must normalize to 5!
    runAnalysesFn = successfulRunnerStub,
    summarizeAnalysesFn = summarizerStub
  )

  expect_true(is.data.frame(wrapperSummary))

  # Target T2DM row (taxisCohortId = 1798326)
  t2dmRow <- wrapperSummary[wrapperSummary$taxisCohortId == 1798326, ]
  expect_equal(nrow(t2dmRow), 1)
  expect_equal(t2dmRow$status, "COMPLETED")

  # Assert that wrapper suppression was applied: all cells, estimates, and 8 bounds masked to -1
  expect_equal(t2dmRow$truePositives, -1)
  expect_equal(t2dmRow$falsePositives, -1)
  expect_equal(t2dmRow$trueNegatives, -1)
  expect_equal(t2dmRow$falseNegatives, -1)
  expect_equal(t2dmRow$sensitivity, -1)
  expect_equal(t2dmRow$sensitivityCi95Lb, -1)
  expect_equal(t2dmRow$sensitivityCi95Ub, -1)
  expect_equal(t2dmRow$ppv, -1)
  expect_equal(t2dmRow$ppvCi95Lb, -1)
  expect_equal(t2dmRow$ppvCi95Ub, -1)
  expect_equal(t2dmRow$specificity, -1)
  expect_equal(t2dmRow$specificityCi95Lb, -1)
  expect_equal(t2dmRow$specificityCi95Ub, -1)
  expect_equal(t2dmRow$npv, -1)
  expect_equal(t2dmRow$npvCi95Lb, -1)
  expect_equal(t2dmRow$npvCi95Ub, -1)
  expect_equal(t2dmRow$f1Score, -1)
  expect_equal(t2dmRow$estimatedPrevalence, -1)

  # Check that wrapper-written CSV on disk matches and was packaged into ZIP
  csvPath <- file.path(tempDir, "phevaluator_summary_STUB_DB.csv")
  expect_true(file.exists(csvPath))

  zipFile <- packageResults(outputFolder = tempDir, databaseId = "STUB_DB")
  expect_true(file.exists(zipFile))

  unzipDir <- file.path(tempDir, "unzipped_stub")
  utils::unzip(zipFile, exdir = unzipDir)
  bundledCsv <- file.path(unzipDir, "phevaluator_summary_STUB_DB.csv")
  expect_true(file.exists(bundledCsv))

  bundledDf <- readr::read_csv(bundledCsv, col_types = readr::cols())
  bundledT2dm <- bundledDf[bundledDf$taxisCohortId == 1798326, ]
  expect_equal(bundledT2dm$status, "COMPLETED")
  expect_equal(bundledT2dm$truePositives, -1)
  expect_equal(bundledT2dm$sensitivityCi95Lb, -1)
})


