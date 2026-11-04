-- Combines:
--   results.ophthalmic_final_cdf_enriched_dfg                (eye drugs, dose form group filter)
--   results.ophthalmic_ingredient_incl_injectables_enriched  (handpicked injectables)
-- Run both of those scripts first.

IF OBJECT_ID('results.ophthalmic_combined_enriched', 'U') IS NOT NULL
  DROP TABLE results.ophthalmic_combined_enriched;

SELECT *
INTO results.ophthalmic_combined_enriched
FROM (

  /* A) Eye drugs (non-systemic, non-injectable) */
  SELECT
    e.ingredient_concept_id,
    e.ingredient_name,
    e.drug_concept_id,
    e.CONCEPT_CLASS_ID,
    e.CONCEPT_CODE,
    e.CONCEPT_ID,
    e.CONCEPT_NAME,
    e.DOMAIN_ID,
    e.INVALID_REASON,
    e.INVALID_REASON_CAPTION,
    e.STANDARD_CONCEPT,
    e.STANDARD_CONCEPT_CAPTION,
    e.VOCABULARY_ID,
    e.dose_form_concept_id,
    e.dose_form_name,
    e.dose_form_group_concept_id,
    e.dose_form_group_name,
    CAST('eye_dose_form_group' AS VARCHAR(30)) AS source_list
  FROM results.ophthalmic_final_cdf_enriched_dfg e

  UNION ALL

  /* B) Handpicked injectables, skipping rows already present in A
        (same ingredient + drug + dose form) */
  SELECT
    i.ingredient_concept_id,
    i.ingredient_name,
    i.drug_concept_id,
    i.CONCEPT_CLASS_ID,
    i.CONCEPT_CODE,
    i.CONCEPT_ID,
    i.CONCEPT_NAME,
    i.DOMAIN_ID,
    i.INVALID_REASON,
    i.INVALID_REASON_CAPTION,
    i.STANDARD_CONCEPT,
    i.STANDARD_CONCEPT_CAPTION,
    i.VOCABULARY_ID,
    i.dose_form_concept_id,
    i.dose_form_name,
    CAST(NULL AS INT)          AS dose_form_group_concept_id,   -- not in injectables table
    CAST(NULL AS VARCHAR(255)) AS dose_form_group_name,
    CAST('handpicked_injectable' AS VARCHAR(30)) AS source_list
  FROM results.ophthalmic_ingredient_incl_injectables_enriched i
  WHERE NOT EXISTS (
    SELECT 1
    FROM results.ophthalmic_final_cdf_enriched_dfg e
    WHERE e.ingredient_concept_id = i.ingredient_concept_id
      AND e.drug_concept_id       = i.drug_concept_id
      AND ISNULL(e.dose_form_concept_id, -1) = ISNULL(i.dose_form_concept_id, -1)
  )

) u;

-- Indexes
CREATE INDEX IX_oph_comb_drug_id
  ON results.ophthalmic_combined_enriched(drug_concept_id);

CREATE INDEX IX_oph_comb_ingredient_id
  ON results.ophthalmic_combined_enriched(ingredient_concept_id);

CREATE INDEX IX_oph_comb_dose_form_id
  ON results.ophthalmic_combined_enriched(dose_form_concept_id);

-- ---------------------------------------------------------------
-- Diagnostics
-- ---------------------------------------------------------------

-- Rows per source
-- SELECT source_list, COUNT(*) AS n_rows, COUNT(DISTINCT drug_concept_id) AS n_drugs,
--        COUNT(DISTINCT ingredient_concept_id) AS n_ingredients
-- FROM results.ophthalmic_combined_enriched
-- GROUP BY source_list;

-- Drugs present in BOTH sources (overlap worth reviewing)
-- SELECT DISTINCT a.drug_concept_id, a.CONCEPT_NAME
-- FROM results.ophthalmic_final_cdf_enriched_dfg a
-- JOIN results.ophthalmic_ingredient_incl_injectables_enriched b
--   ON b.drug_concept_id = a.drug_concept_id;

-- Display
-- SELECT * FROM results.ophthalmic_combined_enriched
-- ORDER BY ingredient_name, CONCEPT_NAME, dose_form_name;