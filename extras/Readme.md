README — Concept AB (TAXIS)
Here’s a lightly edited, de-duplicated version you can paste in:

TAXIS is a new OHDSI project that helps analysts use OMOP CDM data in everyday work. The first deliverable is a curated, clinically meaningful, and analytically useful library of relationships between pairs of CDM “clinical finding” concepts to support tasks such as cohort definition and outcome specification. The CONCEPT_CF_AB package computes frequent, statistically significant person-level co-occurrences (within ±30 days) among OMOP clinical finding concepts and materializes a final output table, 'concept_ab_step_5'. Those pairs are subsequently reviewed and categorized by relationship type using an LLM. The pipeline is portable across OMOP instances: parameterized, SqlRender-compatible SQL is orchestrated in R, keeping control flow outside SQL and enabling translation to supported DBMSs.

At a high level, Concept AB reads from specific OMOP CDM inputs (currently 'condition_occurrence' and the vocabulary tables 'concept', 'concept_relationship', 'concept_ancestor') and writes only to a designated results/workspace schema under your control. A small set of curated lookup tables (maintained separately and used read-only) guides roll-ups and mappings. The run sequence is: init prepares empty working structures; a batch loop computes intermediate counts and measures; finalize consolidates results into 'concept_ab_step_5' and can create supporting indexes.

Security and connectivity follow OHDSI standards. The package does not create or modify logins, users, or grants. A DBA provisions a least-privilege run account with SELECT on required CDM tables and curated lookups, plus DDL/DML only in the chosen results schema. Connections use OHDSI’s DatabaseConnector: environment fields in a project-local '.Renviron' (DBMS, server/database, auth mode, JDBC folder, schema names, runtime knobs) are assembled at runtime; SQL is rendered and translated with SqlRender; and the R driver executes init → batch loop → finalize under already-granted rights. This keeps site specifics out of the SQL and preserves portability.

This distribution includes a project-local '.Renviron' that specifies configuration parameters, concise documentation, two R drivers, three portable SQL programs (SqlRender style for cross-DBMS execution), and a lookup CSV. The lookup maps ~115,000 OMOP clinical finding concepts to ~5,000 higher-level, clinically meaningful standard clinical finding ancestors, enabling consistent roll-ups so co-occurrence signals reflect durable, interpretable clinical categories rather than overly granular leaf terms.

Environment & prerequisites
• OS: Windows, macOS, or Linux
• R ≥ 4.2; Java ≥ 8 (17 LTS recommended); JDBC driver directory set via DATABASECONNECTOR_JAR_FOLDER
• R packages: SqlRender and DatabaseConnector (others like Andromeda/rJava/readr/glue only if you extend locally)
• Database: OMOP CDM with vocabulary loaded and a DBA‑provisioned run account with:
  – SELECT on required CDM tables (currently: condition_occurrence, concept, concept_relationship, concept_ancestor)
  – SELECT on curated lookup tables you list
  – DDL/DML (create/alter/drop table; insert/update/delete; create/drop index) in a designated results/workspace schema
  (Vocabulary is part of the CDM; listed tables are named explicitly for clarity.)

Configuration (.Renviron in the package folder)
• Connection fields: DBMS, DB_SERVER, DB_PORT, DB_USER, CAB_AUTH_MODE (e.g., prompt), DB_EXTRA_SETTINGS, DATABASECONNECTOR_JAR_FOLDER
• Schemas: CDM schema; a project/lookup schema for curated helper tables; and optionally a results/workspace schema (if omitted, the run can reuse the project/lookup schema)
• Portable SQL programs: set CAB_SQL_DIR and filenames CAB_SQL_INIT, CAB_SQL_BATCH, CAB_SQL_FINALIZE to match the files in this folder
• Lookups: CAB_LOOKUP_TABLES as comma‑separated schema.table entries (e.g., the clinical finding roll‑up table)
• Runtime controls:
  – Methodology (change only with protocol): CAB_WINDOW_DAYS (co‑occurrence window), CAB_MIN_PERSONS (row‑level stability/privacy)
  – Execution tuning (site‑dependent): CAB_BATCH_COUNT (partition count), CAB_PARTIAL_RUN_BATCH_LIMIT (use small value for smoke tests), CAB_CREATE_INDEX_DDL (keep true unless DBA manages indexes)
  – Paths/names: keep CAB_SQL_DIR and filenames consistent so the driver can find the programs

Running the pipeline
1) Edit .Renviron with site‑specific values; confirm JDBC folder path and driver.
2) In R, install SqlRender and DatabaseConnector if needed; run concept_cf_ab_precheck.R to validate environment, connectivity, and object visibility.
3) Execute concept_cf_ab_run.R. The driver renders/translates the portable SQL programs with SqlRender and executes init → batch loop → finalize using DatabaseConnector and your field‑based settings.
4) Verify outputs in the designated results/workspace schema (e.g., review top rows by n_persons_ab from the final output produced by finalize).

Troubleshooting tips
• Ensure the project‑local .Renviron is alongside the scripts and filenames match CAB_SQL_* entries.
• JDBC path must exist with a compatible driver for your DBMS.
• Keep CAB_PARTIAL_RUN_BATCH_LIMIT within [1, CAB_BATCH_COUNT] during testing.
• Load the lookup CSV into your project schema named as concept_ab_cf_rollup.
• Permission denials on create/drop/index indicate missing rights in the results/workspace schema; involve a DBA.
• All SQL is SqlRender‑style; if you see a translation edge case, capture the rendered SQL plus DBMS details.

Security & connectivity (OHDSI‑standard)
• The package does not modify security. A least‑privilege run account is pre‑provisioned by your DBA with CDM/lookup SELECT and results‑schema DDL/DML only.
• Connections use OHDSI’s DatabaseConnector with the field‑based approach. The R drivers assemble fields from .Renviron, render/translate SQL with SqlRender, and execute under the already‑granted rights.


OHDSI References
DatabaseConnector (docs): https://ohdsi.github.io/DatabaseConnector/
Connecting vignette:      https://ohdsi.github.io/DatabaseConnector/articles/Connecting.html
JDBC drivers helper:      https://ohdsi.github.io/DatabaseConnector/reference/downloadJdbcDrivers.html
GitHub repo:              https://github.com/OHDSI/DatabaseConnector

SqlRender (docs site):    https://ohdsi.github.io/SqlRender/
“Using SqlRender” guide:  https://ohdsi.github.io/SqlRender/articles/UsingSqlRender.html
CRAN README (SqlRender):  https://cran.r-project.org/web/packages/SqlRender/readme/README.html
