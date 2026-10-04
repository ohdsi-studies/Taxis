#' TAXIS Downstream Application Prototype: Concept Pair Clinical Classifier (R)
#' =========================================================================
#' Illustrative downstream tool demonstrating how pre-computed association
#' summaries from TAXIS (cab_s55_pair_all) can be queried and classified into
#' candidate clinical relationship categories based on continuity-corrected
#' Directionality Ratio (DR) and stratified lift.
#'
#' Operational Boundary Notice (DEC-GR-027, DEC-GR-029):
#' This is an illustrative proof-of-concept application, not part of the core
#' network study package execution (extras/CodeToRun.R).

suppressPackageStartupMessages({
  if (requireNamespace("DatabaseConnector", quietly = TRUE)) {
    library(DatabaseConnector)
  }
})

#' Classify Concept Pairs for a Target Concept
#'
#' @param connection A DatabaseConnector connection object
#' @param resultsSchema The schema where cab_s55_pair_all is materialized (default "work_cab_test")
#' @param conceptId Target OMOP concept ID (e.g., 260139 for Acute bronchitis)
#' @param minObs Minimum observed co-occurrence count threshold (default 5)
#' @param limit Maximum number of pairs to retrieve (default 25)
#' @return A data.frame of classified candidate pairs with privacy suppression applied
#' @export
classifyConceptPairs <- function(connection,
                                 resultsSchema = "work_cab_test",
                                 conceptId = 260139,
                                 minObs = 5,
                                 limit = 25) {
  sql <- sprintf(
    "SELECT 
       concept_a, concept_name_a,
       concept_b, concept_name_b,
       obs_all, obs_same_day, obs_after, obs_before,
       lift_after, dir_ab
     FROM %s.cab_s55_pair_all
     WHERE concept_a = %d AND obs_all >= %d
     ORDER BY obs_all DESC
     LIMIT %d;",
    resultsSchema, as.integer(conceptId), as.integer(minObs), as.integer(limit)
  )

  df <- DatabaseConnector::querySql(connection, sql)
  names(df) <- tolower(names(df))

  if (nrow(df) == 0) {
    message("No concept pairs found matching criteria.")
    return(data.frame())
  }

  # Helper: calculate continuity-corrected Directionality Ratio (DR)
  calcDR <- function(after, before) {
    a <- ifelse(is.na(after), 0, as.numeric(after))
    b <- ifelse(is.na(before), 0, as.numeric(before))
    return((a + 0.5) / (b + 0.5))
  }

  # Helper: assign candidate category
  categorizeDR <- function(dr) {
    ifelse(
      dr >= 1.50,
      "Forward Predominant (Candidate Precursor / Antecedent)",
      ifelse(
        dr <= 0.67,
        "Reverse Predominant (Candidate Intervention / Sequela)",
        "Concurrent / Balanced (Candidate Diagnostic / Biomarker)"
      )
    )
  }

  # Apply privacy cell suppression (< 5 -> -1)
  suppressSmallCells <- function(x) {
    n <- as.numeric(x)
    ifelse(is.na(n), 0, ifelse(n > 0 & n < 5, -1, n))
  }

  df$dr_corrected <- mapply(calcDR, df$obs_after, df$obs_before)
  df$candidate_category <- sapply(df$dr_corrected, categorizeDR)

  df$obs_all_suppressed      <- suppressSmallCells(df$obs_all)
  df$obs_same_day_suppressed <- suppressSmallCells(df$obs_same_day)
  df$obs_after_suppressed    <- suppressSmallCells(df$obs_after)
  df$obs_before_suppressed   <- suppressSmallCells(df$obs_before)

  return(df)
}
