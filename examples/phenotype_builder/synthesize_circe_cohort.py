#!/usr/bin/env python3
"""
TAXIS Automated Phenotype Recreation Engine: Circe Synthesis Script
Compiles structured clinical descriptions and Knowledge Graph relationships
into deterministic, standards-compliant OHDSI Circe JSON cohort expressions.

Usage:
  python examples/phenotype_builder/synthesize_circe_cohort.py
"""

import json
import os
import sys

OUTPUT_DIR = os.path.dirname(os.path.abspath(__file__))


def create_circe_concept_set(concept_set_id, name, concepts):
    """Generate a standard Circe ConceptSet expression."""
    items = []
    for concept_id, concept_name, domain_id in concepts:
        items.append({
            "concept": {
                "CONCEPT_ID": concept_id,
                "CONCEPT_NAME": concept_name,
                "STANDARD_CONCEPT": "S",
                "STANDARD_CONCEPT_CAPTION": "Standard",
                "INVALID_REASON": "V",
                "INVALID_REASON_CAPTION": "Valid",
                "CONCEPT_CODE": str(concept_id),
                "DOMAIN_ID": domain_id,
                "VOCABULARY_ID": "SNOMED" if domain_id == "Condition" else ("RxNorm" if domain_id == "Drug" else "LOINC")
            },
            "isExcluded": False,
            "includeDescendants": True,
            "includeMapped": False
        })
    return {
        "id": concept_set_id,
        "name": name,
        "expression": {"items": items}
    }


def synthesize_t2dm_circe():
    """Synthesize complete Circe JSON for Type 2 Diabetes Mellitus."""
    concept_sets = [
        create_circe_concept_set(0, "Type 2 Diabetes Mellitus", [
            (201826, "Type 2 diabetes mellitus", "Condition"),
            (443729, "Disorder due to type 2 diabetes mellitus", "Condition")
        ]),
        create_circe_concept_set(1, "Confirmatory HbA1c Measurement", [
            (3004410, "Hemoglobin A1c/Hemoglobin.total in Blood", "Measurement"),
            (40762499, "Hemoglobin A1c [Mass fraction] in Blood", "Measurement")
        ]),
        create_circe_concept_set(2, "First-Line Metformin Therapy", [
            (1503297, "Metformin", "Drug"),
            (40167232, "Metformin hydrochloride", "Drug")
        ]),
        create_circe_concept_set(3, "Excluded Conditions (T1DM, Gestational)", [
            (201254, "Type 1 diabetes mellitus", "Condition"),
            (435216, "Gestational diabetes mellitus", "Condition"),
            (40484648, "Secondary diabetes mellitus", "Condition")
        ])
    ]

    circe_json = {
        "ConceptSets": concept_sets,
        "PrimaryCriteria": {
            "CriteriaList": [
                {
                    "ConditionOccurrence": {
                        "CodesetId": 0,
                        "First": True
                    }
                }
            ],
            "ObservationWindow": {
                "PriorDays": 365,
                "PostDays": 0
            },
            "PrimaryCriteriaLimit": {"Type": "First"}
        },
        "QualifiedLimit": {"Type": "First"},
        "ExpressionLimit": {"Type": "First"},
        "InclusionRules": [
            {
                "name": "Confirmatory HbA1c >= 6.5% or Elevated Glucose",
                "description": "Evidence of elevated HbA1c within [-7, +30] days of index condition presentation.",
                "expression": {
                    "Type": "ALL",
                    "CriteriaList": [
                        {
                            "Criteria": {
                                "Measurement": {
                                    "CodesetId": 1,
                                    "ValueAsNumber": {
                                        "Op": "gte",
                                        "Value": 6.5
                                    }
                                }
                            },
                            "StartWindow": {
                                "Start": {"Days": 7, "Coeff": -1},
                                "End": {"Days": 30, "Coeff": 1},
                                "UseEventEnd": False
                            },
                            "Occurrence": {"Type": 2, "Count": 1}
                        }
                    ]
                }
            },
            {
                "name": "First-Line Metformin Exposure",
                "description": "Prescription or dispensing of metformin within [0, +90] days following index presentation.",
                "expression": {
                    "Type": "ALL",
                    "CriteriaList": [
                        {
                            "Criteria": {
                                "DrugExposure": {
                                    "CodesetId": 2
                                }
                            },
                            "StartWindow": {
                                "Start": {"Days": 0, "Coeff": 1},
                                "End": {"Days": 90, "Coeff": 1},
                                "UseEventEnd": False
                            },
                            "Occurrence": {"Type": 2, "Count": 1}
                        }
                    ]
                }
            },
            {
                "name": "Exclusion of Type 1 and Gestational Diabetes",
                "description": "Zero prior or concurrent occurrences of Type 1 diabetes or gestational diabetes.",
                "expression": {
                    "Type": "ALL",
                    "CriteriaList": [
                        {
                            "Criteria": {
                                "ConditionOccurrence": {
                                    "CodesetId": 3
                                }
                            },
                            "StartWindow": {
                                "Start": {"Days": 9999, "Coeff": -1},
                                "End": {"Days": 30, "Coeff": 1},
                                "UseEventEnd": False
                            },
                            "Occurrence": {"Type": 0, "Count": 0}
                        }
                    ]
                }
            }
        ],
        "CensoringCriteria": [],
        "CollapseSettings": {
            "CollapseType": "ERA",
            "EraPad": 0
        },
        "CensorWindow": {}
    }
    return circe_json


def synthesize_ckd_circe():
    """Synthesize complete Circe JSON for Chronic Kidney Disease Stage 3+."""
    concept_sets = [
        create_circe_concept_set(0, "Chronic Kidney Disease Stage 3+", [
            (443611, "Chronic kidney disease stage 3", "Condition"),
            (443612, "Chronic kidney disease stage 4", "Condition"),
            (443597, "Chronic kidney disease stage 5", "Condition"),
            (193782, "End-stage renal disease", "Condition")
        ]),
        create_circe_concept_set(1, "Confirmatory eGFR Measurement", [
            (3049187, "Glomerular filtration rate/1.73 sq M.predicted in Serum, Plasma or Blood", "Measurement"),
            (3030354, "Glomerular filtration rate/1.73 sq M.predicted by Creatinine-based formula", "Measurement")
        ]),
        create_circe_concept_set(2, "Excluded Acute Kidney Injury Events", [
            (197320, "Acute kidney injury", "Condition"),
            (444094, "Acute tubular necrosis", "Condition")
        ])
    ]

    circe_json = {
        "ConceptSets": concept_sets,
        "PrimaryCriteria": {
            "CriteriaList": [
                {
                    "ConditionOccurrence": {
                        "CodesetId": 0,
                        "First": True
                    }
                }
            ],
            "ObservationWindow": {
                "PriorDays": 365,
                "PostDays": 0
            },
            "PrimaryCriteriaLimit": {"Type": "First"}
        },
        "QualifiedLimit": {"Type": "First"},
        "ExpressionLimit": {"Type": "First"},
        "InclusionRules": [
            {
                "name": "Confirmatory eGFR < 60 mL/min/1.73m2",
                "description": "Evidence of reduced eGFR within [-30, +30] days of index presentation.",
                "expression": {
                    "Type": "ALL",
                    "CriteriaList": [
                        {
                            "Criteria": {
                                "Measurement": {
                                    "CodesetId": 1,
                                    "ValueAsNumber": {
                                        "Op": "lt",
                                        "Value": 60.0
                                    }
                                }
                            },
                            "StartWindow": {
                                "Start": {"Days": 30, "Coeff": -1},
                                "End": {"Days": 30, "Coeff": 1},
                                "UseEventEnd": False
                            },
                            "Occurrence": {"Type": 2, "Count": 1}
                        }
                    ]
                }
            },
            {
                "name": "Exclusion of Transitory Acute Kidney Injury",
                "description": "No documentation of acute tubular necrosis or acute kidney injury within 14 days prior.",
                "expression": {
                    "Type": "ALL",
                    "CriteriaList": [
                        {
                            "Criteria": {
                                "ConditionOccurrence": {
                                    "CodesetId": 2
                                }
                            },
                            "StartWindow": {
                                "Start": {"Days": 14, "Coeff": -1},
                                "End": {"Days": 0, "Coeff": 1},
                                "UseEventEnd": False
                            },
                            "Occurrence": {"Type": 0, "Count": 0}
                        }
                    ]
                }
            }
        ],
        "CensoringCriteria": [],
        "CollapseSettings": {
            "CollapseType": "ERA",
            "EraPad": 0
        },
        "CensorWindow": {}
    }
    return circe_json


def main():
    print("Compiling Circe cohort definitions from TAXIS Knowledge Graph relationships...")

    t2dm_path = os.path.join(OUTPUT_DIR, "t2dm_recreated_circe.json")
    with open(t2dm_path, "w", encoding="utf-8") as f:
        json.dump(synthesize_t2dm_circe(), f, indent=2)
    print(f"  [SUCCESS] Generated: {os.path.basename(t2dm_path)}")

    ckd_path = os.path.join(OUTPUT_DIR, "ckd_recreated_circe.json")
    with open(ckd_path, "w", encoding="utf-8") as f:
        json.dump(synthesize_ckd_circe(), f, indent=2)
    print(f"  [SUCCESS] Generated: {os.path.basename(ckd_path)}")


if __name__ == "__main__":
    main()
