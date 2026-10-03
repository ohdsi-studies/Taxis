#' Run CohortDiagnostics on the 10 Cohorts
#' @export
runDiagnostics <- function(connectionDetails,
                           cdmDatabaseSchema,
                           cohortDatabaseSchema,
                           cohortTable,
                           outputFolder,
                           databaseId,
                           minCellCount = 5) {

  diagFolder <- file.path(outputFolder, "diagnostics")
  if (!file.exists(diagFolder)) {
    dir.create(diagFolder, recursive = TRUE)
  }

  pathToCsv <- system.file("settings", "CohortsToCreate.csv", package = "TaxisPhenotypeEvaluation")
  cohortsToCreate <- readr::read_csv(pathToCsv, col_types = readr::cols())
  cohortTableNames <- CohortGenerator::getCohortTableNames(cohortTable = cohortTable)

  cohortDefinitionSet <- CohortGenerator::createEmptyCohortDefinitionSet()
  for (i in 1:nrow(cohortsToCreate)) {
    cid <- cohortsToCreate$cohortId[i]
    cname <- cohortsToCreate$cohortName[i]
    sqlFile <- system.file("sql", "sql_server", sprintf("%s.sql", cid), package = "TaxisPhenotypeEvaluation")
    jsonFile <- system.file("cohorts", sprintf("%s.json", cid), package = "TaxisPhenotypeEvaluation")

    cohortDefinitionSet <- rbind(
      cohortDefinitionSet,
      data.frame(
        cohortId = as.numeric(cid),
        cohortName = cname,
        sql = SqlRender::readSql(sqlFile),
        json = readr::read_file(jsonFile),
        stringsAsFactors = FALSE
      )
    )
  }

  ParallelLogger::logInfo("Executing CohortDiagnostics...")
  CohortDiagnostics::executeDiagnostics(
    cohortDefinitionSet = cohortDefinitionSet,
    connectionDetails = connectionDetails,
    cdmDatabaseSchema = cdmDatabaseSchema,
    cohortDatabaseSchema = cohortDatabaseSchema,
    cohortTable = cohortTable,
    exportFolder = diagFolder,
    databaseId = databaseId,
    runInclusionStatistics = TRUE,
    runIncludedSourceConcepts = TRUE,
    runOrphanConcepts = FALSE,
    runTimeDistributions = TRUE,
    runVisitContext = TRUE,
    runBreakdownIndexEvents = TRUE,
    runIncidenceRate = TRUE,
    runCohortOverlap = TRUE,
    runCohortCharacterization = TRUE,
    minCellCount = minCellCount
  )

  ParallelLogger::logInfo(sprintf("CohortDiagnostics export complete at %s", diagFolder))
}
