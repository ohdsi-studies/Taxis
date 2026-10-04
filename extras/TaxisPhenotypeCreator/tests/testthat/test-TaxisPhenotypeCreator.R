test_that("TaxisPhenotypeCreator package exports required functions", {
  expect_true(exists("createPhenotype"))
  expect_true(exists("synthesizeCirceCohort"))
  expect_true(exists("compileCohortSql"))
  expect_true(exists("buildBenchmarkPhenotypes"))
})
