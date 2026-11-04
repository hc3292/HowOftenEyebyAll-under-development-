################################################################################
# INSTRUCTIONS: this script creates cohorts via Capr
################################################################################

library(Capr) # make sure this is installed 
library(CirceR)

####################
## COHORT LIST
# in later iterations -> be able to read in CSV of a list of cohortId, conceptId, and name
####################

# outcome concepts
concepts = read.csv("scriptsForStudyDesigner/settings/UniqueOutcomeConcepts.csv") # this has all the concepst from EMA, FDA, phecodes
concepts$cohortId = seq(1:nrow(concepts)) + 10000 # start at 10000 so it doesn't interfere with the drugs
colnames(concepts)

## OLD
# OMOP concept IDs (standard concepts, which for conditions are SNOMED) and labels
# concepts <- data.frame(
#   cohortId  = 1:9,
#   conceptId = c(377556L, 141651L, 432791L, 437894L, 40481633L,
#                 4322024L, 4013643L, 441202L, 4026032L),
#   name      = c("Sudden visual loss",
#                 "Stevens-Johnson syndrome",
#                 "Angioedema",
#                 "Ventricular fibrillation",
#                 "Azotaemia",
#                 "Pulmonary hypertension",
#                 "Pulmonary arterial hypertension",
#                 "Anaphylactic reaction",
#                 "Acute hepatic failure"),
#   stringsAsFactors = FALSE
# )


# this is from Capr
makeCohort <- function(conceptId, name) {
  conceptSet <- cs(descendants(conceptId), name = name)
  
  cohort(
    entry = entry(
      conditionOccurrence(conceptSet),
      observation(conceptSet),
      observationWindow = continuousObservation(0L, 0L),
      primaryCriteriaLimit = "All",
      qualifiedLimit = "All"
    ),
    exit = exit(
      endStrategy = fixedExit(index = "startDate", offsetDays = 1L)
    ),
    era = era(eraDays = 30L)
  )
}

cohortList <- Map(makeCohort, concepts$conceptId, concepts$conceptName) |> unname()

####################
## generate json and sql
####################

jsonList <- vapply(cohortList, function(x) as.character(as.json(x)), character(1))

sqlList <- vapply(jsonList, function(j) {
  expr <- cohortExpressionFromJson(j)
  buildCohortQuery(expr, createGenerateOptions(generateStats = TRUE))
}, character(1)) |> unname()

outcomeDefinitionSet <- data.frame(
  cohortId   = as.integer(concepts$cohortId),
  cohortName = concepts$conceptName,
  json       = jsonList,
  sql        = sqlList,
  stringsAsFactors = FALSE
)

# save jsons and sqls
# saveCohortDefinitionSet(
#   cohortDefinitionSet = outcomeDefinitionSet,
#   settingsFileName    = "inst/outcomes/OutcomeCohorts.csv",
#   jsonFolder          = "inst/outcomes/cohorts",
#   sqlFolder           = "inst/outcomes/sql/sql_server"
# )

