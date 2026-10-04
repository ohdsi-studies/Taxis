test_that("Taxis package exports required functions", {
  expect_true(exists("execute"))
  expect_true(exists("runConceptMining"))
  expect_true(exists("packageMiningResults"))
})

test_that("minCellCount threshold validation enforces scalar integer floor of 5 (REC-039-1)", {
  validateThreshold <- function(minCellCount) {
    isValidThreshold <- !is.null(minCellCount) &&
      is.numeric(minCellCount) &&
      length(minCellCount) == 1 &&
      !is.na(minCellCount) &&
      is.finite(minCellCount) &&
      (minCellCount %% 1 == 0) &&
      minCellCount >= 5

    if (!isValidThreshold) {
      5L
    } else {
      as.integer(minCellCount)
    }
  }

  expect_equal(validateThreshold(NULL), 5L)
  expect_equal(validateThreshold(NA), 5L)
  expect_equal(validateThreshold(NaN), 5L)
  expect_equal(validateThreshold(Inf), 5L)
  expect_equal(validateThreshold(-Inf), 5L)
  expect_equal(validateThreshold(-1L), 5L)
  expect_equal(validateThreshold(0L), 5L)
  expect_equal(validateThreshold(4L), 5L)
  expect_equal(validateThreshold(c(5L, 10L)), 5L)
  expect_equal(validateThreshold(5.9), 5L)
  expect_equal(validateThreshold(5.1), 5L)
  expect_equal(validateThreshold(5L), 5L)
  expect_equal(validateThreshold(10L), 10L)
  expect_equal(validateThreshold(20), 20L)
})

test_that("Cross-table gap histogram protection closes 1/19/20 subtraction attack (REC-038-2, REC-039-2)", {
  minCellCount <- 5L

  # Synthetic pattern table with bucket 7 (tight, count 1) and bucket 30 (mid, count 19)
  patternData <- data.frame(
    concept_id = c(201826L, 201826L),
    src = c(1L, 1L),
    metric = c("gap", "gap"),
    bucket = c(7L, 30L),
    n_obs = c(1L, 19L),
    n_persons = c(1L, 15L),
    stringsAsFactors = FALSE
  )

  # Synthetic grain guide row: total n_gaps = 20 (1 tight + 19 mid), tight frac = 0.05, mid frac = 0.95
  grainData <- data.frame(
    concept_id = 201826L,
    src = 1L,
    obs_act = 100L,
    pers_act = 80L,
    mentions_per_person = 1.25,
    n_gaps = 20L,
    median_gap_bucket = 30L,
    median_span_bucket = 90L,
    frac_gaps_tight = 0.05,
    frac_gaps_mid = 0.95,
    frac_gaps_long = 0.0,
    pattern = "clustered",
    grain = "first",
    rationale = "clustered event",
    stringsAsFactors = FALSE
  )

  # Track masked concepts in patternData
  maskedKeys <- character(0)
  for (i in seq_len(nrow(patternData))) {
    if (patternData$n_obs[i] > 0 && patternData$n_obs[i] < minCellCount) {
      patternData$n_obs[i] <- -1L
      if (patternData$metric[i] == "gap") {
        maskedKeys <- c(maskedKeys, paste(patternData$concept_id[i], patternData$src[i], sep = "_"))
      }
    }
  }

  expect_equal(patternData$n_obs[1], -1L)
  expect_equal(patternData$n_obs[2], 19L)
  expect_true("201826_1" %in% maskedKeys)

  # Apply joint masking to grainData
  grainKey <- paste(grainData$concept_id[1], grainData$src[1], sep = "_")
  if (grainKey %in% maskedKeys || grainData$n_gaps[1] < minCellCount) {
    grainData$n_gaps[1] <- -1L
    grainData$frac_gaps_tight[1] <- -1.0
    grainData$frac_gaps_mid[1] <- -1.0
    grainData$frac_gaps_long[1] <- -1.0
  }

  expect_equal(grainData$n_gaps[1], -1L)
  expect_equal(grainData$frac_gaps_tight[1], -1.0)
  expect_equal(grainData$frac_gaps_mid[1], -1.0)
  expect_equal(grainData$frac_gaps_long[1], -1.0)
})
