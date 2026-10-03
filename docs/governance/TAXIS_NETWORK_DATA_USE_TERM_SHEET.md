# TAXIS Network Study: Data Governance & Terms of Access Term Sheet

> **Document Type**: Network Participation Term Sheet & Data Governance Specification  
> **Target Audience**: Institutional Review Boards (IRBs), Data Governance Committees, and Network Data Partners  
> **Study Leadership**:
> - **Stephen H. Bandeian, MD, JD** (Principal Investigator, Johns Hopkins University School of Medicine)
> - **Gowtham Rao, MD, PhD** (Senior Investigator, CoReason, Inc. USA; OHDSI)
> - **Shaun Grannis, MD, MS** (Senior Investigator, Regenstrief Institute / Indiana University School of Medicine)
> - **J. Marc Overhage, MD, PhD** (Senior Investigator, The Overhage Group / Indiana University School of Medicine)  
> **OHDSI Presentation**: 2026 OHDSI Global Symposium Collaborator Showcase (Entry #127, October 20–22, 2026, New Brunswick, NJ)  

---

## 1. Principles of Data Protection & Distributed Analytics

The **TAXIS (Transparent Analytic Knowledge Graph for Interoperable Science)** network study operates strictly under the established **OHDSI distributed research paradigm**:
- **Code moves to the data; data never moves to the code.**
- All study scripts (HADES R study packages and database SQL queries) are executed entirely behind the participating data partner’s institutional firewall.
- **Zero Protected Health Information (PHI) or Personally Identifiable Information (PII)** is ever extracted, transmitted, or hosted centrally.

---

## 2. Resolving Concept-Pair Granularity & Data Sensitivity

Institutional data holders frequently evaluate the sensitivity of concept-concept co-occurrences. To guarantee strict institutional privacy while supporting community scientific goals, TAXIS establishes a **two-tiered governance architecture**:

```
┌────────────────────────────────────────────────────────────────────────┐
│                   TIER 1: LOCAL DATA PARTNER DOMAIN                    │
│   • Raw OMOP CDM Tables (condition_occurrence, drug_exposure, etc.)    │
│   • Internal Concept-Concept Pair Co-Occurrence Matrices               │
│   • Crude Person Counts and Local Contingency Tables                   │
│   ==> REMAINS ENTIRELY LOCAL BEHIND FIREWALL. NEVER SHARED.            │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Local Aggregation, Filtering & Cell Suppression (< 5)
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                  TIER 2: SHARED NETWORK DELIVERABLES                   │
│   • Aggregate Phenotype Performance (ROC-AUC, Sensitivity, PPV)        │
│   • Pairwise Cohort Overlap Indices (Jaccard Similarity)               │
│   • High-Confidence Derived Knowledge Graph Edges (Thresholded)        │
│   ==> EXPORTED VIA Results_<databaseId>.zip FOR COMMUNITY SHARING      │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Explicit Data Sharing Terms & Output Scope

| Analytics Phase | Local Execution Asset | What Leaves the Data Partner | What NEVER Leaves the Data Partner |
|---|---|---|---|
| **Phase 1: Phenotype Evaluation** | `TaxisPhenotypeEvaluation` R Package (HADES compliant) | Aggregate cohort counts (with $<5$ cell suppression), pairwise Jaccard overlap indices, standard `CohortDiagnostics` export archives, and `PheValuator` performance models (ROC-AUC, Sensitivity, Specificity, PPV). | Zero patient IDs, zero encounter dates, zero individual clinical trajectories. |
| **Phase 2: Knowledge Graph Association Mining** | Concept AB Association Rule Mining Pipeline (v57) | High-confidence, statistically thresholded clinical relationships (e.g. *Drug A Treats Condition B*), normalized lift ratios, and clinical taxonomy classifications. | Raw concept-concept co-occurrence contingency matrices, unmasked cell counts, or institution-specific patient volume distributions. |

---

## 4. Privacy Safeguards & Cell Suppression

1. **Mandatory Small-Cell Suppression**: In accordance with HIPAA Safe Harbor and international privacy standards, any aggregate count fewer than 5 (`minCellCount = 5`) is automatically masked as `-1` prior to packaging.
2. **Deterministic Output Auditing**: Output files are packaged into a single inspection-ready zip archive (`Results_<databaseId>.zip`). Participating partner institutions have full authority to inspect and audit all CSV files prior to transmission.
3. **Non-Commercial Scientific Use**: Shared outputs are restricted to scientific knowledge graph generation, open-source OHDSI Phenotype Library enhancement, and academic dissemination. Re-identification attempts are strictly prohibited.
4. **Complementary Cell Protection**: Mathematical safeguards prevent algebraic reconstruction of small cell counts from published summary ratios or marginal distributions.

---

## 5. Intellectual Property, Licensing & Academic Attribution

1. **Open Science & Community Benefit**: All derived knowledge graphs, Circe cohort definitions, and evaluation scripts are released under standard **Apache 2.0 / Creative Commons BY 4.0** open-source licenses for the benefit of the global scientific community.
2. **Authorship & Attribution**: Participating data partners contributing execution results are acknowledged and invited to co-author resulting network manuscripts and symposium proceedings in accordance with standard **ICMJE guidelines**.
3. **Institutional Autonomy**: Network participation is entirely voluntary. Sites may choose to run Phase 1 (Phenotype Evaluation) without executing Phase 2 (Knowledge Graph Association Mining).
