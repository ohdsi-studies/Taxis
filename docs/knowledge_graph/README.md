# TAXIS Clinical Knowledge Graph & Relationship Taxonomy

This directory contains the formal ontology specifications, relational schemas, and scientific monographs defining the **TAXIS Clinical Pair Taxonomy (CPT-6)**.

---

## Document Index

### 1. [Scientific Foundations & Specification of the TAXIS Clinical Pair Taxonomy](TAXONOMY_SCIENTIFIC_FOUNDATIONS_AND_SPECIFICATION.md)
**Definitive Scientific Monograph**: Comprehensively details:
- **Scientific Provenance & Authorship**: Dr. Stephen H. Bandeian's original clinical concept-pair architecture and AHRQ/CMS episode-of-care foundation (M1–M9, 1111); Dr. J. Marc Overhage's clinical validation architecture, ClinVec benchmarks, and blinded dual-internist adjudication (Overhage & Grannis); and Dr. Gowtham Rao's neuro-symbolic proposer-validator integration and governance.
- **The Five Core Relationship Families**: Deep medical and pathophysiological characterization of Causal & Pathophysiological Mechanisms, Clinical Manifestations, Diagnostic Evaluations, Therapeutic Interventions, and Differential Diagnostic Mimics.
- **The Complete 112-Code Catalog**: Tabulated specifications for all 112 standardized codes across 32 semantic families, complete with domain constraints, expected directionality ratios, and real-world clinical exemplars.
- **Mathematical Coordination with Pipeline v57**: Directionality Ratio ($DR$) mechanics, Mantel-Haenszel Stratified Lift ($\text{Lift}_{\text{strat}}$), and empirical lag decay distributions.
- **Operational Circe Phenotyping Translation**: The 6-Bucket architecture and the 10% anchor mimic-attrition cap (`DEC-GR-008`).

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
