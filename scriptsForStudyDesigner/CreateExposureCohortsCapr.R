library(Capr)
library(dplyr)
library(CohortGenerator)

# ---- Inputs ----
# Export from the ENRICHED SQL query (must include the ATLAS concept fields)
infile  <- "scriptsForStudyDesigner/settings/ophthalmic_final_cdf_enriched_dfg.csv" 
out_dir <- "scriptsForStudyDesigner/settings/atlas_concept_sets"

# 1. Read the sheet
drugs <- read.csv(infile) |>
  transmute(
    ingredientConceptId = as.integer(ingredient_concept_id),
    ingredientName      = ingredient_name,
    drugConceptId       = as.integer(drug_concept_id)
  ) |>
  distinct()

# 2. One row per ingredient, with a vector of its drug concept IDs
ingredients <- drugs |>
  group_by(ingredientConceptId, ingredientName) |>
  summarise(drugConceptIds = list(unique(drugConceptId)), .groups = "drop") |>
  mutate(cohortId = row_number())

# 3. Cohort builder: concept set = all listed formulations + descendants
makeDrugCohort <- function(conceptIds, name) {
  conceptSet <- cs(descendants(conceptIds), name = name)
  
  cohort(
    entry = entry(
      drugExposure(conceptSet, firstOccurrence()),
      observationWindow = continuousObservation(priorDays = 365L, postDays = 0L),
      primaryCriteriaLimit = "First"
    ),
    exit = exit(
      endStrategy = drugExit(
        conceptSet,
        persistenceWindow  = 30L,
        surveillanceWindow = 0L
      )
    ),
    era = era(eraDays = 0L)
  )
}

# 4. Build a named list of cohorts
cohorts <- Map(makeDrugCohort,
               conceptIds = ingredients$drugConceptIds,
               name       = ingredients$ingredientName)
names(cohorts) <- ingredients$ingredientName

# 5. (Optional) Convert to a CohortGenerator-style cohort definition set
exposureDefinitionSet <- data.frame(
  cohortId   = ingredients$cohortId + 2000, # so as to not conflict with neg controls
  cohortName = ingredients$ingredientName,
  json       = vapply(cohorts, function(x) as.json(x), character(1)),
  stringsAsFactors = FALSE
)
exposureDefinitionSet$sql <- vapply(
  exposureDefinitionSet$json,
  function(j) CirceR::buildCohortQuery(
    CirceR::cohortExpressionFromJson(j),
    CirceR::createGenerateOptions(generateStats = FALSE)
  ),
  character(1)
)

# clean up names from vapply() so the data frame is plain
rownames(exposureDefinitionSet) <- NULL

# saveCohortDefinitionSet(
#   cohortDefinitionSet = cohortDefinitionSet,
#   settingsFileName    = "inst/exposures/ExposureCohorts.csv",
#   jsonFolder          = "inst/exposures/cohorts",
#   sqlFolder           = "inst/exposures/sql/sql_server"
# )
