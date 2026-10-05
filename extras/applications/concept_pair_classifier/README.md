# Downstream Application Prototype: Concept Pair Temporal Classifier
## Proof-of-Concept Downstream Classifier Consuming TAXIS Mined Association Metrics

> **Operational Boundary Notice (`DEC-GR-027`, `DEC-GR-029`)**: This application is an **illustrative downstream proof of concept**. It is **not** part of the core TAXIS network study package execution on partner CDMs (`extras/CodeToRun.R`). It demonstrates how downstream tools (e.g., interactive explorers, concept set builders, or clinical review pipelines) can consume pre-computed, aggregate association matrices from TAXIS (`cab_s55_pair_all`), calculate continuity-corrected Directionality Ratios ($DR$), and group candidate associations into **descriptive temporal sequence categories** while enforcing strict **small-cell privacy protection and anti-reconstruction safeguards**.

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

This prototype demonstrates how downstream analytical workflows can consume these empirical counts, apply continuity corrections, and present privacy-safe descriptive summaries.

---

### Temporal Sequence Classification

To stabilize directional estimates, the classifier calculates the **continuity-corrected Directionality Ratio ($DR$)**:

$$DR = \frac{\text{obs\_after} + 0.5}{\text{obs\_before} + 0.5}$$

Pairs are categorized into descriptive temporal categories based on observed sequence:

| Criteria | Descriptive Category | Interpretation |
|---|---|---|
| **$0 < \text{obs\_after} < 5$ or $0 < \text{obs\_before} < 5$** | **Directionality Suppressed (<5 count)** | Directional counts are protected; ratios suppressed to prevent reconstruction |
| **$\text{obs\_after} = 0$ and $\text{obs\_before} = 0$** | **No Directional Precedence Observed** | Co-occurrences occurred exclusively on same day or insufficient directional data |
| **$\text{obs\_after} \ge 5, \text{obs\_before} \ge 5$, $DR \ge 1.50$** | **Empirically Preceding (Concept A precedes B)** | Concept A was observed prior to Concept B more frequently in longitudinal records |
| **$\text{obs\_after} \ge 5, \text{obs\_before} \ge 5$, $DR \le 0.67$** | **Empirically Following (Concept B precedes A)** | Concept B was observed prior to Concept A more frequently in longitudinal records |
| **$\text{obs\_after} \ge 5, \text{obs\_before} \ge 5$, $0.67 < DR < 1.50$** | **Empirically Balanced / Non-Directional** | Relative temporal precedence does not exhibit strong asymmetry |

> [!IMPORTANT]
> **Methodological Scope**: These categories reflect **observed empirical temporal sequence in electronic health records**. Observational sequence does **not** prove clinical causality, establish biological mechanism, or determine clinical indication. Confounding by indication, surveillance bias, diagnostic delay, and documentation artifacts can distort temporal patterns. Clinical adjudication is required to confirm clinical meaning.

---

### Privacy Protection & Anti-Reconstruction Safeguards (`REC-069-1`)

To prevent direct or indirect identification of patient-level data:
1. **Minimum Volume Threshold**: Entire rows with total co-occurrences `obs_all < 5` are withheld from display and output tables.
2. **Small-Cell Masking**: Any component cell with $0 < \text{count} < 5$ is masked to `-1` (displayed as `<5`).
3. **Anti-Inversion Protection**: When directional counts are small, derived ratios (`dr_corrected`, `dir_ab`) and directional lifts are suppressed (`None` / `NA`). This prevents algebraic recovery of hidden counts (e.g., $(10 + 0.5)/DR - 0.5 = 3$).
4. **Subtraction Protection**: Total count `obs_all` is masked to `-1` whenever complementary subtraction from other known components could reveal a suppressed cell.
5. **Sanitized Output Schemas**: All internal raw unsuppressed columns are dropped in both R and Python return objects, returning strictly privacy-safe data structures.

---

### Usage

#### Option A: R Interface (`classify_pairs.R`)
```r
source("extras/applications/concept_pair_classifier/classify_pairs.R")

# Using an existing DatabaseConnector connection:
results <- classifyConceptPairs(
  connection = conn,
  resultsSchema = "work_cab_test",
  conceptId = 260139,
  minObs = 5
)
print(results)

# Or using connectionDetails:
results <- classifyConceptPairs(
  connectionDetails = connDetails,
  resultsSchema = "work_cab_test",
  conceptId = 260139,
  minObs = 5
)
```

#### Option B: Python CLI (`classify_pairs.py`)
```bash
python extras/applications/concept_pair_classifier/classify_pairs.py --concept-id 260139 --min-obs 5
```

#### Verification Test Suites
```bash
# Python verification test (unit tests + live Postgres query + anti-reconstruction tests):
python extras/applications/concept_pair_classifier/test_classifier_demo.py

# R verification test (DatabaseConnector live query + anti-reconstruction tests):
Rscript extras/applications/concept_pair_classifier/test_classifier_demo.R
```
