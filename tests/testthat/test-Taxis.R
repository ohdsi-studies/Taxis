test_that("Taxis package exports required functions", {
  expect_true(exists("execute"))
  expect_true(exists("runConceptMining"))
  expect_true(exists("packageMiningResults"))
})
