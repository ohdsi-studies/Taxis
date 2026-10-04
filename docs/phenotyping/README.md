# TAXIS Phenotyping & Concept Set Engineering Documentation

This directory contains scientific architecture specifications, integration blueprints, and research documents defining how the **TAXIS empirical association mining foundation** interfaces with downstream cohort authoring and concept set engineering systems across the OHDSI community.

---

## Document Index

### 1. [TAXIS in the OHDSI Phenotype & Concept Set Engineering Ecosystem](TAXIS_COHORT_AND_CONCEPT_SET_BUILDER_ECOSYSTEM.md)
**Primary Architecture Specification**: Establishes how TAXIS serves as an agnostic empirical evidence layer for all modern cohort authoring paradigms, covering:
- **Agentic & Generative AI Systems**: OHDSI Pythia (ATLAS 3.0 AI assistant), Phenelope (LLM concept set builder), FastOMOP (multi-agent RWE framework), OHDSI KEEPER (dual-hybrid LLM case adjudication), OHDSI Study Agent, and autonomous LLM-Capr coding agents.
- **Programmatic & Classical Systems**: Capr (HADES R domain-specific language), ATLAS 3.0 (TrexSQL DuckDB query cache acceleration), PHOEBE, and Aphrodite machine learning phenotyping.
- **Interoperability Surfaces**: FastMCP (Model Context Protocol), OHDSI WebAPI/Plumber REST endpoints, and columnar Parquet/DuckDB dumps.

### 2. [TAXIS Integration with ATLAS v3.0 & Pythia](TAXIS_Atlas3_Pythia_Integration_Architecture.md)
Detailed architectural blueprint focusing specifically on ATLAS v3.0 (Single-SPA Vue 3 workbench) and the Pythia AI Cohort Design Assistant (eve-layout / ClojureScript / trex runtime), specifying tool interfaces, card proposal flows, and TrexSQL DuckDB query cache optimizations.

### 3. [Phenotype Phebruary 2026: TAXIS Integration](PHENOTYPE_PHEBRUARY_2026_TAXIS_INTEGRATION.md)
Demonstration of TAXIS capabilities applied to the 2026 OHDSI Phenotype Phebruary challenge, featuring the flagship **Acute Myocardial Infarction (AMI)** cohort definition with treatment-enriched criteria, diagnostic biomarker validation, and Poisson-based attrition diagnostics.

### 4. [Phenotype Recreation Engine Specification](Phenotype_Recreation_Engine.md)
Technical design of the 6-Bucket cohort criteria slot architecture, illustrating how downstream tools can programmatically translate TAXIS empirical graph edges into standards-compliant Circe JSON cohort definitions.

### 5. [RFC: Pythia, TAXIS & Phenotype Library Hybrid Architecture](RFC_Pythia_TAXIS_PhenotypeLibrary_Hybrid_Architecture.md)
Request for Comments outlining the neuro-symbolic hybrid architecture bridging human-authored templates from the OHDSI Phenotype Library with empirical association metrics from TAXIS.

---

## Study Leadership & Authorship

- **Stephen H. Bandeian, MD, JD** – Principal Investigator (Original SQL Engine Author)
- **J. Marc Overhage, MD, PhD** – Co-Principal Investigator
- **Gowtham Rao, MD, PhD** – Investigator
- **Shaun Grannis, MD, MS** – Investigator
