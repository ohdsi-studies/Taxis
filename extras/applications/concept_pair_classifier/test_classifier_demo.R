#!/usr/bin/env Rscript
#' Test Suite: Concept Pair Classifier Prototype (R Verification)
#' ==============================================================
#' Verifies that classify_pairs.R executes cleanly via DatabaseConnector,
#' enforces strict small-cell privacy protection, drops raw unsuppressed columns,
#' exercises the production sanitization path, and correctly handles both live and
#' unavailable database scenarios (REC-070-1, REC-070-2).

if (Sys.getenv("JAVA_HOME") == "" && dir.exists("C:/Program Files/DBeaver/jre")) {
  Sys.setenv(JAVA_HOME = "C:/Program Files/DBeaver/jre")
}

source("extras/applications/concept_pair_classifier/classify_pairs.R")

cat("======================================================================\n")
cat("   TAXIS DOWNSTREAM CONCEPT PAIR CLASSIFIER R VERIFICATION SUITE       \n")
cat("======================================================================\n")

# -----------------------------------------------------------------------------
# Test 1: Production Sanitizer Unit Tests (No Mock Functions)
# -----------------------------------------------------------------------------
cat("--> Test 1: Testing production sanitizeConceptPairRows() on synthetic fixtures...\n")

# 1a: Invented disclosure attack case (after=10, before=3, total=20, same_day=7)
fixture_10_3 <- data.frame(
  concept_a = 99901,
  concept_name_a = "Test Condition",
  concept_b = 99902,
  concept_name_b = "Test Exposure",
  obs_all = 20,
  obs_same_day = 7,
  obs_after = 10,
  obs_before = 3,
  lift_after = 2.5,
  dir_ab = 0.769,
  stringsAsFactors = FALSE
)

res_10_3 <- sanitizeConceptPairRows(fixture_10_3)
cat("    10/3 Fixture Result fields:", paste(names(res_10_3), collapse = ", "), "\n")
cat("    obs_all:", res_10_3$obs_all, "| obs_before:", res_10_3$obs_before, "\n")
cat("    dr_corrected:", as.character(res_10_3$dr_corrected), "| dir_ab:", as.character(res_10_3$dir_ab), "\n")
cat("    category:", res_10_3$temporal_category, "\n")

stopifnot(nrow(res_10_3) == 1)
stopifnot(res_10_3$obs_before == -1)
stopifnot(res_10_3$obs_all == -1)           # Subtraction leakage protection (20 - 7 - 10 = 3)
stopifnot(is.na(res_10_3$dr_corrected))     # Algebraic inversion protection ((10+0.5)/DR - 0.5 = 3)
stopifnot(is.na(res_10_3$dir_ab))
stopifnot(res_10_3$temporal_category == "Directionality Suppressed (<5 count)")

# 1b: No Directional Precedence Observed (after=0, before=0, total=10, same_day=10)
fixture_no_dir <- data.frame(
  concept_a = 99901,
  concept_name_a = "Test Condition",
  concept_b = 99904,
  concept_name_b = "SameDay Only",
  obs_all = 10,
  obs_same_day = 10,
  obs_after = 0,
  obs_before = 0,
  lift_after = 1.25,
  dir_ab = 0.5,
  stringsAsFactors = FALSE
)

res_no_dir <- sanitizeConceptPairRows(fixture_no_dir)
stopifnot(nrow(res_no_dir) == 1)
stopifnot(res_no_dir$obs_all == 10)
stopifnot(res_no_dir$obs_same_day == 10)
stopifnot(res_no_dir$obs_after == 0)
stopifnot(res_no_dir$obs_before == 0)
stopifnot(res_no_dir$temporal_category == "No Directional Precedence Observed")
stopifnot(is.na(res_no_dir$dr_corrected))   # DR must be NA for no-direction
stopifnot(res_no_dir$dir_ab == 0.5)

# 1c: Withhold rows with total obs < 5
fixture_small_total <- data.frame(
  concept_a = 99901,
  concept_name_a = "Test Condition",
  concept_b = 99905,
  concept_name_b = "Rare Exposure",
  obs_all = 4,
  obs_same_day = 1,
  obs_after = 2,
  obs_before = 1,
  lift_after = 1.0,
  dir_ab = 0.5,
  stringsAsFactors = FALSE
)

res_small <- sanitizeConceptPairRows(fixture_small_total)
stopifnot(nrow(res_small) == 0)

cat("    [PASS] Production sanitizer verified on all synthetic boundary cases.\n")

# -----------------------------------------------------------------------------
# Test 2: Live DatabaseConnector Execution via connectionDetails (Documented Path)
# -----------------------------------------------------------------------------
cat("--> Test 2: Executing classifyConceptPairs() via connectionDetails on live PostgreSQL...\n")
dbHost <- Sys.getenv("POSTGRES_HOST", "localhost")
dbPort <- as.integer(Sys.getenv("POSTGRES_PORT", "5433"))
dbName <- Sys.getenv("POSTGRES_DB", "synthea")
dbUser <- Sys.getenv("POSTGRES_USER", "ohdsi_app")
dbPass <- Sys.getenv("POSTGRES_PASSWORD", "ohdsi_app_pass_2026")

envJar <- trimws(Sys.getenv("DATABASECONNECTOR_JAR_FOLDER"))
driverPath <- if (envJar != "" && dir.exists(envJar)) envJar else "c:/files/git/github/ohdsi-studies/Taxis/extras/testdata/jdbc"

connDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "postgresql",
  server = sprintf("%s/%s", dbHost, dbName),
  port = dbPort,
  user = dbUser,
  password = dbPass,
  pathToDriver = driverPath
)

# Test live execution using the connectionDetails parameter
live_res <- tryCatch({
  classifyConceptPairs(
    connectionDetails = connDetails,
    resultsSchema = "work_cab_test",
    conceptId = 260139, # Acute bronchitis
    minObs = 5,
    limit = 10
  )
}, error = function(e) {
  cat("    FATAL: Live database query failed:", e$message, "\n")
  stop("Integration test failed to query database: ", e$message)
})

stopifnot(nrow(live_res) > 0)
cat("    Retrieved", nrow(live_res), "sanitized rows via connectionDetails.\n")

# Verify schema: only privacy-safe column names returned
allowed_cols <- c("concept_id_a", "concept_name_a", "concept_id_b", "concept_name_b",
                  "obs_all", "obs_same_day", "obs_after", "obs_before",
                  "lift_after", "dir_ab", "dr_corrected", "temporal_category")
stopifnot(all(names(live_res) %in% allowed_cols))
stopifnot(!("unsuppressed" %in% names(live_res)))
cat("    [PASS] Returned dataframe strictly adheres to privacy-safe schema.\n")

# Verify acetaminophen pair
apap_idx <- grep("acetaminophen", tolower(live_res$concept_name_b))
stopifnot(length(apap_idx) > 0)
apap <- live_res[apap_idx[1], ]
cat("    Pair:", apap$concept_name_a, "<->", apap$concept_name_b, "\n")
cat("    Obs All:", apap$obs_all, "| After:", apap$obs_after, "| Before:", apap$obs_before, "\n")
cat("    DR:", apap$dr_corrected, "| Category:", apap$temporal_category, "\n")
stopifnot(apap$dr_corrected >= 1.50)
stopifnot(apap$temporal_category == "Empirically Preceding (Concept A precedes B)")
cat("    [PASS] Live DatabaseConnector connectionDetails query and classification verified.\n")

# -----------------------------------------------------------------------------
# Test 3: Unavailable Database Negative Failure Assertion (REC-070-1)
# -----------------------------------------------------------------------------
cat("--> Test 3: Verifying unavailable database raises deterministic error...\n")
badConnDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "postgresql",
  server = "127.0.0.1/nonexistent_db",
  port = 5439, # unreachable port
  user = "invalid_user",
  password = "invalid_password",
  pathToDriver = driverPath
)

bad_res <- tryCatch({
  classifyConceptPairs(
    connectionDetails = badConnDetails,
    resultsSchema = "work_cab_test",
    conceptId = 260139
  )
  FALSE
}, error = function(e) {
  cat("    Observed expected error on unavailable database:", substr(e$message, 1, 80), "...\n")
  TRUE
})

stopifnot(bad_res == TRUE)
cat("    [PASS] Unavailable database failure handled cleanly and deterministically.\n")

cat("\n======================================================================\n")
cat("   ALL R CLASSIFIER DEMO TESTS PASSED SUCCESSFULLY (3/3)              \n")
cat("======================================================================\n")
