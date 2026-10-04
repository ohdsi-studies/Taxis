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

test_that("TaxisPhenotypeCreator package exports required functions", {
  expect_true(exists("createPhenotype"))
  expect_true(exists("synthesizeCirceCohort"))
  expect_true(exists("compileCohortSql"))
  expect_true(exists("buildBenchmarkPhenotypes"))
  expect_true(exists("createConceptSet"))
  expect_true(exists("exportCirceJson"))
})

test_that("createConceptSet creates valid Circe ConceptSet structure", {
  concepts <- list(
    list(conceptId = 201826, conceptName = "Type 2 diabetes mellitus", domainId = "Condition")
  )
  cs <- createConceptSet(id = 0, name = "Target T2DM", concepts = concepts)

  expect_equal(cs$id, 0)
  expect_equal(cs$name, "Target T2DM")
  expect_equal(length(cs$expression$items), 1)
  expect_equal(cs$expression$items[[1]]$concept$CONCEPT_ID, 201826)
  expect_true(cs$expression$items[[1]]$includeDescendants)
  expect_false(cs$expression$items[[1]]$isExcluded)
})

test_that("synthesizeCirceCohort produces compliant 4-slot structure", {
  primary <- list(
    list(conceptId = 201826, conceptName = "Type 2 diabetes mellitus", domainId = "Condition")
  )
  labs <- list(
    concepts = list(
      list(conceptId = 3004410, conceptName = "HbA1c", domainId = "Measurement")
    ),
    valueAsNumber = list(Op = "gte", Value = 6.5)
  )
  drugs <- list(
    list(conceptId = 1503297, conceptName = "Metformin", domainId = "Drug")
  )
  exclusions <- list(
    list(conceptId = 201254, conceptName = "Type 1 diabetes mellitus", domainId = "Condition")
  )

  circe <- synthesizeCirceCohort(
    name = "Test T2DM Cohort",
    primaryConcepts = primary,
    confirmatoryLabs = labs,
    indicatedDrugs = drugs,
    exclusionConditions = exclusions,
    priorObservationDays = 365
  )

  # Check top-level Circe JSON slots
  expect_true("ConceptSets" %in% names(circe))
  expect_true("PrimaryCriteria" %in% names(circe))
  expect_true("InclusionRules" %in% names(circe))

  # PrimaryCriteria structure
  expect_equal(circe$PrimaryCriteria$ObservationWindow$PriorDays, 365)
  expect_equal(circe$PrimaryCriteria$ObservationWindow$PostDays, 0)
  expect_equal(circe$PrimaryCriteria$PrimaryCriteriaLimit$Type, "First")

  # InclusionRules structure (Confirmatory Lab, Indicated Drug, Rule-out Exclusions)
  expect_equal(length(circe$InclusionRules), 3)
  ruleNames <- sapply(circe$InclusionRules, function(r) r$name)
  expect_true("Confirmatory Laboratory Measurements" %in% ruleNames)
  expect_true("Indicated First-Line Pharmacotherapy" %in% ruleNames)
  expect_true("Rule-Out Differential Diagnosis Exclusions" %in% ruleNames)
})

test_that("buildBenchmarkPhenotypes returns all 5 benchmark definitions", {
  benchmarks <- buildBenchmarkPhenotypes()
  expect_equal(length(benchmarks), 5)
  expect_true(all(c("T2DM", "CKD", "COPD", "Obesity", "Hyperkalemia") %in% names(benchmarks)))

  # Verify specific benchmark structure
  expect_equal(benchmarks$T2DM$PrimaryCriteria$PrimaryCriteriaLimit$Type, "First")
  expect_equal(benchmarks$CKD$PrimaryCriteria$ObservationWindow$PriorDays, 365)
})

