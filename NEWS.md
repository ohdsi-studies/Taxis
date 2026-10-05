# Taxis 1.0.0

Initial official release of the TAXIS Concept AB Mining Engine study package.

### Features
* Distributed Concept AB association mining engine (Pipeline v57) executing encounter-level and population-level co-occurrence across OMOP CDM clinical domains.
* Execution across 40 random batches with memory and disk footprint management.
* Comprehensive calculation of crude and healthcare utilization-stratified lift, odds ratios, and continuity-corrected Directionality Ratios (DR).
* Strict privacy preservation via fail-closed schema validation and non-PHI small-cell suppression (< 5 masked to -1).
* Push-button network execution driver configured in `extras/CodeToRun.R`.
