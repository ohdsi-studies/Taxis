#' TAXIS Downstream Application Prototype: Concept Pair Temporal Classifier (R)
#' =========================================================================
#' Illustrative downstream tool demonstrating how pre-computed association
#' summaries from TAXIS (cab_s55_pair_all) can be queried and classified into
#' descriptive temporal sequence categories while enforcing strict small-cell
#' privacy protection.
#'
#' Scientific Attribution & Provenance:
#' All underlying SQL code, analytical tables (cab_s55_pair_all), 40-batch
#' partitioning architectures, and continuity-corrected Directionality Ratio (DR)
#' formulations queried by this tool were conceived, designed, and written by
#' Stephen H. Bandeian, MD, JD (Principal Investigator, Johns Hopkins University).
#'
#' Operational Boundary Notice (DEC-GR-027, DEC-GR-029):
#' This is an illustrative proof-of-concept application, not part of the core
#' network study package execution (extras/CodeToRun.R). Observational temporal
#' sequence is supporting descriptive evidence and does NOT establish clinical
#' causality, biological mechanisms, or therapeutic indications.

suppressPackageStartupMessages({
  if (requireNamespace("DatabaseConnector", quietly = TRUE)) {
    library(DatabaseConnector)
  }
})
options(databaseConnectorInteger64AsNumeric = FALSE)

#' Classify Concept Pairs for a Target Concept with Privacy Suppression
#'
#' @param connection A DatabaseConnector connection object (optional if connectionDetails provided)
#' @param connectionDetails A DatabaseConnector connectionDetails object (optional if connection provided)
#' @param resultsSchema The schema where cab_s55_pair_all is materialized (default "work_cab_test")
#' @param conceptId Target OMOP concept ID (e.g., 260139 for Acute bronchitis)
#' @param minObs Minimum observed co-occurrence count threshold (default 5)
#' @param limit Maximum number of pairs to retrieve (default 25)
#' @return A privacy-safe data.frame containing only sanitized counts and descriptive categories
#' @export
classifyConceptPairs <- function(connection = NULL,
                                 connectionDetails = NULL,
                                 resultsSchema = "work_cab_test",
                                 conceptId = 260139,
                                 minObs = 5,
                                 limit = 25) {
  # Handle connection management
  shouldClose <- FALSE
  if (is.null(connection)) {
    if (is.null(connectionDetails)) {
      stop("Must provide either 'connection' or 'connectionDetails'.")
    }
    connection <- DatabaseConnector::connect(connectionDetails)
    shouldClose <- TRUE
  }
  on.exit({
    if (shouldClose && !is.null(connection)) {
      DatabaseConnector::disconnect(connection)
    }
  })

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

  raw_df <- DatabaseConnector::querySql(connection, sql)
  names(raw_df) <- tolower(names(raw_df))

  if (nrow(raw_df) == 0) {
    message("No concept pairs found matching criteria.")
    return(data.frame())
  }

  return(sanitizeConceptPairRows(raw_df))
}

#' Sanitize and Classify Concept Pair Rows
#'
#' Applies anti-reconstruction privacy rules and descriptive temporal categorization
#' across a data frame of concept pair query results.
#'
#' @param raw_df Data frame containing raw query results from cab_s55_pair_all.
#' @return Data frame containing sanitized, cell-suppressed concept pairs.
#' @export
sanitizeConceptPairRows <- function(raw_df) {
  if (is.null(raw_df) || nrow(raw_df) == 0) {
    return(data.frame())
  }
  names(raw_df) <- tolower(names(raw_df))

  sanitized_rows <- list()
  for (i in seq_len(nrow(raw_df))) {
    row <- raw_df[i, ]
    all_val  <- if (is.na(row$obs_all)) 0 else as.numeric(row$obs_all)
    sd_val   <- if (is.na(row$obs_same_day)) 0 else as.numeric(row$obs_same_day)
    aft_val  <- if (is.na(row$obs_after)) 0 else as.numeric(row$obs_after)
    bef_val  <- if (is.na(row$obs_before)) 0 else as.numeric(row$obs_before)
    lift_val <- if (is.na(row$lift_after)) NA else as.numeric(row$lift_after)
    dir_val  <- if (is.na(row$dir_ab)) NA else as.numeric(row$dir_ab)

    # Withhold record if total observations < 5
    if (all_val < 5) {
      next
    }

    has_small_directional_cell <- (aft_val > 0 && aft_val < 5) || 
                                  (bef_val > 0 && bef_val < 5) || 
                                  (sd_val > 0 && sd_val < 5)

    if (has_small_directional_cell) {
      safe_all <- -1
      safe_sd  <- if (sd_val > 0 && sd_val < 5) -1 else sd_val
      safe_aft <- if (aft_val > 0 && aft_val < 5) -1 else aft_val
      safe_bef <- if (bef_val > 0 && bef_val < 5) -1 else bef_val
      safe_lift_aft <- if (aft_val > 0 && aft_val < 5) NA else round(lift_val, 3)
      safe_dir_ab <- NA
      safe_dr <- NA
      category <- "Directionality Suppressed (<5 count)"
    } else {
      safe_all <- all_val
      safe_sd  <- sd_val
      safe_aft <- aft_val
      safe_bef <- bef_val
      safe_lift_aft <- round(lift_val, 3)
      safe_dir_ab <- round(dir_val, 4)

      if (aft_val == 0 && bef_val == 0) {
        category <- "No Directional Precedence Observed"
        safe_dr <- NA
      } else if (aft_val < 5 || bef_val < 5) {
        category <- "Directionality Suppressed (<5 count)"
        safe_dr <- NA
        safe_dir_ab <- NA
      } else {
        raw_dr <- (aft_val + 0.5) / (bef_val + 0.5)
        safe_dr <- round(raw_dr, 4)
        if (raw_dr >= 1.50) {
          category <- "Empirically Preceding (Concept A precedes B)"
        } else if (raw_dr <= 0.67) {
          category <- "Empirically Following (Concept B precedes A)"
        } else {
          category <- "Empirically Balanced / Non-Directional"
        }
      }
    }

    sanitized_rows[[length(sanitized_rows) + 1]] <- data.frame(
      concept_id_a = as.numeric(row$concept_a),
      concept_name_a = as.character(row$concept_name_a),
      concept_id_b = as.numeric(row$concept_b),
      concept_name_b = as.character(row$concept_name_b),
      obs_all = safe_all,
      obs_same_day = safe_sd,
      obs_after = safe_aft,
      obs_before = safe_bef,
      lift_after = safe_lift_aft,
      dir_ab = safe_dir_ab,
      dr_corrected = safe_dr,
      temporal_category = category,
      stringsAsFactors = FALSE
    )
  }

  if (length(sanitized_rows) == 0) {
    return(data.frame())
  }

  result_df <- do.call(rbind, sanitized_rows)
  return(result_df)
}
