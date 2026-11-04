-- Drop table if it already exists
IF OBJECT_ID('results.ophthalmic_final_cdf_enriched_dfg', 'U') IS NOT NULL
  DROP TABLE results.ophthalmic_final_cdf_enriched_dfg;

WITH
/* 1) Dose Form Groups that signal EYE products.
      Run the diagnostic query at the bottom first to confirm the names in your vocabulary. */
eye_dose_form_group AS (
  SELECT c.concept_id, c.concept_name
  FROM CONCEPT c
  WHERE c.concept_class_id = 'Dose Form Group'
    AND c.invalid_reason IS NULL
    AND (
         LOWER(c.concept_name) LIKE '%ophthalm%'
      OR LOWER(c.concept_name) LIKE '%ocular%'
      OR LOWER(c.concept_name) LIKE '%eye%'
    )
),

/* 2) Dose Forms that belong to an eye Dose Form Group */
eye_dose_form AS (
  SELECT DISTINCT
    df.concept_id    AS dose_form_concept_id,
    df.concept_name  AS dose_form_name,
    g.concept_id     AS dose_form_group_concept_id,
    g.concept_name   AS dose_form_group_name
  FROM eye_dose_form_group g
  JOIN CONCEPT_RELATIONSHIP cr
    ON cr.concept_id_2 = g.concept_id
   AND cr.relationship_id IN ('RxNorm is a','Is a','Has dose form group')   -- dose form -> group
  JOIN CONCEPT df
    ON df.concept_id = cr.concept_id_1
   AND df.concept_class_id = 'Dose Form'
   AND df.invalid_reason IS NULL
),

/* 3) Dose Forms that belong to an INJECTABLE group (to exclude injectables) */
injectable_dose_form AS (
  SELECT DISTINCT cr.concept_id_1 AS dose_form_concept_id
  FROM CONCEPT g
  JOIN CONCEPT_RELATIONSHIP cr
    ON cr.concept_id_2 = g.concept_id
   AND cr.relationship_id IN ('RxNorm is a','Is a','Has dose form group')
  WHERE g.concept_class_id = 'Dose Form Group'
    AND g.invalid_reason IS NULL
    AND LOWER(g.concept_name) LIKE '%inject%'
),

/* 4) Standard RxNorm / RxNorm Extension ingredients (ALL of them; no ATC, no seed list) */
rx_ingredients AS (
  SELECT
    c.concept_id   AS ingredient_concept_id,
    c.concept_name AS ingredient_name
  FROM CONCEPT c
  WHERE c.domain_id = 'Drug'
    AND c.vocabulary_id IN ('RxNorm','RxNorm Extension')
    AND c.concept_class_id = 'Ingredient'
    AND c.standard_concept = 'S'
    AND c.invalid_reason IS NULL
),

/* 5) Clinical Drug Forms with an eye dose form (and not an injectable one) */
eye_cdf AS (
  SELECT DISTINCT
    cdf.concept_id AS clinical_drug_form_id,
    edf.dose_form_concept_id,
    edf.dose_form_name,
    edf.dose_form_group_concept_id,
    edf.dose_form_group_name
  FROM eye_dose_form edf
  JOIN CONCEPT_RELATIONSHIP cr
    ON cr.concept_id_2 = edf.dose_form_concept_id
   AND cr.relationship_id IN ('Has dose form','RxNorm has dose form')      -- CDF -> dose form
  JOIN CONCEPT cdf
    ON cdf.concept_id = cr.concept_id_1
   AND cdf.vocabulary_id IN ('RxNorm','RxNorm Extension')
   AND cdf.concept_class_id IN ('Clinical Drug Form', 'Clinical Drug')
   AND cdf.standard_concept = 'S'
   AND cdf.invalid_reason IS NULL
  WHERE NOT EXISTS (
    SELECT 1
    FROM injectable_dose_form inj
    WHERE inj.dose_form_concept_id = edf.dose_form_concept_id
  )
    AND LOWER(edf.dose_form_name) NOT LIKE '%inject%'
    AND LOWER(edf.dose_form_name) NOT LIKE '%intravit%'
),

/* 6) Roll each eye CDF up to its ingredient(s).
      NOTE: a CDF with several ingredients produces several rows. */
final_cdf AS (
  SELECT
    i.ingredient_concept_id,
    i.ingredient_name,
    e.clinical_drug_form_id AS drug_concept_id,
    c.concept_class_id,
    c.concept_code,
    c.concept_name,
    c.domain_id,
    c.invalid_reason,
    c.standard_concept,
    c.vocabulary_id,
    e.dose_form_concept_id,
    e.dose_form_name,
    e.dose_form_group_concept_id,
    e.dose_form_group_name
  FROM eye_cdf e
  JOIN CONCEPT_ANCESTOR ca
    ON ca.descendant_concept_id = e.clinical_drug_form_id
  JOIN rx_ingredients i
    ON i.ingredient_concept_id = ca.ancestor_concept_id
  JOIN CONCEPT c
    ON c.concept_id = e.clinical_drug_form_id
)

SELECT
  ingredient_concept_id,
  ingredient_name,

  drug_concept_id,

  -- === FULL ATLAS "concept" FIELDS FOR THE DRUG CONCEPT (items[].concept) ===
  concept_class_id AS CONCEPT_CLASS_ID,
  concept_code     AS CONCEPT_CODE,
  drug_concept_id  AS CONCEPT_ID,
  concept_name     AS CONCEPT_NAME,
  domain_id        AS DOMAIN_ID,

  CASE WHEN invalid_reason IS NULL THEN 'V' ELSE invalid_reason END AS INVALID_REASON,
  CASE WHEN invalid_reason IS NULL THEN 'Valid'
       WHEN invalid_reason = 'D' THEN 'Deleted'
       WHEN invalid_reason = 'U' THEN 'Updated'
       ELSE 'Invalid' END AS INVALID_REASON_CAPTION,

  standard_concept AS STANDARD_CONCEPT,
  CASE WHEN standard_concept = 'S' THEN 'Standard'
       WHEN standard_concept = 'C' THEN 'Classification'
       ELSE NULL END AS STANDARD_CONCEPT_CAPTION,

  vocabulary_id    AS VOCABULARY_ID,

  -- provenance
  dose_form_concept_id,
  dose_form_name,
  dose_form_group_concept_id,
  dose_form_group_name
INTO results.ophthalmic_final_cdf_enriched_dfg
FROM final_cdf;

-- Indexes
CREATE INDEX IX_oph_cdf_dfg_concept_id
  ON results.ophthalmic_final_cdf_enriched_dfg(drug_concept_id);

CREATE INDEX IX_oph_cdf_dfg_ingredient_id
  ON results.ophthalmic_final_cdf_enriched_dfg(ingredient_concept_id);

CREATE INDEX IX_oph_cdf_dfg_dose_form_id
  ON results.ophthalmic_final_cdf_enriched_dfg(dose_form_concept_id);

-- ---------------------------------------------------------------
-- Diagnostics (run these first / after)
-- ---------------------------------------------------------------

-- A) What Dose Form Groups exist in your vocabulary, and how many dose forms does each hold?
-- SELECT g.concept_id, g.concept_name, COUNT(DISTINCT cr.concept_id_1) AS n_dose_forms
-- FROM CONCEPT g
-- LEFT JOIN CONCEPT_RELATIONSHIP cr
--   ON cr.concept_id_2 = g.concept_id
--  AND cr.relationship_id IN ('RxNorm is a','Is a','Has dose form group')
-- WHERE g.concept_class_id = 'Dose Form Group' AND g.invalid_reason IS NULL
-- GROUP BY g.concept_id, g.concept_name
-- ORDER BY g.concept_name;

-- B) Is 4-coumaric acid in the result?
-- SELECT * FROM results.ophthalmic_final_cdf_enriched_dfg
-- WHERE LOWER(ingredient_name) LIKE '%coumaric%';

-- C) Overview by ingredient
-- SELECT DISTINCT ingredient_name FROM results.ophthalmic_final_cdf_enriched_dfg ORDER BY ingredient_name;