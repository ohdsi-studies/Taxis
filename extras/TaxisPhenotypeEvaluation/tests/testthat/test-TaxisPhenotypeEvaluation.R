test_that("TaxisPhenotypeEvaluation package exports required functions", {
  expect_true(exists("execute"))
  expect_true(exists("createCohorts"))
  expect_true(exists("computeCohortOverlap"))
  expect_true(exists("applyCohortOverlapSuppression"))
  expect_true(exists("runDiagnostics"))
  expect_true(exists("runPheValuator"))
  expect_true(exists("packageResults"))
})
