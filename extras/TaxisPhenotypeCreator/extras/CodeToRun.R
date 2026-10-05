# ==============================================================================
# TAXIS Phenotype Creator: Automated Phenotype Synthesizer Demonstration
# ==============================================================================
#
# Package: TaxisPhenotypeCreator
# Role: Translates structured clinical descriptions and TAXIS KG association edges
#       into standards-compliant OHDSI Circe JSON cohort definitions and SQL.
#
# Study Leadership:
#   • Stephen H. Bandeian, MD, JD - Principal Investigator, Johns Hopkins University
#   • J. Marc Overhage, MD, PhD - Co-Principal Investigator, The Overhage Group / Indiana Univ
#   • Gowtham Rao, MD, PhD - Investigator, CoReason, Inc. / OHDSI
#   • Shaun Grannis, MD, MS - Investigator, Regenstrief Institute / Indiana Univ
# ==============================================================================

# Install TaxisPhenotypeCreator:
# devtools::install_local("extras/TaxisPhenotypeCreator")
# remotes::install_github("ohdsi-studies/Taxis", subdir = "extras/TaxisPhenotypeCreator")

library(TaxisPhenotypeCreator)

# --- Example 1: Synthesize all 5 TAXIS Benchmark Phenotypes ------------------
message("--> Synthesizing 5 TAXIS Benchmark Phenotypes...")
benchmarks <- TaxisPhenotypeCreator::buildBenchmarkPhenotypes()

outputFolder <- file.path(getwd(), "synthesized_circe_cohorts")
dir.create(outputFolder, showWarnings = FALSE, recursive = TRUE)

for (pName in names(benchmarks)) {
  filePath <- file.path(outputFolder, sprintf("%s_recreated_circe.json", tolower(pName)))
  TaxisPhenotypeCreator::exportCirceJson(benchmarks[[pName]], filePath)
  message(sprintf("  [CREATED] %s -> %s", pName, filePath))
}

# --- Example 2: Programmatically Define a Custom Phenotype --------------------
message("\n--> Defining custom Hyperkalemia phenotype with confirmatory lab...")
customHyperkalemia <- TaxisPhenotypeCreator::createPhenotype(
  name = "Custom Hyperkalemia Phenotype",
  primaryConcepts = list(
    list(conceptId = 434610, conceptName = "Hyperkalemia", domainId = "Condition")
  ),
  confirmatoryLabs = list(
    concepts = list(
      list(conceptId = 3023103, conceptName = "Potassium in Serum or Plasma", domainId = "Measurement")
    ),
    valueAsNumber = list(Op = "gt", Value = 5.0)
  ),
  indicatedDrugs = list(
    list(conceptId = 1353766, conceptName = "Sodium polystyrene sulfonate", domainId = "Drug")
  ),
  priorObservationDays = 365,
  outputFolder = outputFolder
)

message("Synthesized Circe JSON successfully written to: ", outputFolder)
message("Generated definitions can be imported into OHDSI ATLAS or evaluated via TaxisPhenotypeEvaluation.")
