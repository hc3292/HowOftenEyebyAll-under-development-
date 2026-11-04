How Often Eye by All
=============

<img src="https://img.shields.io/badge/Study%20Status-Repo%20Created-lightgray.svg" alt="Study Status: Repo Created">

- Analytics use case(s): **Characterization, Population-Level Estimation**
- Study type: **Clinical Application**
- Tags: **ophthalmology, drug safety, incidence, SCCS, Strategus**
- Study lead: **[Name]**
- Study lead forums tag: **[[Lead tag]](https://forums.ohdsi.org/u/[Lead tag])**
- Study start date: **[YYYY-MM-DD]**
- Study end date: **-**
- Protocol: **[link or path under Documents/]**
- Publications: **-**
- Results explorer: **-**

## Description

**How Often Eye by All** is an OHDSI network study that estimates how often adverse outcomes occur after ophthalmic drug exposures in OMOP CDM data. The package is built on the [OHDSI Strategus](https://ohdsi.github.io/Strategus/) study-repo workflow: a shared analysis specification is distributed to data partners, each site runs the same pipeline locally, and only aggregate results are returned for synthesis.

The current design generates large libraries of ophthalmic exposure cohorts and outcome cohorts, then runs:

- **CohortGenerator** — materialize study cohorts
- **CohortDiagnostics** — cohort quality diagnostics
- **CohortIncidence** — incidence estimation
- **SelfControlledCaseSeries** — self-controlled case series estimation

Study calendar window in the analysis specification: **2015-01-01** to **2024-12-31**.

> Status: **under development**. Cohort libraries, negative controls, and analysis settings may still change before site launch.

## Repository layout

| Path | Role |
|------|------|
| `ExecuteAnalyses.R` | Site execution entry point (`Strategus::execute`) |
| `ShareResults.R` | Zip + upload aggregate site results |
| `inst/analysisSpecifications.json` | Strategus analysis specification |
| `inst/cohorts/`, `inst/Cohorts.csv` | Cohort definitions packaged with the study |
| `config.yml` | Study-level configuration (name, folders, results DB) |
| `scriptsForStudyDesigner/` | Capr cohort builders + specification creation |
| `scriptsForStudyCoordinator/` | Results schema, upload, evidence synthesis, Shiny app |
| `template_docs/` | Role guides (designer, site, coordinator) |
| `Documents/` | Protocol materials |
| `renv.lock` | Reproducible R package environment |

Exposure and outcome cohorts are built with Capr under `scriptsForStudyDesigner/` (ophthalmic ingredient exposures and concept-based outcome cohorts). The Strategus specification is created with `CreateStrategusAnalysisSpecifications.R` and saved to `inst/analysisSpecifications.json`.

## Prerequisites

Follow the OHDSI [HADES R setup guide](https://ohdsi.github.io/Hades/rSetup.html), then see [template_docs/prerequisites.md](template_docs/prerequisites.md).

You will need:

- R (lockfile records **4.4.1**)
- RStudio (or equivalent)
- Java (HADES / DatabaseConnector)
- Access to a local **OMOP CDM** with permission to read the CDM schema and write to a work schema

## Quick start (site participants)

1. Clone this repository and open `HowOftenEyebyAll.Rproj` in RStudio.
2. Restore the environment (one-time; restart R afterward):

```r
renv::restore()
```

3. Edit the input block in `ExecuteAnalyses.R`:

- `cdmDatabaseSchema`
- `workDatabaseSchema`
- `connectionDetails`
- `databaseName` (used as the results subfolder name)
- `minCellCount` (default `5`)
- optionally `sqlRenderTempEmulationSchema` for platforms without temp tables

4. Run `ExecuteAnalyses.R`. Results land under `results/<databaseName>/`.
5. Review aggregate outputs (no patient-level data should be shared).
6. Configure and run `ShareResults.R` using SFTP credentials from the Study Coordinator.

Full site instructions: [template_docs/site-participant-guide.md](template_docs/site-participant-guide.md).

## Sharing results

`ShareResults.R` calls `Strategus::zipResults()` on the site results folder, then uploads via `OhdsiSharing::sftpUploadFile()`. Only aggregate CSV outputs are packaged. Confirm local governance approval before upload.

## License

See [LICENSE](LICENSE).

## Acknowledgments

This repository uses the OHDSI Strategus study-repo template and HADES packages. Network study execution follows the standard OHDSI designer → site → coordinator workflow.
