####################
## combine outcome and exposures
####################

source("scriptsForStudyDesigner/CreateOutcomeCohortsCapr.R")
source("scriptsForStudyDesigner/CreateExposureCohortsCapr.R")

# combine all
cohortDefinitionSet = rbind(exposureDefinitionSet, outcomeDefinitionSet)

# save
saveCohortDefinitionSet(
  cohortDefinitionSet = cohortDefinitionSet,
  settingsFileName    = "inst/Cohorts.csv",
  jsonFolder          = "inst/cohorts",
  sqlFolder           = "inst/sql/sql_server"
)
