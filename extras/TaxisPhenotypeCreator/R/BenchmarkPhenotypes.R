# @file BenchmarkPhenotypes.R
#
# Copyright 2026 Observational Health Data Sciences and Informatics
#
# This file is part of TaxisPhenotypeCreator
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

#' Build TAXIS 5 Clinical Benchmark Phenotype Definitions
#'
#' @description
#' Generates computable Circe JSON definitions for the 5 benchmark conditions evaluated
#' against the OHDSI Phenotype Library in the TAXIS study:
#' 1. COPD (Cohort 1798322 vs Library 1263)
#' 2. Obesity (Cohort 1798323 vs Library 1179)
#' 3. Chronic Kidney Disease Stage 3+ (Cohort 1798324 vs Library 1191)
#' 4. Hyperkalemia (Cohort 1798325 vs Library 940)
#' 5. Type 2 Diabetes Mellitus (Cohort 1798326 vs Library 1032)
#'
#' @param phenotypeName Optional string to select a single phenotype ("T2DM", "CKD", "COPD", "Obesity", "Hyperkalemia").
#'                      If NULL, returns all 5 benchmark phenotypes in a named list.
#'
#' @return A named list of Circe JSON cohort definitions.
#' @export
buildBenchmarkPhenotypes <- function(phenotypeName = NULL) {
  benchmarks <- list()

  # 1. Type 2 Diabetes Mellitus (1798326)
  benchmarks$T2DM <- synthesizeCirceCohort(
    name = "Type 2 Diabetes Mellitus (TAXIS 1798326)",
    primaryConcepts = list(
      list(conceptId = 201826, conceptName = "Type 2 diabetes mellitus", domainId = "Condition"),
      list(conceptId = 443729, conceptName = "Disorder due to type 2 diabetes mellitus", domainId = "Condition")
    ),
    confirmatoryLabs = list(
      concepts = list(
        list(conceptId = 3004410, conceptName = "Hemoglobin A1c/Hemoglobin.total in Blood", domainId = "Measurement"),
        list(conceptId = 40762499, conceptName = "Hemoglobin A1c [Mass fraction] in Blood", domainId = "Measurement")
      ),
      valueAsNumber = list(Op = "gte", Value = 6.5)
    ),
    indicatedDrugs = list(
      list(conceptId = 1503297, conceptName = "Metformin", domainId = "Drug"),
      list(conceptId = 40167232, conceptName = "Metformin hydrochloride", domainId = "Drug")
    ),
    exclusionConditions = list(
      list(conceptId = 201254, conceptName = "Type 1 diabetes mellitus", domainId = "Condition"),
      list(conceptId = 435216, conceptName = "Gestational diabetes mellitus", domainId = "Condition"),
      list(conceptId = 40484648, conceptName = "Secondary diabetes mellitus", domainId = "Condition")
    ),
    priorObservationDays = 365
  )

  # 2. Chronic Kidney Disease Stage 3+ (1798324)
  benchmarks$CKD <- synthesizeCirceCohort(
    name = "Chronic Kidney Disease Stage 3+ (TAXIS 1798324)",
    primaryConcepts = list(
      list(conceptId = 443611, conceptName = "Chronic kidney disease stage 3", domainId = "Condition"),
      list(conceptId = 443612, conceptName = "Chronic kidney disease stage 4", domainId = "Condition"),
      list(conceptId = 443597, conceptName = "Chronic kidney disease stage 5", domainId = "Condition"),
      list(conceptId = 193782, conceptName = "End-stage renal disease", domainId = "Condition")
    ),
    confirmatoryLabs = list(
      concepts = list(
        list(conceptId = 3049187, conceptName = "Glomerular filtration rate/1.73 sq M.predicted in Serum, Plasma or Blood", domainId = "Measurement"),
        list(conceptId = 3030354, conceptName = "Glomerular filtration rate/1.73 sq M.predicted by Creatinine-based formula", domainId = "Measurement")
      ),
      valueAsNumber = list(Op = "lt", Value = 60.0)
    ),
    indicatedDrugs = NULL,
    exclusionConditions = list(
      list(conceptId = 197320, conceptName = "Acute kidney injury", domainId = "Condition"),
      list(conceptId = 444094, conceptName = "Acute tubular necrosis", domainId = "Condition")
    ),
    priorObservationDays = 365
  )

  # 3. COPD (1798322)
  benchmarks$COPD <- synthesizeCirceCohort(
    name = "Chronic Obstructive Pulmonary Disease (TAXIS 1798322)",
    primaryConcepts = list(
      list(conceptId = 255573, conceptName = "Chronic obstructive lung disease", domainId = "Condition"),
      list(conceptId = 258780, conceptName = "Chronic bronchitis", domainId = "Condition"),
      list(conceptId = 254061, conceptName = "Emphysema", domainId = "Condition")
    ),
    confirmatoryLabs = NULL,
    indicatedDrugs = list(
      list(conceptId = 1177480, conceptName = "Tiotropium", domainId = "Drug"),
      list(conceptId = 1110410, conceptName = "Ipratropium", domainId = "Drug"),
      list(conceptId = 1154343, conceptName = "Albuterol", domainId = "Drug")
    ),
    exclusionConditions = list(
      list(conceptId = 317009, conceptName = "Asthma", domainId = "Condition"),
      list(conceptId = 256449, conceptName = "Cystic fibrosis", domainId = "Condition")
    ),
    priorObservationDays = 365
  )

  # 4. Obesity (1798323)
  benchmarks$Obesity <- synthesizeCirceCohort(
    name = "Obesity (TAXIS 1798323)",
    primaryConcepts = list(
      list(conceptId = 433736, conceptName = "Obesity", domainId = "Condition"),
      list(conceptId = 437833, conceptName = "Morbid obesity", domainId = "Condition")
    ),
    confirmatoryLabs = list(
      concepts = list(
        list(conceptId = 3038553, conceptName = "Body mass index (BMI) [Ratio]", domainId = "Measurement")
      ),
      valueAsNumber = list(Op = "gte", Value = 30.0)
    ),
    indicatedDrugs = NULL,
    exclusionConditions = NULL,
    priorObservationDays = 365
  )

  # 5. Hyperkalemia (1798325)
  benchmarks$Hyperkalemia <- synthesizeCirceCohort(
    name = "Hyperkalemia (TAXIS 1798325)",
    primaryConcepts = list(
      list(conceptId = 434610, conceptName = "Hyperkalemia", domainId = "Condition")
    ),
    confirmatoryLabs = list(
      concepts = list(
        list(conceptId = 3023103, conceptName = "Potassium [Moles/volume] in Serum or Plasma", domainId = "Measurement"),
        list(conceptId = 3015632, conceptName = "Potassium [Moles/volume] in Blood", domainId = "Measurement")
      ),
      valueAsNumber = list(Op = "gt", Value = 5.0)
    ),
    indicatedDrugs = list(
      list(conceptId = 1353766, conceptName = "Sodium polystyrene sulfonate", domainId = "Drug"),
      list(conceptId = 45774751, conceptName = "Patiromer", domainId = "Drug")
    ),
    exclusionConditions = NULL,
    priorObservationDays = 365
  )

  if (!is.null(phenotypeName)) {
    if (!phenotypeName %in% names(benchmarks)) {
      stop(sprintf("Unknown phenotype: '%s'. Available: %s", phenotypeName, paste(names(benchmarks), collapse = ", ")))
    }
    return(benchmarks[[phenotypeName]])
  }

  return(benchmarks)
}
