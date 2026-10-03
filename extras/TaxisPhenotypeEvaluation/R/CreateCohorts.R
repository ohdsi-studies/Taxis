#' Create Cohort Tables and Instantiate Cohort Set
#' @export
createCohorts <- function(connectionDetails,
                          cdmDatabaseSchema,
                          cohortDatabaseSchema,
                          cohortTable,
                          outputFolder,
                          databaseId,
                          minCellCount = 5) {

  ParallelLogger::logInfo("Loading cohort definitions from inst/settings/CohortsToCreate.csv...")
  pathToCsv <- system.file("settings", "CohortsToCreate.csv", package = "TaxisPhenotypeEvaluation")
  cohortsToCreate <- readr::read_csv(pathToCsv, col_types = readr::cols())

  # Create cohort table names
  cohortTableNames <- CohortGenerator::getCohortTableNames(cohortTable = cohortTable)

  # Establish connection
  connection <- DatabaseConnector::connect(connectionDetails)
  on.exit(DatabaseConnector::disconnect(connection))

  ParallelLogger::logInfo(sprintf("Creating cohort tables in %s.%s...", cohortDatabaseSchema, cohortTable))
  CohortGenerator::createCohortTables(
    connection = connection,
    cohortDatabaseSchema = cohortDatabaseSchema,
    cohortTableNames = cohortTableNames
  )

  # Read cohort definitions from package
  cohortDefinitionSet <- CohortGenerator::createEmptyCohortDefinitionSet()

  for (i in 1:nrow(cohortsToCreate)) {
    cid <- cohortsToCreate$cohortId[i]
    cname <- cohortsToCreate$cohortName[i]
    sqlFile <- system.file("sql", "sql_server", sprintf("%s.sql", cid), package = "TaxisPhenotypeEvaluation")
    jsonFile <- system.file("cohorts", sprintf("%s.json", cid), package = "TaxisPhenotypeEvaluation")

    sql <- SqlRender::readSql(sqlFile)
    json <- readr::read_file(jsonFile)

    cohortDefinitionSet <- rbind(
      cohortDefinitionSet,
      data.frame(
        cohortId = as.numeric(cid),
        cohortName = cname,
        sql = sql,
        json = json,
        stringsAsFactors = FALSE
      )
    )
  }

  ParallelLogger::logInfo("Instantiating 10 cohorts on the database...")
  cohortCounts <- CohortGenerator::generateCohortSet(
    connection = connection,
    cdmDatabaseSchema = cdmDatabaseSchema,
    cohortDatabaseSchema = cohortDatabaseSchema,
    cohortTableNames = cohortTableNames,
    cohortDefinitionSet = cohortDefinitionSet
  )

  # Apply cell suppression
  cohortCountsSummary <- cohortCounts %>%
    dplyr::mutate(
      databaseId = databaseId,
      cohortEntries = ifelse(cohortEntries < minCellCount & cohortEntries > 0, -1, cohortEntries),
      cohortSubjects = ifelse(cohortSubjects < minCellCount & cohortSubjects > 0, -1, cohortSubjects)
    )

  countsFile <- file.path(outputFolder, sprintf("cohort_counts_%s.csv", databaseId))
  readr::write_csv(cohortCountsSummary, countsFile)
  ParallelLogger::logInfo(sprintf("Cohort counts saved to %s (counts < %d suppressed)", countsFile, minCellCount))

  return(invisible(cohortCounts))
}
