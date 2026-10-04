# ==============================================================================
# TAXIS Concept AB Mining Pipeline: Standalone SQL Execution Runner (concept_ab_run.R)
#
# ORIGINAL AUTHORSHIP & SCIENTIFIC ATTRIBUTION:
#   All SQL scripts, database architectures, 40-batch partitioning strategies,
#   and original analytic algorithms in Pipeline v57 were conceived, designed,
#   and authored by:
#     Stephen H. Bandeian, MD, JD
#     Principal Investigator, Johns Hopkins University School of Medicine
#
# STUDY LEADERSHIP:
#   • Stephen H. Bandeian, MD, JD – Principal Investigator (Original Analytic Code & SQL Author)
#   • J. Marc Overhage, MD, PhD – Co-Principal Investigator, The Overhage Group / Indiana Univ
#   • Gowtham Rao, MD, PhD – Investigator, CoReason, Inc. / OHDSI
#   • Shaun Grannis, MD, MS – Investigator, Regenstrief Institute / Indiana Univ
# ==============================================================================
#
# ---------------------------------------------------------
# HOW TO RUN
# ---------------------------------------------------------
# Run this script from the project directory — the folder that contains
# both this .R file and concept_ab.env. The script uses relative paths
# to find the .env file and to write output.sql.
#
#   VS Code:    open the project folder as your workspace, then run.
#   RStudio:    open the .Rproj, or use Session > Set Working Directory >
#               To Source File Location.
#   Terminal:   cd <project folder> ; Rscript concept_ab_run.R
# ---------------------------------------------------------

# ---------------------------------------------------------
# TECHNICAL SPECIFICATION & DIALECT HANDLING
# ---------------------------------------------------------
# * Parameterized SqlRender targetDialect in init / batch / finalize
#   (supports all OHDSI HADES dialects: postgresql, redshift, sql server, snowflake, etc.).
# * Integrated timing instrumentation around the batch loop (proc.time).
# * Validated connection and schema resolution via DatabaseConnector.
# * Enforced DBMS as the single source of truth for both connection and dialect translation.
# ---------------------------------------------------------

# ---------------------------------------------------------
# Prevent Windows from sleeping during this job
# ---------------------------------------------------------
if (tolower(Sys.info()[["sysname"]]) == "windows") {
  cat("[driver] Disabling system sleep for this session...\n")
  # Set system sleep timeout to 0 minutes (never sleep) when plugged in
  system("powercfg -change -standby-timeout-ac 0", intern = TRUE)
}

get_password <- function(label = "Database password: ") {
  if (requireNamespace("getPass", quietly = TRUE)) {
    getPass::getPass(label)
  } else {
    flush.console(); readline(label)
  }
}

# Clean, portable connection details builder (field-based OHDSI standard)
getConnectionDetails <- function() {
  # Field-based (OHDSI standard) connection details.
  dbms      <- tolower(Sys.getenv("DBMS"))
  jarFolder <- Sys.getenv("DATABASECONNECTOR_JAR_FOLDER", "")
  server    <- Sys.getenv("DB_SERVER", "")
  user      <- Sys.getenv("DB_USER", "")
  portTxt   <- Sys.getenv("DB_PORT", "")
  extras    <- Sys.getenv("DB_EXTRA_SETTINGS", "")
  authMode  <- tolower(Sys.getenv("CAB_AUTH_MODE", "prompt"))  # integrated | password_env | prompt

  if (!nzchar(dbms))   stop("DBMS is not set in .Renviron")
  if (!nzchar(server)) stop("DB_SERVER is not set in .Renviron")
  if (!dir.exists(jarFolder)) stop("DATABASECONNECTOR_JAR_FOLDER does not exist: ", jarFolder)

  # Determine password based on auth mode (prompt is the default)
  pw <- ""
  if (identical(authMode, "password_env")) {
    pw <- Sys.getenv("DB_PASSWORD", "")
    if (!nzchar(pw)) stop("CAB_AUTH_MODE=password_env but DB_PASSWORD is empty in .Renviron")
  } else if (identical(authMode, "prompt")) {
    pw <- get_password()
    if (!nzchar(trimws(pw))) stop("No password entered.")
  } else if (identical(authMode, "integrated")) {
    # SQL Server integrated security: leave user/password blank; extras should carry any required flags
    user <- ""
    pw   <- ""
  } else {
    stop("Unsupported CAB_AUTH_MODE: ", authMode, " (use: integrated | password_env | prompt)")
  }

  DatabaseConnector::createConnectionDetails(
    dbms         = dbms,
    server       = server,
    user         = user,
    password     = pw,
    port         = suppressWarnings(as.integer(portTxt)),
    pathToDriver = jarFolder,
    extraSettings= extras
  )
}

# ------------------------------------------------------------------
# ------------------------------------------------------------------
# ------------------------------------------------------------------
# concept_ab: batched pipeline runner (portable, env-driven)
# - Reads ALL config from .Renviron (fail-fast if missing)
# - Executes three SqlRender scripts:
#     1) concept_ab_init.sql          (once; builds all_persons_batch + cum tables)
#     2) concept_ab_batch.sql         (looped; one pass per batch)
#     3) concept_ab_finalize.sql      (single pass; builds *_all and final table)
# ------------------------------------------------------------------
# ------------------------------------------------------------------
# ------------------------------------------------------------------

# ---- load env first, then set JAVA_HOME before packages ----
readRenviron("concept_ab.env")           # read the .Renviron in the current working directory
Sys.setenv(JAVA_HOME = Sys.getenv("JAVA_HOME"))

suppressPackageStartupMessages({
  # optional: library(rJava)
  library(SqlRender)
  library(DatabaseConnector)
})

# ---- strict env config (single source of truth = .Renviron) ----
req  <- function(k) { v <- Sys.getenv(k, unset = ""); if (!nzchar(v)) stop(sprintf("missing required env var: %s", k)); v }
reqi <- function(k) { as.integer(req(k)) }   # <-- keep: used below for CAB_BATCH_COUNT

dbms      <- req("DBMS")
jarFolder <- req("DATABASECONNECTOR_JAR_FOLDER")
if (!dir.exists(jarFolder)) stop("DATABASECONNECTOR_JAR_FOLDER not found: ", jarFolder)

# (DB_SERVER/DB_USER/DB_PORT/DB_EXTRA_SETTINGS/CAB_AUTH_MODE are validated inside getConnectionDetails())

# Use DBMS as the SqlRender target dialect (same OHDSI dialect strings).
# Single source of truth: DBMS in the .env file.
# (See REVIEW HISTORY at top of file for why DB_DIALECT was not adopted.)
databaseDialect <- dbms


# schemas
sourceCdmSchema <- req("CDM_SCHEMA")
# Four schemas, each named explicitly. req() so a missing entry fails fast
# rather than silently collapsing one schema onto another.
projectReferenceSchema <- req("PROJECT_REFERENCE_SCHEMA")
omopReferenceSchema    <- req("OMOP_REFERENCE_SCHEMA")
resultsSchema          <- req("RESULTS_SCHEMA")

# ---- sql files (env is the single source of truth) ----
sqlDir    <- req("CAB_SQL_DIR")
initFile  <- req("CAB_SQL_INIT")
batchFile <- req("CAB_SQL_BATCH")
finalFile <- req("CAB_SQL_FINALIZE")

initSqlPath  <- file.path(sqlDir, initFile);   stopifnot(file.exists(initSqlPath))
batchSqlPath <- file.path(sqlDir, batchFile);  stopifnot(file.exists(batchSqlPath))
finSqlPath   <- file.path(sqlDir, finalFile);  stopifnot(file.exists(finSqlPath))
# ---- runtime knobs ----
# CAB_BATCH_COUNT            = total number of partitions (e.g., 40 or 100)
# CAB_PARTIAL_RUN_BATCH_LIMIT= how many batches to EXECUTE this run (1..CAB_BATCH_COUNT)
#   example: CAB_BATCH_COUNT=40, CAB_PARTIAL_RUN_BATCH_LIMIT=2  => run batches 1 and 2 (~5% of data)
#   init assigns batch_number via ntile(), which is 1-based, so batches run 1..limit.
batchCount <- reqi("CAB_BATCH_COUNT")

partialLimit <- as.integer(Sys.getenv("CAB_PARTIAL_RUN_BATCH_LIMIT", as.character(batchCount)))
if (is.na(partialLimit) || partialLimit < 1L || partialLimit > batchCount) {
  stop(sprintf("CAB_PARTIAL_RUN_BATCH_LIMIT (%s) must be an integer in [1, %d]",
               Sys.getenv("CAB_PARTIAL_RUN_BATCH_LIMIT", ""), batchCount))
}

createIdx  <- tolower(Sys.getenv("CAB_CREATE_INDEX_DDL","true")) %in% c("true","1","yes")
cab_min_ab_obs <- as.integer(Sys.getenv("CAB_MIN_AB_OBS", "0"))
cab_min_concept_obs <- as.integer(Sys.getenv("CAB_MIN_CONCEPT_OBS", "0"))
cab_min_conditional_prob <- as.numeric(Sys.getenv("CAB_MIN_CONDITIONAL_PROB", "0"))
window_days <- as.integer(Sys.getenv("CAB_WINDOW_DAYS", "35"))
data_profile_batch_limit <- as.integer(Sys.getenv("CAB_DATA_PROFILE_BATCH_LIMIT", "2"))

# CAB_FINALIZE_ONLY skips init and the batch loop and runs finalize against the
# cum tables already in the results schema. Use it after a run that was stopped
# part way, or to rebuild the _all tables with different thresholds without
# repeating hours of batch work.
finalizeOnly <- tolower(Sys.getenv("CAB_FINALIZE_ONLY", "false")) %in% c("true","1","yes","t","y")

# CAB_MAX_BATCH_NUMBER caps which batches finalize rolls up. A run stopped part
# way leaves a PARTIAL batch in the cum tables: its pair counts are incomplete
# while its marginals and person-days may not be, so including it corrupts every
# ratio for the persons in that batch, and nothing downstream could detect it.
# Set this to the last batch that COMPLETED. Blank or 0 falls back to
# CAB_PARTIAL_RUN_BATCH_LIMIT.
maxBatchNumber <- as.integer(Sys.getenv("CAB_MAX_BATCH_NUMBER", "0"))

# CAB_DROP_CUM_TABLES drops the per-batch cum tables once finalize has rolled
# them into the _all tables. They are working tables and nothing downstream
# reads them, but this is IRREVERSIBLE -- rebuilding means rerunning every
# batch. Leave off unless disk space is the binding constraint.
dropCum <- tolower(Sys.getenv("CAB_DROP_CUM_TABLES", "false")) %in% c("true","1","yes","t","y")
if (is.na(data_profile_batch_limit) || data_profile_batch_limit < 1L) {
  stop(sprintf("CAB_DATA_PROFILE_BATCH_LIMIT (%s) must be an integer >= 1",
               Sys.getenv("CAB_DATA_PROFILE_BATCH_LIMIT", "")))
}

# Current-time function for the cab_process_log step timestamps.
# postgresql: clock_timestamp() is statement-scoped (current_timestamp is
# transaction-scoped). other dialects: CURRENT_TIMESTAMP (standard ANSI / OHDSI T-SQL).
now_expr <- if (tolower(databaseDialect) == "postgresql") "clock_timestamp()" else "CURRENT_TIMESTAMP"

# ---- helpers ----
read_sql      <- function(p) paste(readLines(p, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

# Optional debug dump: set CAB_DEBUG=1 in the .env to write the SQL that is
# actually sent to the DBMS -- rendered AND translated to the target dialect --
# into the working directory. This is what executeSql() receives, so it is the
# right artifact for diagnosing dialect/translation problems. Off by default.
cabDebug <- tolower(Sys.getenv("CAB_DEBUG", "false")) %in% c("true","1","yes","t","y")
dump_sql <- function(sqlText, fileName) {
  if (cabDebug) {
    writeLines(sqlText, fileName)
    cat("[driver] CAB_DEBUG: wrote ", fileName, "\n", sep = "")
  }
}

# ---- connect (and always disconnect) ----
connectionDetails <- getConnectionDetails()
conn <- DatabaseConnector::connect(connectionDetails)

# optional quick proof
# print(DatabaseConnector::querySql(conn, "select db_name() db, suser_sname() login;"))

# ---- choose which batches to execute this run ----
# We always partition by CAB_BATCH_COUNT; we only EXECUTE the first CAB_PARTIAL_RUN_BATCH_LIMIT batches this run.
if (is.na(maxBatchNumber) || maxBatchNumber < 1L) maxBatchNumber <- partialLimit
batchList <- 1:partialLimit
cat(sprintf("[driver] batch_count=%d; executing batches: %s\n",
            batchCount, paste(batchList, collapse=",")))

# ---- refresh connection before init (handles 'connection is closed') ----
cat("[driver] refreshing connection before init...\n")
try(DatabaseConnector::disconnect(conn), silent = TRUE)
conn <- DatabaseConnector::connect(connectionDetails)  # reuse, no new prompt


# ---- init and batch loop, both skipped when CAB_FINALIZE_ONLY is set ----
if (finalizeOnly) {

  cat("[driver] CAB_FINALIZE_ONLY is set: skipping init and the batch loop.\n")
  cat(sprintf("[driver] finalize will roll up batches 1 through %d\n", maxBatchNumber))

} else {

# ---- init (pre-batch) ----
stopifnot(file.exists(initSqlPath))
cat("[driver] init\n")
sql <- SqlRender::render(
  read_sql(initSqlPath),
  source_cdm_schema       = sourceCdmSchema,
  results_database_schema = resultsSchema,
  batch_count             = batchCount,
  create_index_ddl        = createIdx
)
# Execute the init Script
sqlFinal <- SqlRender::translate(sql, targetDialect = databaseDialect)
dump_sql(sqlFinal, "rendered_init.sql")
tryCatch(
  executeSql(conn, sqlFinal, progressBar = TRUE),
  error = function(e) {
    cat("[driver] init failed: ", conditionMessage(e), " — reconnecting & retrying once...\n", sep = "")
    try(DatabaseConnector::disconnect(conn), silent = TRUE)
    conn <<- DatabaseConnector::connect(connectionDetails)  # reuse, no new prompt
    executeSql(conn, sqlFinal, progressBar = TRUE)
  }
)

# ---  Record the Start Time ---
# proc.time() returns the CPU time (user, system) and the elapsed wall-clock time
start_time <- proc.time()
# ---- batch loop ----
stopifnot(file.exists(batchSqlPath))
for (b in batchList) {
  cat(sprintf("[driver] batch %d/%d\n", b, batchCount))
  sql <- SqlRender::render(
    read_sql(batchSqlPath),
    source_cdm_schema       = sourceCdmSchema,
    project_reference_schema = projectReferenceSchema,
    results_database_schema = resultsSchema,
    batch_count             = batchCount,
    batch_number            = b,
    cab_min_ab_obs     	    = cab_min_ab_obs,
    omop_reference_schema   = omopReferenceSchema,
    window_days             = window_days,
    data_profile_batch_limit = data_profile_batch_limit,
    create_index_ddl        = createIdx,
    now_expr                = now_expr
  )
  sqlFinal <- SqlRender::translate(sql, targetDialect = databaseDialect)
  if (b == batchList[1]) dump_sql(sqlFinal, "rendered_batch.sql")  # batches differ only in @batch_number
  executeSql(conn, sqlFinal, progressBar = TRUE)
}

# compute time to compute batches and display it
end_time <- proc.time()
time_difference <- end_time - start_time
elapsed_seconds <- time_difference["elapsed"]
elapsed_minutes <- elapsed_seconds / 60
cat("\n--- Timing Results ---\n")
# Print the full difference vector for detailed review
print(time_difference)
cat(sprintf("\nTotal Elapsed Time for code block: %.4f minutes\n", elapsed_minutes))

}  # end of the init-and-batch block skipped by CAB_FINALIZE_ONLY


# ---- finalize ----
stopifnot(file.exists(finSqlPath))
cat("[driver] finalize\n")
sql <- suppressWarnings(
  SqlRender::render(
    read_sql(finSqlPath),
    project_reference_schema   = projectReferenceSchema,
    results_database_schema   = resultsSchema,
    omop_reference_schema     = omopReferenceSchema,
    cab_min_concept_obs       = cab_min_concept_obs,
    cab_min_conditional_prob  = cab_min_conditional_prob,
    window_days               = window_days,
    create_index_ddl          = createIdx,
    max_batch_number          = maxBatchNumber,
    drop_cum_tables           = dropCum
  )
)
sqlFinal <- SqlRender::translate(sql, targetDialect = databaseDialect)
dump_sql(sqlFinal, "rendered_finalize.sql")
executeSql(conn, sqlFinal, progressBar = TRUE)

cat("[driver] all done.\n")

# Ensure database connection is closed safely
DatabaseConnector::disconnect(conn)
# for debugging: displays the full error traceback from the most recent error captured.
# On a clean run this prints "No trace available" or similar — that is expected and harmless.
# Requires the 'rlang' package; if not installed, this final line errors after work is complete.
try(rlang::last_trace(), silent = TRUE)

# ---------------------------------------------------------
# Restore normal sleep settings
# ---------------------------------------------------------
if (tolower(Sys.info()[["sysname"]]) == "windows") {
  cat("[driver] Restoring system sleep timeout to 30 minutes...\n")
  system("powercfg -change -standby-timeout-ac 30", intern = TRUE)
}
