# TAXIS Clinical Knowledge Graph & Relationship Taxonomy

This directory contains the formal ontology specifications, relational schemas, and scientific monographs defining the **TAXIS Clinical Pair Taxonomy (CPT-6)**.

---

## Document Index

### 1. [Overview & Empirical Grounding of the TAXIS Clinical Pair Taxonomy](TAXONOMY_OVERVIEW.md)
**High-Level Scientific Overview**:
- **Scientific Provenance & Authorship**: Dr. Stephen H. Bandeian's clinical concept-pair architecture and SQL mining engine; Dr. J. Marc Overhage's clinical validation architecture, ClinVec benchmarks, and blinded dual-internist adjudication; and Dr. Gowtham Rao's empirical phenotype integration and statistical governance.
- **Empirical Grounding**: Coordination with Pipeline v57 metrics materialized in `cab_s55_pair_all` (co-occurrences, continuity-corrected Directionality Ratio $DR$, and Mantel-Haenszel Stratified Lift $\text{Lift}_{\text{strat}}$).
- **The Five Core Relationship Families**: Operational grouping of clinical relationships (Causal Mechanisms, Manifestations, Diagnostics, Interventions, and Mimics).
- **Methodological Boundaries**: Clarifying observational timing versus biological causality.

### 2. [TAXIS Clinical Pair Taxonomy v6.0](Clinical_Pair_Taxonomy_6.md)
Formal knowledge graph schema, relational code tables, directional precedence boundaries, and inverse symmetry specifications for the 112 standardized relation codes.

---

## Companion Specifications

- **Semantic Prompt Implementation**: See [`examples/taxonomy/prompts_and_examples.md`](../../examples/taxonomy/prompts_and_examples.md) for the Two-Stage Screen-and-Code LLM prompts and exemplar execution outputs.
- **Empirical Validation Results**: See [`docs/validation/ClinVec_Benchmark_Results.md`](../validation/ClinVec_Benchmark_Results.md) for the Blinded Dual-Internist Adjudication results (88.3% broad group agreement, 58.1% exact code agreement).
- **Downstream Tool Ecosystem**: See [`docs/phenotyping/TAXIS_COHORT_AND_CONCEPT_SET_BUILDER_ECOSYSTEM.md`](../phenotyping/TAXIS_COHORT_AND_CONCEPT_SET_BUILDER_ECOSYSTEM.md) for integration with ATLAS 3.0, Pythia, Capr, Phenelope, FastOMOP, and KEEPER.

---

## Study Leadership & Attribution

- **Stephen H. Bandeian, MD, JD** – Principal Investigator (Original SQL Engine & Taxonomy Architecture Author)
- **J. Marc Overhage, MD, PhD** – Co-Principal Investigator (Clinical Validation Lead & Adjudicator)
- **Gowtham Rao, MD, PhD** – Investigator (Phenotype Development & Evaluation Workgroup)
- **Shaun Grannis, MD, MS** – Investigator (Regenstrief Institute / Indiana University School of Medicine)
