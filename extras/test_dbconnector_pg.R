Sys.setenv(JAVA_HOME = "C:/Program Files/DBeaver/jre")
library(DatabaseConnector)

connectionDetails <- createConnectionDetails(
  dbms = "postgresql",
  server = "localhost/synthea",
  port = 5433,
  user = "ohdsi_app",
  password = "ohdsi_app_pass_2026",
  pathToDriver = "c:/files/git/github/ohdsi-studies/Taxis/extras/testdata/jdbc"
)

conn <- connect(connectionDetails)
cat("Connected successfully to PostgreSQL!\n")

res <- querySql(conn, "SELECT COUNT(*) AS n_person FROM cdm.person;")
print(res)

res2 <- querySql(conn, "SELECT COUNT(*) AS n_lookups FROM concept_ab_vocab.cab_vocab_all_procedure;")
print(res2)

disconnect(conn)
cat("Disconnected cleanly.\n")
