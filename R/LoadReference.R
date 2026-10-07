# @file LoadReference.R
#
# Copyright 2026 Observational Health Data Sciences and Informatics
#
# This file is part of Taxis
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#' Load TAXIS Reference Tables into Target Database
#'
#' @description
#' Unpacks and loads the normalized TAXIS reference lookup tables from the
#' bundled package assets (\code{inst/csv/*.csv.gz}) directly into the
#' target database schema.
#'
#' Tables loaded:
#' \itemize{
#'   \item \code{cab_visit_hierarchy} (20 rows, visit setting hierarchy)
#'   \item \code{cab_chronic_conditions} (29,346 rows, AHRQ CCSR chronic condition flags)
#'   \item \code{cab_device} (32,517 rows, device mapping and 365-day implant flags)
#'   \item \code{cab_procedure} (151,868 rows, procedure rollups, RBCS categories, CMS RVUs)
#'   \item \code{cab_meas_obs_test} (299,934 rows, lab/obs tests, assertion & question gates)
#'   \item \code{cab_drug_ing_form} (2,996,686 rows, 4-integer drug to ingredient/dose form map)
#'   \item \code{cab_concept_names} (392,648 rows, unified naming authority for output concepts)
#' }
#'
#' Optionally creates backward-compatibility views (\code{cab_vocab_all_*}) so that
#' legacy v57 queries execute seamlessly.
#'
#' @param connectionDetails        An object of type \code{connectionDetails} created using
#'                                 \code{\link[DatabaseConnector]{createConnectionDetails}},
#'                                 or an existing active database connection.
#' @param referenceSchema          Target schema name where reference tables will reside
#'                                 (e.g., \code{"concept_ab_vocab"} or user scratch schema).
#' @param overwrite                Logical; if \code{TRUE}, drops existing tables and reloads
#'                                 them. If \code{FALSE} (default), checks if each table exists
#'                                 and is non-empty, skipping existing tables.
#' @param createIndices            Logical; whether to create performance indexes on the loaded
#'                                 tables. Set to \code{FALSE} for cloud columnar platforms
#'                                 (Snowflake, BigQuery, Redshift). Default is \code{TRUE}.
#' @param createCompatibilityViews Logical; whether to create \code{cab_vocab_all_*} views
#'                                 mapping legacy query expectations to the normalized tables.
#'                                 Default is \code{TRUE}.
#' @param progressBar              Logical; whether to display progress indicators during bulk
#'                                 insertion. Default is \code{TRUE}.
#'
#' @return
#' Invisibly returns a named list with row counts for each loaded reference table.
#'
#' @export
loadReferenceTables <- function(connectionDetails,
                                referenceSchema,
                                overwrite = FALSE,
                                createIndices = TRUE,
                                createCompatibilityViews = TRUE,
                                progressBar = TRUE) {

  if (missing(connectionDetails) || is.null(connectionDetails)) {
    stop("Parameter 'connectionDetails' must be provided.")
  }
  if (missing(referenceSchema) || is.null(referenceSchema) || nchar(referenceSchema) == 0) {
    stop("Parameter 'referenceSchema' must be specified.")
  }

  isExternalConn <- inherits(connectionDetails, "DatabaseConnectorConnection")
  if (isExternalConn) {
    conn <- connectionDetails
  } else {
    conn <- DatabaseConnector::connect(connectionDetails)
    on.exit(DatabaseConnector::disconnect(conn), add = TRUE)
  }

  dbms <- DatabaseConnector::dbms(conn)
  ParallelLogger::logInfo("=====================================================================")
  ParallelLogger::logInfo("TAXIS: Loading Normalized Reference Tables")
  ParallelLogger::logInfo(sprintf("Target DBMS: %s", dbms))
  ParallelLogger::logInfo(sprintf("Reference Schema: %s", referenceSchema))
  ParallelLogger::logInfo(sprintf("Overwrite: %s", overwrite))
  ParallelLogger::logInfo("=====================================================================")

  # 1. Attempt to ensure schema exists if privileges allow
  tryCatch({
    createSchemaSql <- sprintf("CREATE SCHEMA IF NOT EXISTS %s;", referenceSchema)
    createSchemaSql <- SqlRender::translate(createSchemaSql, targetDialect = dbms)
    DatabaseConnector::executeSql(conn, createSchemaSql, progressBar = FALSE)
  }, error = function(e) {
    # If user doesn't have CREATE SCHEMA, warn and assume schema already exists
    ParallelLogger::logDebug(sprintf("Notice on schema creation: %s", e$message))
  })

  # Table specifications
  tablesToLoad <- list(
    list(name = "cab_visit_hierarchy",   file = "cab_visit_hierarchy.csv.gz",   expectedRows = 20),
    list(name = "cab_chronic_conditions",file = "cab_chronic_conditions.csv.gz",expectedRows = 29346),
    list(name = "cab_device",            file = "cab_device.csv.gz",            expectedRows = 32517),
    list(name = "cab_procedure",         file = "cab_procedure.csv.gz",         expectedRows = 151868),
    list(name = "cab_meas_obs_test",     file = "cab_meas_obs_test.csv.gz",     expectedRows = 299934),
    list(name = "cab_concept_names",     file = "cab_concept_names.csv.gz",     expectedRows = 392648),
    list(name = "cab_drug_ing_form",     file = "cab_drug_ing_form.csv.gz",     expectedRows = 2996686)
  )

  results <- list()

  for (t in tablesToLoad) {
    tName <- t$name
    fName <- t$file
    expRows <- t$expectedRows

    # Check if table already exists
    tableExists <- DatabaseConnector::existsTable(conn, databaseSchema = referenceSchema, tableName = tName)

    if (tableExists && !overwrite) {
      cntSql <- sprintf("SELECT COUNT(*) AS row_count FROM %s.%s;", referenceSchema, tName)
      cntSql <- SqlRender::translate(cntSql, targetDialect = dbms)
      existingCnt <- DatabaseConnector::querySql(conn, cntSql)
      nRowsExisting <- as.numeric(existingCnt[1, 1])

      if (nRowsExisting > 0) {
        ParallelLogger::logInfo(sprintf("  Table %s.%s already exists with %s rows. Skipping (overwrite=FALSE).",
                                        referenceSchema, tName, format(nRowsExisting, big.mark = ",")))
        results[[tName]] <- nRowsExisting
        next
      }
    }

    # Locate asset file
    filePath <- system.file("csv", fName, package = "Taxis")
    if (filePath == "" || !file.exists(filePath)) {
      # Fallback to local inst/csv for source dev workflow
      localPath <- file.path("inst", "csv", fName)
      if (file.exists(localPath)) {
        filePath <- localPath
      } else {
        stop(sprintf("Reference data asset '%s' not found in package or local directory.", fName))
      }
    }

    ParallelLogger::logInfo(sprintf("  Loading %s from %s...", tName, basename(filePath)))
    t0 <- proc.time()

    # Read gzipped CSV into data frame
    conGz <- gzfile(filePath, "rt")
    df <- utils::read.csv(conGz, stringsAsFactors = FALSE)
    close(conGz)

    # Insert into database
    DatabaseConnector::insertTable(
      connection          = conn,
      databaseSchema      = referenceSchema,
      tableName           = tName,
      data                = df,
      dropTableIfExists   = overwrite,
      createTable         = TRUE,
      tempTable           = FALSE,
      progressBar         = progressBar,
      camelCaseToSnakeCase= FALSE
    )

    elapsedSec <- (proc.time() - t0)["elapsed"]
    cntSql <- sprintf("SELECT COUNT(*) AS row_count FROM %s.%s;", referenceSchema, tName)
    cntSql <- SqlRender::translate(cntSql, targetDialect = dbms)
    rowCnt <- as.numeric(DatabaseConnector::querySql(conn, cntSql)[1, 1])
    results[[tName]] <- rowCnt

    ParallelLogger::logInfo(sprintf("  Loaded %s.%s: %s rows in %.1f seconds.",
                                    referenceSchema, tName, format(rowCnt, big.mark = ","), elapsedSec))
  }

  # Build Performance Indexes
  if (createIndices && !tolower(dbms) %in% c("snowflake", "bigquery", "redshift", "netezza", "spark")) {
    ParallelLogger::logInfo("--> Building performance indexes on reference tables...")
    indexSqls <- c(
      sprintf("CREATE INDEX IF NOT EXISTS ix_cab_vh ON %s.cab_visit_hierarchy (visit_concept_id);", referenceSchema),
      sprintf("CREATE INDEX IF NOT EXISTS ix_cab_cc ON %s.cab_chronic_conditions (concept_id);", referenceSchema),
      sprintf("CREATE INDEX IF NOT EXISTS ix_cab_dev ON %s.cab_device (concept_id_in);", referenceSchema),
      sprintf("CREATE INDEX IF NOT EXISTS ix_cab_proc ON %s.cab_procedure (concept_id_in);", referenceSchema),
      sprintf("CREATE INDEX IF NOT EXISTS ix_cab_meas ON %s.cab_meas_obs_test (concept_id_in);", referenceSchema),
      sprintf("CREATE INDEX IF NOT EXISTS ix_cab_drug ON %s.cab_drug_ing_form (concept_id_in);", referenceSchema),
      sprintf("CREATE INDEX IF NOT EXISTS ix_cab_names ON %s.cab_concept_names (concept_id);", referenceSchema)
    )

    for (idxSql in indexSqls) {
      tryCatch({
        idxTrans <- SqlRender::translate(idxSql, targetDialect = dbms)
        DatabaseConnector::executeSql(conn, idxTrans, progressBar = FALSE)
      }, error = function(e) {
        ParallelLogger::logDebug(sprintf("Index note: %s", e$message))
      })
    }
  }

  # Build Backward-Compatibility Views
  if (createCompatibilityViews) {
    ParallelLogger::logInfo("--> Creating backward-compatibility views (cab_vocab_all_*)...")
    viewSqls <- c(
      sprintf("CREATE OR REPLACE VIEW %s.cab_vocab_all_visit_hierarchy AS
               SELECT visit_concept_id, visit_concept_name, visit_level, visit_level_name
               FROM %s.cab_visit_hierarchy;", referenceSchema, referenceSchema),

      sprintf("CREATE OR REPLACE VIEW %s.cab_vocab_all_chronic_conditions AS
               SELECT concept_id, CAST(NULL AS VARCHAR(255)) AS concept_name, CAST(NULL AS VARCHAR(20)) AS route,
                      CAST(NULL AS BIGINT) AS via_ancestor_id, CAST(NULL AS VARCHAR(255)) AS via_ancestor_name,
                      CAST(NULL AS INTEGER) AS via_ancestor_desc_count
               FROM %s.cab_chronic_conditions;", referenceSchema, referenceSchema),

      sprintf("CREATE OR REPLACE VIEW %s.cab_vocab_all_device AS
               SELECT d.concept_id_in, CAST(NULL AS VARCHAR(255)) AS concept_name_in, CAST(NULL AS VARCHAR(20)) AS concept_domain_in,
                      CAST(NULL AS VARCHAR(20)) AS concept_vocab_in, d.concept_id, n.concept_name, n.concept_domain, n.concept_vocab,
                      d.implant_flag, CAST(NULL AS INTEGER) AS concept_rbcs_1, CAST(NULL AS VARCHAR(250)) AS concept_rbcs_1t,
                      CAST(NULL AS NUMERIC(10,2)) AS concept_rvu
               FROM %s.cab_device d
               LEFT JOIN %s.cab_concept_names n ON d.concept_id = n.concept_id;", referenceSchema, referenceSchema, referenceSchema),

      sprintf("CREATE OR REPLACE VIEW %s.cab_vocab_all_procedure AS
               SELECT p.concept_id_in, CAST(NULL AS VARCHAR(255)) AS concept_name_in, CAST(NULL AS VARCHAR(20)) AS concept_domain_in,
                      CAST(NULL AS VARCHAR(20)) AS concept_vocab_in, p.concept_id, n.concept_name, n.concept_domain, n.concept_vocab,
                      p.concept_rbcs_1, CAST(NULL AS VARCHAR(250)) AS concept_rbcs_1t, p.concept_rvu
               FROM %s.cab_procedure p
               LEFT JOIN %s.cab_concept_names n ON p.concept_id = n.concept_id;", referenceSchema, referenceSchema, referenceSchema),

      sprintf("CREATE OR REPLACE VIEW %s.cab_vocab_all_meas_obs_test AS
               SELECT m.concept_id_in, CAST(NULL AS VARCHAR(255)) AS concept_name_in, CAST(NULL AS VARCHAR(20)) AS concept_class_in,
                      CAST(NULL AS VARCHAR(20)) AS concept_domain_in, CAST(NULL AS VARCHAR(20)) AS concept_vocab_in,
                      m.concept_id, n.concept_name, n.concept_domain, CAST(NULL AS VARCHAR(20)) AS concept_class, n.concept_vocab,
                      m.is_question, m.is_assertion_eligible, m.flag_concept_id
               FROM %s.cab_meas_obs_test m
               LEFT JOIN %s.cab_concept_names n ON m.concept_id = n.concept_id;", referenceSchema, referenceSchema, referenceSchema),

      sprintf("CREATE OR REPLACE VIEW %s.cab_vocab_all_drug_ing_form AS
               SELECT d.concept_id_in, CAST(NULL AS VARCHAR(255)) AS concept_name_in, CAST(NULL AS VARCHAR(20)) AS concept_domain_in,
                      CAST(NULL AS VARCHAR(20)) AS concept_vocab_in, d.ingredient_id, CAST(NULL AS VARCHAR(255)) AS ingredient_name,
                      d.dose_form_concept_id, CAST(NULL AS VARCHAR(250)) AS dose_form_name,
                      CAST(NULL AS INTEGER) AS dose_form_category_number, CAST(NULL AS VARCHAR(250)) AS dose_form_category_name,
                      CAST(NULL AS VARCHAR(61)) AS ing_form_text_key, d.concept_id, n.concept_name, n.concept_domain, n.concept_vocab
               FROM %s.cab_drug_ing_form d
               LEFT JOIN %s.cab_concept_names n ON d.concept_id = n.concept_id;", referenceSchema, referenceSchema, referenceSchema)
    )

    for (vSql in viewSqls) {
      tryCatch({
        vTrans <- SqlRender::translate(vSql, targetDialect = dbms)
        DatabaseConnector::executeSql(conn, vTrans, progressBar = FALSE)
      }, error = function(e) {
        ParallelLogger::logDebug(sprintf("Compatibility view notice: %s", e$message))
      })
    }
  }

  ParallelLogger::logInfo("TAXIS: Reference table loading complete.")
  invisible(results)
}
