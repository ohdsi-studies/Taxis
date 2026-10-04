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

