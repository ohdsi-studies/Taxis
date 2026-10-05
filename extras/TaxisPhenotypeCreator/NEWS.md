# TaxisPhenotypeCreator 1.0.0

Initial official release of the TaxisPhenotypeCreator HADES package.

### Features
* Neuro-symbolic Circe JSON synthesis from the TAXIS Clinical Knowledge Graph (112 relation codes).
* Deterministic 4-slot mapping: primary criteria, confirmatory laboratory criteria, indicated pharmacotherapies, and differential diagnosis rule-outs.
* Target DBMS cohort SQL compilation via `CirceR::buildCohortQuery()`.
* Pre-bundled cohort definitions for 5 benchmark clinical phenotypes (COPD, Obesity, CKD, Hyperkalemia, Type 2 Diabetes Mellitus).
* Standalone execution driver in `extras/CodeToRun.R`.
