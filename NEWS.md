# Taxis 1.0.0 (Data Partner Testing Release)

Official release of the TAXIS (Temporal Association eXploration for Clinical Inference Studies) Concept AB Mining Engine study package, ready for testing by OHDSI network data partners.

### Authorship & Intellectual Attribution
* **Conceived, designed, and written by**: Stephen H. Bandeian, MD, JD (Principal Investigator, Johns Hopkins University School of Medicine).
* **Full scientific credit and intellectual attribution** for all SQL algorithms (init, batch, finalize), database architectures, 40-batch random partitioning strategies, healthcare utilization decile stratification, continuity-corrected directionality formulations, measurement key packing schemes, and core analytical code belong to Dr. Stephen H. Bandeian.
* **Study Leadership**:
  - Stephen H. Bandeian, MD, JD — Principal Investigator & Original SQL/Analytic Code Author, [Johns Hopkins University School of Medicine](https://www.hopkinsmedicine.org)
  - J. Marc Overhage, MD, PhD — Co-Principal Investigator, The Overhage Group / [Indiana University School of Medicine](https://medicine.iu.edu)
  - Gowtham Rao, MD, PhD — Study Package Architect & Maintainer, [CoReason, Inc.](https://www.coreason.ai) / OHDSI
  - Shaun Grannis, MD, MS — Investigator, [Regenstrief Institute](https://www.regenstrief.org) / [Indiana University School of Medicine](https://medicine.iu.edu)

### Highlights & Core Features
* **Distributed Association Mining Engine (Pipeline v57)**:
  - Discovers and quantifies empirical longitudinal clinical concept pairs across six OMOP CDM cross-domain intersections: Condition-Drug, Condition-Measurement, Condition-Procedure, Condition-Condition, Drug-Procedure, and Drug-Drug.
  - 40-batch balanced random hash partitioning (`abs(hashbytes('md5', person_id)) % 40 + 1`) to manage memory and disk footprint across large-scale databases.
  - Multi-window co-occurrence risk intervals (default: 182 days; configurable).
* **Statistical Estimands & Mathematical Formulations**:
  - Crude Poisson event lift ($Lift_{obs} = O_{AB} / E_{obs}$) and Wilson-Hilferty asymmetrical 95% Poisson confidence limits.
  - Healthcare utilization decile stratification (10 deciles) to eliminate contact density and surveillance confounding ($E_{MH}$).
  - Cochran-Mantel-Haenszel common odds ratio ($OR_{MH}$) with continuity-corrected directionality ratios ($DR_{corrected} = (O_{after} + 0.5) / (O_{before} + 0.5)$).
  - Symmetric reflection of within-domain pairs (`1010`, `2020`, `3030`, `4040`, `6060`) ensuring uniform queryability.
* **Cross-Dialect Database Portability**:
  - Full HADES conformance via `DatabaseConnector` and `SqlRender`.
  - Validated and tested across PostgreSQL, Microsoft SQL Server, AWS Redshift, Snowflake, Oracle, and Google BigQuery.
  - Parameterized index creation (`createIndexDdl`) allowing seamless execution on cloud columnar data warehouse engines.
  - Hardened with `executeSqlSafely()` to eliminate JDBC driver empty-statement crashes (`REC-063-1`).
* **Data Partner Privacy & Governance (`DEC-GR-005`)**:
  - Zero patient-level data transmission; analytical pipeline runs 100% locally behind partner firewalls.
  - Automated small-cell suppression (< 5 masked to -1) across all exported count fields.
  - Mathematical anti-reconstruction protection across 2x2 contingency tables and companion fields (`REC-038-2`).
  - Strict path allowlist packaging generating `Results_Mining_<databaseId>.zip`.
* **Push-Button Network Execution**:
  - Pre-flight verification (Phase A: `batchCount = 40`, `partialRunBatchLimit = 1`) executes in minutes to verify drivers, permissions, and schemas.
  - Full production execution (Phase B: `partialRunBatchLimit = 40`) executes the complete longitudinal study.
  - Single driver script in `extras/CodeToRun.R`.
