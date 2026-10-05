# @file SynthesizeCirce.R
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

#' Create an OHDSI Circe ConceptSet Expression
#'
#' @param id         Integer concept set identifier.
#' @param name       Character string descriptive name.
#' @param concepts   Data frame or list of concept tuples (conceptId, conceptName, domainId).
#'
#' @return A list conforming to OHDSI Circe ConceptSet schema.
#' @export
createConceptSet <- function(id, name, concepts) {
  items <- list()

  if (is.data.frame(concepts)) {
    for (i in seq_len(nrow(concepts))) {
      domain <- concepts$domainId[i]
      vocab <- if (domain == "Condition") "SNOMED" else if (domain == "Drug") "RxNorm" else "LOINC"
      items[[i]] <- list(
        concept = list(
          CONCEPT_ID = as.numeric(concepts$conceptId[i]),
          CONCEPT_NAME = as.character(concepts$conceptName[i]),
          STANDARD_CONCEPT = "S",
          STANDARD_CONCEPT_CAPTION = "Standard",
          INVALID_REASON = "V",
          INVALID_REASON_CAPTION = "Valid",
          CONCEPT_CODE = as.character(concepts$conceptId[i]),
          DOMAIN_ID = domain,
          VOCABULARY_ID = vocab
        ),
        isExcluded = FALSE,
        includeDescendants = TRUE,
        includeMapped = FALSE
      )
    }
  } else if (is.list(concepts)) {
    for (i in seq_along(concepts)) {
      c_item <- concepts[[i]]
      domain <- if (!is.null(c_item$domainId)) c_item$domainId else "Condition"
      vocab <- if (domain == "Condition") "SNOMED" else if (domain == "Drug") "RxNorm" else "LOINC"
      items[[i]] <- list(
        concept = list(
          CONCEPT_ID = as.numeric(c_item$conceptId),
          CONCEPT_NAME = as.character(c_item$conceptName),
          STANDARD_CONCEPT = "S",
          STANDARD_CONCEPT_CAPTION = "Standard",
          INVALID_REASON = "V",
          INVALID_REASON_CAPTION = "Valid",
          CONCEPT_CODE = as.character(c_item$conceptId),
          DOMAIN_ID = domain,
          VOCABULARY_ID = vocab
        ),
        isExcluded = FALSE,
        includeDescendants = TRUE,
        includeMapped = FALSE
      )
    }
  }

  list(
    id = id,
    name = name,
    expression = list(items = items)
  )
}

#' Synthesize Computable Circe JSON Cohort Definition
#'
#' @description
#' Implements deterministic 4-slot neuro-symbolic mapping from structured clinical intent:
#' Slot 1: Primary index event criteria (Condition occurrence with >= priorObservationDays continuous observation)
#' Slot 2: Confirmatory laboratory measurements (window: [-7, +30] days)
#' Slot 3: Indicated first-line pharmacotherapies (window: [0, +90] days)
#' Slot 4: Rule-out exclusion criteria (count = 0 in all prior history)
#'
#' @param name                   Cohort name string.
#' @param primaryConcepts        Concepts defining the primary index presentation.
#' @param confirmatoryLabs       Optional list of lab criteria (concepts, operator, value).
#' @param indicatedDrugs         Optional list of indicated drug concepts.
#' @param exclusionConditions    Optional list of exclusion condition concepts.
#' @param priorObservationDays   Required continuous prior observation in days (default: 365).
#'
#' @return A list object representing the complete OHDSI Circe JSON cohort definition.
#' @export
synthesizeCirceCohort <- function(name,
                                  primaryConcepts,
                                  confirmatoryLabs = NULL,
                                  indicatedDrugs = NULL,
                                  exclusionConditions = NULL,
                                  priorObservationDays = 365) {

  conceptSets <- list()
  nextId <- 0

  # Slot 1: Primary Index Concept Set
  csPrimary <- createConceptSet(nextId, sprintf("%s - Primary Condition", name), primaryConcepts)
  conceptSets[[length(conceptSets) + 1]] <- csPrimary
  primaryCsId <- nextId
  nextId <- nextId + 1

  inclusionRules <- list()

  # Slot 2: Confirmatory Labs
  if (!is.null(confirmatoryLabs) && length(confirmatoryLabs$concepts) > 0) {
    csLab <- createConceptSet(nextId, sprintf("%s - Confirmatory Measurement", name), confirmatoryLabs$concepts)
    conceptSets[[length(conceptSets) + 1]] <- csLab
    labCsId <- nextId
    nextId <- nextId + 1

    crit <- list(
      Measurement = list(
        CodesetId = labCsId
      )
    )
    if (!is.null(confirmatoryLabs$valueAsNumber)) {
      crit$Measurement$ValueAsNumber <- confirmatoryLabs$valueAsNumber
    }

    inclusionRules[[length(inclusionRules) + 1]] <- list(
      name = "Confirmatory Laboratory Measurements",
      description = "Evidence of confirmatory laboratory measurement in [-7, +30] day window around index presentation.",
      expression = list(
        Type = "ALL",
        CriteriaList = list(
          list(
            Criteria = crit,
            StartWindow = list(
              Start = list(Days = 7, Coeff = -1),
              End = list(Days = 30, Coeff = 1),
              UseEventEnd = FALSE
            ),
            Occurrence = list(Type = 2, Count = 1)
          )
        )
      )
    )
  }

  # Slot 3: Indicated Pharmacotherapies
  if (!is.null(indicatedDrugs) && length(indicatedDrugs) > 0) {
    csDrug <- createConceptSet(nextId, sprintf("%s - Indicated Therapy", name), indicatedDrugs)
    conceptSets[[length(conceptSets) + 1]] <- csDrug
    drugCsId <- nextId
    nextId <- nextId + 1

    inclusionRules[[length(inclusionRules) + 1]] <- list(
      name = "Indicated First-Line Pharmacotherapy",
      description = "Prescription or dispensing of indicated first-line medication within [0, +90] days following index.",
      expression = list(
        Type = "ALL",
        CriteriaList = list(
          list(
            Criteria = list(DrugExposure = list(CodesetId = drugCsId)),
            StartWindow = list(
              Start = list(Days = 0, Coeff = 1),
              End = list(Days = 90, Coeff = 1),
              UseEventEnd = FALSE
            ),
            Occurrence = list(Type = 2, Count = 1)
          )
        )
      )
    )
  }

  # Slot 4: Rule-Out Exclusions
  if (!is.null(exclusionConditions) && length(exclusionConditions) > 0) {
    csExcl <- createConceptSet(nextId, sprintf("%s - Excluded Mimics", name), exclusionConditions)
    conceptSets[[length(conceptSets) + 1]] <- csExcl
    exclCsId <- nextId
    nextId <- nextId + 1

    inclusionRules[[length(inclusionRules) + 1]] <- list(
      name = "Rule-Out Differential Diagnosis Exclusions",
      description = "Zero prior or concurrent occurrences of conflicting differential diagnoses.",
      expression = list(
        Type = "ALL",
        CriteriaList = list(
          list(
            Criteria = list(ConditionOccurrence = list(CodesetId = exclCsId)),
            StartWindow = list(
              Start = list(Days = 9999, Coeff = -1),
              End = list(Days = 30, Coeff = 1),
              UseEventEnd = FALSE
            ),
            Occurrence = list(Type = 0, Count = 0)
          )
        )
      )
    )
  }

  # Construct complete Circe JSON AST
  circe <- list(
    ConceptSets = conceptSets,
    PrimaryCriteria = list(
      CriteriaList = list(
        list(
          ConditionOccurrence = list(
            CodesetId = primaryCsId,
            First = TRUE
          )
        )
      ),
      ObservationWindow = list(
        PriorDays = priorObservationDays,
        PostDays = 0
      ),
      PrimaryCriteriaLimit = list(Type = "First")
    ),
    QualifiedLimit = list(Type = "First"),
    ExpressionLimit = list(Type = "First"),
    InclusionRules = inclusionRules,
    CensoringCriteria = list(),
    CollapseSettings = list(
      CollapseType = "ERA",
      EraPad = 0
    ),
    CensorWindow = list()
  )

  return(circe)
}
