# TAXIS Network Study: Data Governance & Terms of Access Term Sheet

> **Document Type**: Network Participation Term Sheet & Data Governance Specification  
> **Target Audience**: Institutional Review Boards (IRBs), Data Governance Committees, and Network Data Partners  
> **Study Leadership**:
> - **Stephen H. Bandeian, MD, JD** (Principal Investigator, Johns Hopkins University School of Medicine)
> - **Gowtham Rao, MD, PhD** (Investigator, CoReason, Inc. USA; OHDSI)
> - **Shaun Grannis, MD, MS** (Investigator, Regenstrief Institute / Indiana University School of Medicine)
> - **J. Marc Overhage, MD, PhD** (Investigator, The Overhage Group / Indiana University School of Medicine)  
> **OHDSI Presentation**: 2026 OHDSI Global Symposium Collaborator Showcase (Entry #127, October 20–22, 2026, New Brunswick, NJ)  

---

## 1. Principles of Data Protection & Distributed Analytics

The **TAXIS (Transparent Analytic Knowledge Graph for Interoperable Science)** network study operates strictly under the established **OHDSI distributed research paradigm**:
- **Code moves to the data; data never moves to the code.**
- All study scripts (HADES R study packages and database SQL queries) are executed entirely behind the participating data partner’s institutional firewall.
- **Zero Protected Health Information (PHI) or Personally Identifiable Information (PII)** is ever extracted, transmitted, or hosted centrally.

---

## 2. Resolving Concept-Pair Granularity & Data Sensitivity

Institutional data holders frequently evaluate the sensitivity of concept-concept co-occurrences. To guarantee institutional data privacy while supporting community scientific goals, TAXIS establishes a **two-tiered governance architecture**:

```
┌────────────────────────────────────────────────────────────────────────┐
│                   TIER 1: LOCAL DATA PARTNER DOMAIN                    │
│   • Raw OMOP CDM Tables (condition_occurrence, drug_exposure, etc.)    │
│   • Internal Concept-Concept Pair Co-Occurrence Matrices               │
│   • Crude Person Counts and Local Contingency Tables                   │
│   ==> REMAINS ENTIRELY LOCAL BEHIND FIREWALL. NEVER SHARED.            │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Local Aggregation, Filtering & Cell Suppression (minCellCount)
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                  TIER 2: SHARED NETWORK DELIVERABLES                   │
│   • Permitted Aggregate Phenotype Performance Metrics (ROC-AUC, PPV)   │
│   • Pairwise Cohort Overlap Indices (Jaccard Similarity)               │
│   • Filtered Diagnostic Summary Metrics (Index Event Breakdowns)       │
│   ==> EXPORTED VIA Results_<databaseId>.zip FOR COMMUNITY SHARING      │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Explicit Data Sharing Terms & Output Allowlist

| Analytics Phase | Local Execution Asset | Permitted Shared Outputs (What Leaves Partner) | Strictly Local (What NEVER Leaves Partner) |
|---|---|---|---|
| **Phase 1: Phenotype Evaluation (Core Network Scope)** | [`TaxisPhenotypeEvaluation`](../../extras/TaxisPhenotypeEvaluation/README.md) R Package (HADES compliant) | **Allowlist Only**:<br>• Aggregate cohort counts (with small-cell suppression applied)<br>• Pairwise Jaccard cohort overlap indices<br>• Summary diagnostic characterization metrics (aggregate index event breakdowns, orphan concept aggregate counts)<br>• Summary `PheValuator` diagnostic performance metrics (Sensitivity, Specificity, PPV, NPV, F1 Score) packaged in `Results_<databaseId>.zip`. | • Zero patient IDs or person identifiers<br>• Zero encounter timestamps or visit dates<br>• Zero individual clinical trajectories<br>• Zero patient-level model weights or individual covariate records<br>• Zero raw, unfiltered diagnostic archives. |
| **Phase 2: Knowledge Graph Mining (Future Extension)** | Concept AB Association Rule Mining Pipeline | *Separate future scope subject to site-specific agreed terms*:<br>• High-confidence, statistically thresholded clinical relationship labels (e.g. *Drug A Treats Condition B*)<br>• Normalized lift ratios. | • Zero raw contingency matrices<br>• Zero unmasked pairwise co-occurrence counts<br>• Zero institution-specific patient volume distributions. |

---

## 4. Privacy Safeguards & Cell Suppression

1. **Mandatory Small-Cell Suppression**: As a baseline study disclosure policy, any aggregate count fewer than 5 (`minCellCount = 5`, or a stricter institutional threshold such as 10 or 20 if required by local governance policy) is masked prior to export. This rule is a study-specific risk mitigation threshold; participating institutions retain full discretion to enforce stricter small-cell thresholds.
2. **Deterministic Output Auditing**: Output files are pre-packaged into a single inspection-ready zip archive (`Results_<databaseId>.zip`). Participating partner institutions retain complete authority to inspect, audit, and approve all CSV files prior to transmission.
3. **Restricted Research Purpose**: Shared outputs are restricted exclusively to scientific knowledge graph evaluation, open-source OHDSI Phenotype Library enhancement, and academic dissemination. Re-identification attempts or linkage with external datasets are strictly prohibited.
4. **Complementary Cell Protection**: Mathematical checks and margin audits prevent algebraic reconstruction of suppressed small cell counts from marginal totals or summary ratios.

---

## 5. Intellectual Property, Licensing & Academic Attribution

1. **Software & Specification Licensing**: Open-source study packages, Circe cohort definitions, and technical documentation are released under the **Apache 2.0** (software) and **Creative Commons Attribution 4.0 International (CC-BY-4.0)** (documentation) licenses.
2. **Data Governance & Output Use**: Research outputs exported by participating data partners remain governed by this Data Use Term Sheet and may be utilized solely for the non-commercial academic and scientific purposes described herein.
3. **Authorship & Attribution**: Participating data partners contributing execution results are acknowledged and invited to co-author resulting network manuscripts and symposium proceedings in accordance with standard **ICMJE guidelines**.
4. **Institutional Autonomy**: Network participation is entirely voluntary. Sites participate in Phase 1 phenotype evaluation without obligation to participate in future Phase 2 association mining extensions.
