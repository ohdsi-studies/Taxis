# Downstream Application Prototype: Concept Pair Clinical Classifier
## Proof-of-Concept Downstream Classifier Consuming TAXIS Mined Association Metrics

> **Operational Boundary Notice (`DEC-GR-027`, `DEC-GR-029`)**: This application is an **illustrative downstream proof of concept**. It is **not** part of the core TAXIS network study package execution on partner CDMs (`extras/CodeToRun.R`). It demonstrates how downstream tools (e.g., interactive explorers, concept set builders, or clinical review pipelines) can consume pre-computed, aggregate association matrices from TAXIS (`cab_s55_pair_all`), calculate continuity-corrected Directionality Ratios ($DR$), and group candidate associations into structured clinical relationship categories.

---

### Overview

Pipeline v57 of the TAXIS network study generates aggregate association summaries across concept pairs in the OMOP Common Data Model, materializing metrics in `cab_s55_pair_all`:
- `obs_all`: Total patient encounter pairs;
- `obs_same_day`: Same-day co-occurrences ($t_A = t_B$);
- `obs_after`: Precedence count where Concept A strictly preceded Concept B ($t_A < t_B$);
- `obs_before`: Precedence count where Concept B strictly preceded Concept A ($t_B < t_A$);
- `lift_after`: Observed vs. expected co-occurrence lift in the post-index window;
- `lift_before`: Observed vs. expected co-occurrence lift in the pre-index window;
- `dir_ab`: Materialized uncorrected directionality ratio ($\frac{\text{obs\_after}}{\text{obs\_after} + \text{obs\_before}}$).

This prototype demonstrates how downstream analytical workflows can consume these empirical counts and apply post-processing heuristics to support clinical investigation.

---

### Classification Heuristic

To stabilize low-cell estimates, the classifier calculates the **continuity-corrected Directionality Ratio ($DR$)**:

$$DR = \frac{\text{obs\_after} + 0.5}{\text{obs\_before} + 0.5}$$

Pairs meeting empirical volume criteria ($N \ge 5$) are categorized into three illustrative candidate groups:

| Directionality Range | Category | Illustrative Clinical Role |
|---|---|---|
| **$DR \ge 1.50$** | **Forward Predominant** | Candidate antecedent risk factors, prodromal conditions, or upstream etiologies |
| **$0.67 < DR < 1.50$** | **Concurrent / Balanced** | Candidate diagnostic evaluations, contemporaneous signs/symptoms, or syndromic clusters |
| **$DR \le 0.67$** | **Reverse Predominant** | Candidate therapeutic interventions, subsequent monitoring procedures, or downstream sequelae |

> [!IMPORTANT]
> **Methodological Scope**: These categories reflect **observed temporal sequence in electronic health records**, which serves as supporting evidence for hypothesis generation. Observational sequence does **not** prove clinical causality or identify biological mechanism. Confounding by indication, surveillance bias, diagnostic delay, and documentation artifacts can distort temporal patterns. Clinical adjudication is required to confirm biological validity.

---

### Usage

#### Option A: R Interface (`classify_pairs.R`)
```r
source("extras/applications/concept_pair_classifier/classify_pairs.R")

# Run interactive query for a concept (e.g., Acute bronchitis, concept_id = 260139)
results <- classifyConceptPairs(
  connectionDetails = connDetails,
  resultsSchema = "work_cab_test",
  conceptId = 260139,
  minObs = 5
)
print(results)
```

#### Option B: Python CLI (`classify_pairs.py`)
```bash
python extras/applications/concept_pair_classifier/classify_pairs.py --concept-id 260139 --min-obs 5
```

#### Verification Test Suite
```bash
python extras/applications/concept_pair_classifier/test_classifier_demo.py
```
