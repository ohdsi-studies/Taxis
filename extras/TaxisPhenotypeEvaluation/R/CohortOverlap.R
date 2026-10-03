#' Compute Pairwise Overlap and Jaccard Similarity with Algebraic Disclosure Protection
#'
#' @details
#' Evaluates set intersections, unions, and Jaccard similarity between TAXIS-generated
#' candidate cohorts and OHDSI Phenotype Library comparator cohorts.
#' Enforces small-cell suppression (< minCellCount) on all distinct person counts and
#' masks derived ratio metrics whenever any underlying cell is suppressed to prevent
#' algebraic reverse-engineering of protected counts.
#'
#' @param connectionDetails DatabaseConnector connection details.
#' @param cohortDatabaseSchema Schema where cohort tables reside.
#' @param cohortTable Name of the cohort table.
#' @param outputFolder Path to write summary CSV outputs.
#' @param databaseId Short identifier for the database.
#' @param minCellCount Minimum count threshold for cell suppression (default is 5).
#'
#' @export
computeCohortOverlap <- function(connectionDetails,
                                 cohortDatabaseSchema,
                                 cohortTable,
                                 outputFolder,
                                 databaseId,
                                 minCellCount = 5) {

  pathToPairs <- system.file("settings", "PhenotypePairs.csv", package = "TaxisPhenotypeEvaluation")
  pairs <- readr::read_csv(pathToPairs, col_types = readr::cols())

  connection <- DatabaseConnector::connect(connectionDetails)
  on.exit(DatabaseConnector::disconnect(connection))

  overlapResults <- data.frame()

  for (i in 1:nrow(pairs)) {
    group <- pairs$pairGroup[i]
    phenoName <- pairs$phenotypeName[i]
    taxisId <- pairs$taxisCohortId[i]
    libraryId <- pairs$libraryCohortId[i]

    ParallelLogger::logInfo(sprintf("Calculating overlap for %s (TAXIS: %s vs Library: %s)...", group, taxisId, libraryId))

    sql <- "
    WITH taxis_pts AS (
      SELECT DISTINCT subject_id
      FROM @cohortDatabaseSchema.@cohortTable
      WHERE cohort_definition_id = @taxisId
    ),
    library_pts AS (
      SELECT DISTINCT subject_id
      FROM @cohortDatabaseSchema.@cohortTable
      WHERE cohort_definition_id = @libraryId
    )
    SELECT
      (SELECT COUNT(*) FROM taxis_pts) AS taxis_count,
      (SELECT COUNT(*) FROM library_pts) AS library_count,
      (SELECT COUNT(*) FROM taxis_pts t INNER JOIN library_pts l ON t.subject_id = l.subject_id) AS intersection_count,
      (SELECT COUNT(*) FROM (SELECT subject_id FROM taxis_pts UNION SELECT subject_id FROM library_pts) u) AS union_count,
      (SELECT COUNT(*) FROM taxis_pts t WHERE NOT EXISTS (SELECT 1 FROM library_pts l WHERE l.subject_id = t.subject_id)) AS taxis_only_count,
      (SELECT COUNT(*) FROM library_pts l WHERE NOT EXISTS (SELECT 1 FROM taxis_pts t WHERE t.subject_id = l.subject_id)) AS library_only_count
    ;
    "

    renderedSql <- SqlRender::render(
      sql = sql,
      cohortDatabaseSchema = cohortDatabaseSchema,
      cohortTable = cohortTable,
      taxisId = taxisId,
      libraryId = libraryId
    )
    translatedSql <- SqlRender::translate(renderedSql, targetDialect = connectionDetails$dbms)
    res <- DatabaseConnector::querySql(connection, translatedSql)
    names(res) <- tolower(names(res))

    taxisCount <- res$taxis_count[1]
    libraryCount <- res$library_count[1]
    intersectCount <- res$intersection_count[1]
    unionCount <- res$union_count[1]
    taxisOnly <- res$taxis_only_count[1]
    libraryOnly <- res$library_only_count[1]

    # Apply complementary suppression to eliminate algebraic reconstruction
    suppressed <- applyCohortOverlapSuppression(
      taxisCount = taxisCount,
      libraryCount = libraryCount,
      intersectCount = intersectCount,
      unionCount = unionCount,
      taxisOnly = taxisOnly,
      libraryOnly = libraryOnly,
      minCellCount = minCellCount
    )

    row <- data.frame(
      databaseId = databaseId,
      pairGroup = group,
      phenotypeName = phenoName,
      taxisCohortId = taxisId,
      libraryCohortId = libraryId,
      taxisPatientCount = suppressed$taxisPatientCount,
      libraryPatientCount = suppressed$libraryPatientCount,
      intersectionCount = suppressed$intersectionCount,
      unionCount = suppressed$unionCount,
      taxisOnlyCount = suppressed$taxisOnlyCount,
      libraryOnlyCount = suppressed$libraryOnlyCount,
      jaccardIndex = suppressed$jaccardIndex,
      taxisSensitivityVsLibrary = suppressed$taxisSensitivityVsLibrary,
      taxisAgreementVsLibrary = suppressed$taxisAgreementVsLibrary,
      stringsAsFactors = FALSE
    )

    overlapResults <- rbind(overlapResults, row)
  }

  overlapFile <- file.path(outputFolder, sprintf("cohort_overlap_summary_%s.csv", databaseId))
  readr::write_csv(overlapResults, overlapFile)
  ParallelLogger::logInfo(sprintf("Cohort overlap summary saved to %s (small cells and derived ratios masked where < %d)", overlapFile, minCellCount))

  return(invisible(overlapResults))
}

#' Apply Complementary Small-Cell Suppression to Cohort Overlap Partition
#'
#' @details
#' Implements rigorous algebraic disclosure protection across a 2x2 cohort overlap partition:
#' A = taxisOnly + intersectCount
#' B = libraryOnly + intersectCount
#' unionCount = taxisOnly + libraryOnly + intersectCount
#'
#' If ANY partition cell (intersectCount, taxisOnly, libraryOnly, or unionCount) is suppressed
#' (count > 0 and count < minCellCount), then to prevent linear algebraic reconstruction of the
#' suppressed small cell from marginal identities (e.g. intersectCount = taxisCount - taxisOnly),
#' all interior partition counts (intersectionCount, taxisOnlyCount, libraryOnlyCount, unionCount)
#' and all derived ratios (jaccardIndex, sensitivity, agreement) MUST be complementary-masked to -1.
#' Marginal cohort totals (taxisPatientCount, libraryPatientCount) are masked if they individually fall < minCellCount.
#'
#' @param taxisCount Total distinct patients in TAXIS cohort.
#' @param libraryCount Total distinct patients in OHDSI Library comparator cohort.
#' @param intersectCount Distinct patients in both cohorts.
#' @param unionCount Distinct patients in either cohort.
#' @param taxisOnly Distinct patients in TAXIS but not in Library.
#' @param libraryOnly Distinct patients in Library but not in TAXIS.
#' @param minCellCount Minimum count threshold (default is 5).
#'
#' @return A list containing masked counts and ratios.
#' @export
applyCohortOverlapSuppression <- function(taxisCount,
                                          libraryCount,
                                          intersectCount,
                                          unionCount,
                                          taxisOnly,
                                          libraryOnly,
                                          minCellCount = 5) {

  # Cell-level suppression flags (< minCellCount and > 0)
  taxisSuppressed <- (taxisCount < minCellCount & taxisCount > 0)
  librarySuppressed <- (libraryCount < minCellCount & libraryCount > 0)
  intersectSuppressed <- (intersectCount < minCellCount & intersectCount > 0)
  unionSuppressed <- (unionCount < minCellCount & unionCount > 0)
  taxisOnlySuppressed <- (taxisOnly < minCellCount & taxisOnly > 0)
  libraryOnlySuppressed <- (libraryOnly < minCellCount & libraryOnly > 0)

  # Check if any interior partition cell or union is suppressed
  partitionSuppressed <- (intersectSuppressed || taxisOnlySuppressed ||
                          libraryOnlySuppressed || unionSuppressed)

  if (partitionSuppressed) {
    # Complementary suppression: mask all partition cells and union to prevent
    # algebraic reconstruction of small cell via subtraction or marginal identities
    maskedIntersect <- -1
    maskedTaxisOnly <- -1
    maskedLibraryOnly <- -1
    maskedUnion <- -1
    jaccard <- -1
    sensitivityProxy <- -1
    positiveAgreement <- -1
  } else {
    maskedIntersect <- intersectCount
    maskedTaxisOnly <- taxisOnly
    maskedLibraryOnly <- libraryOnly
    maskedUnion <- unionCount
    jaccard <- ifelse(unionCount > 0, round(intersectCount / unionCount, 4), 0)
    sensitivityProxy <- ifelse(libraryCount > 0, round(intersectCount / libraryCount, 4), 0)
    positiveAgreement <- ifelse(taxisCount > 0, round(intersectCount / taxisCount, 4), 0)
  }

  maskedTaxis <- ifelse(taxisSuppressed, -1, taxisCount)
  maskedLibrary <- ifelse(librarySuppressed, -1, libraryCount)

  # If either marginal total is suppressed, also ensure all partition cells are masked
  if (taxisSuppressed || librarySuppressed) {
    maskedIntersect <- -1
    maskedTaxisOnly <- -1
    maskedLibraryOnly <- -1
    maskedUnion <- -1
    jaccard <- -1
    sensitivityProxy <- -1
    positiveAgreement <- -1
  }

  return(list(
    taxisPatientCount = maskedTaxis,
    libraryPatientCount = maskedLibrary,
    intersectionCount = maskedIntersect,
    unionCount = maskedUnion,
    taxisOnlyCount = maskedTaxisOnly,
    libraryOnlyCount = maskedLibraryOnly,
    jaccardIndex = jaccard,
    taxisSensitivityVsLibrary = sensitivityProxy,
    taxisAgreementVsLibrary = positiveAgreement
  ))
}

