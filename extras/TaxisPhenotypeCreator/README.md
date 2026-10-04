# TaxisPhenotypeCreator: Automated Clinical Phenotype Creation Engine
## Neuro-Symbolic Circe JSON Synthesis from TAXIS Knowledge Graph Associations

[![Build Status](https://github.com/ohdsi-studies/Taxis/workflows/R-CMD-check/badge.svg)](https://github.com/ohdsi-studies/Taxis/actions?query=workflow%3AR-CMD-check)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

> **Package**: `TaxisPhenotypeCreator`  
> **Framework**: OHDSI HADES (`CirceR`, `SqlRender`)  
> **Licensing**: Apache 2.0 Open Source  
> **Study Leadership**:  
> • Stephen H. Bandeian, MD, JD – Principal Investigator, Johns Hopkins University School of Medicine  
> • Gowtham Rao, MD, PhD – Investigator, CoReason, Inc. USA; OHDSI (Phenotype working group)  
> • Shaun Grannis, MD, MS – Investigator, Regenstrief Institute / Indiana University School of Medicine  
> • J. Marc Overhage, MD, PhD – Investigator, The Overhage Group / Indiana University School of Medicine  

---

## 1. Overview & Architectural Role

In observational health data research, authoring clinical cohort definitions manually is prone to substantial investigator variation (*Shoaibi, Ostropolets, Weaver, Rao, et al., AMIA 2024*).

**`TaxisPhenotypeCreator`** automates this process by translating structured clinical descriptions and empirical associations from the **TAXIS Clinical Knowledge Graph** (Pipeline v57; 112 relation codes) into formal, standards-compliant **OHDSI Circe JSON** cohort definitions and target DBMS cohort SQL expressions.

```text
┌─────────────────────────────────────────────────────────────────────────────────┐
│                 TAXIS TRIPARTITE MODULAR PACKAGE ECOSYSTEM                      │
└─────────────────────────────────────────────────────────────────────────────────┘
                                       │
         ┌─────────────────────────────┼─────────────────────────────┐
         ▼                             ▼                             ▼
┌──────────────────┐         ┌─────────────────────┐       ┌──────────────────────┐
│      Taxis       │         │TaxisPhenotypeCreator│       │TaxisPhenotypeEval... │
│  (Root Package)  │         │  (Creation Engine)  │       │ (Evaluation Package) │
│                  │         │                     │       │                      │
│ Runs 40-batch    │         │ Translates clinical │       │ Evaluates phenotypes │
│ Concept AB mining│ ──────> │ intent into Circe   │ ────> │ via CohortGenerator, │
│ across OMOP CDMs │         │ JSON cohort schemas │       │ CohortDiagnostics &  │
│ behind firewalls │         │ using KG edge rules │       │ PheValuator with     │
│                  │         │                     │       │ small-cell masking   │
└──────────────────┘         └─────────────────────┘       └──────────────────────┘
```

---

## 2. Deterministic 4-Slot Mapping Architecture

The package deterministically maps clinical intent into four standard criteria slots:

1. **Slot 1: Primary Index Criteria (`PrimaryCriteria`)**:
   - Condition occurrence index presentation.
   - Continuous prior observation window ($\ge 365$ days default).
   - First-in-history constraint.
2. **Slot 2: Confirmatory Laboratory Measurements (`InclusionRules: Confirmatory Finding`)**:
   - Specific measurement concept set.
   - Temporal window: $[-7, +30]$ days relative to index.
   - Value thresholds (e.g. $\text{HbA1c} \ge 6.5\%$, $\text{eGFR} < 60\text{ mL/min}/1.73\text{m}^2$).
3. **Slot 3: Indicated Pharmacotherapies (`InclusionRules: Indicated Drug`)**:
   - First-line indicated drug exposure.
   - Temporal window: $[0, +90]$ days following index.
4. **Slot 4: Rule-Out Exclusions (`InclusionRules: Differential Exclusions`)**:
   - Conflicting differential diagnoses or competing etiologies.
   - Requirement: Count $= 0$ across all prior history.

---

## 3. Installation

Install the package directly from GitHub:
```r
# Install from repository subdirectory
remotes::install_github("ohdsi-studies/Taxis", subdir = "extras/TaxisPhenotypeCreator")
```

Or install locally:
```r
devtools::install_local("extras/TaxisPhenotypeCreator")
```

---

## 4. Usage Examples

### 4.1 Synthesize the 5 TAXIS Benchmark Phenotypes
```r
library(TaxisPhenotypeCreator)

# Generate all 5 benchmark phenotypes (COPD, Obesity, CKD, Hyperkalemia, T2DM)
benchmarks <- TaxisPhenotypeCreator::buildBenchmarkPhenotypes()

# Export Type 2 Diabetes Mellitus to Circe JSON
TaxisPhenotypeCreator::exportCirceJson(benchmarks$T2DM, "t2dm_circe.json")
```

### 4.2 Programmatically Construct a Custom Phenotype
```r
customPhenotype <- TaxisPhenotypeCreator::createPhenotype(
  name = "Severe Hyperkalemia with Medication Management",
  primaryConcepts = list(
    list(conceptId = 434610, conceptName = "Hyperkalemia", domainId = "Condition")
  ),
  confirmatoryLabs = list(
    concepts = list(
      list(conceptId = 3023103, conceptName = "Potassium in Serum or Plasma", domainId = "Measurement")
    ),
    valueAsNumber = list(Op = "gt", Value = 5.5)
  ),
  indicatedDrugs = list(
    list(conceptId = 1353766, conceptName = "Sodium polystyrene sulfonate", domainId = "Drug")
  ),
  priorObservationDays = 365,
  outputFolder = "output_cohorts"
)
```

### 4.3 Compile Circe JSON to Target SQL
```r
# Compile to target SQL (e.g. PostgreSQL, SQL Server, Snowflake)
sqlPostgres <- TaxisPhenotypeCreator::compileCohortSql(
  circeObject = benchmarks$T2DM,
  targetDialect = "postgresql"
)
```

The resulting Circe expressions are ready to be imported into **OHDSI ATLAS** or evaluated in network studies via **`TaxisPhenotypeEvaluation`**.
