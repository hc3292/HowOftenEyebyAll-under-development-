IF OBJECT_ID('results.ophthalmic_ingredient_incl_injectables_enriched', 'U') IS NOT NULL
  DROP TABLE results.ophthalmic_ingredient_incl_injectables_enriched;

WITH
/* ✅ NEW: your ingredient filter list */
seed_ingredients AS (
  SELECT DISTINCT ingredient_concept_id
  FROM (VALUES
    (40244266),  -- aflibercept
    (1790868),   -- amikacin
    (1717240),   -- amphotericin B
    (1397141),   -- bevacizumab
    (37497314),  -- brolucizumab
    (1776684),   -- ceftazidime
    (997881),    -- clindamycin
    (1518254),   -- dexamethasone
    (1759013),   -- faricimab
    (996541),    -- fluocinolone
    (19048999),  -- fomivirsen
    (1757803),   -- ganciclovir
    (19063605),  -- pegaptanib
    (1537122),   -- pegcetacoplan
    (19080982),  -- ranibizumab
    (903963),    -- triamcinolone
    (1707687),   -- vancomycin
    (746414),    -- avacincaptad pegol
    (1724700),   -- foscarnet
    (1305058),   -- methotrexate
    (1714277)    -- voriconazole
  ) v(ingredient_concept_id)
),

ocular_signal_dose_form AS (
  SELECT c.concept_id, c.concept_name
  FROM concept c
  WHERE c.domain_id = 'Drug'
    AND c.concept_class_id = 'Dose Form'
    AND c.invalid_reason IS NULL
    AND (
         LOWER(c.concept_name) LIKE '%ophthalmic%'
      OR LOWER(c.concept_name) LIKE '%ocular%'
      OR LOWER(c.concept_name) LIKE '%eye%'
      OR LOWER(c.concept_name) LIKE '%inject%'

      OR LOWER(c.concept_name) LIKE '%intravitreal%'
      OR LOWER(c.concept_name) LIKE '%intravitre%'
      OR LOWER(c.concept_name) LIKE '%intraocular%'
      OR LOWER(c.concept_name) LIKE '%intra-ocular%'
      OR LOWER(c.concept_name) LIKE '%vitreous%'
      OR (LOWER(c.concept_name) LIKE '%ophthalm%' AND LOWER(c.concept_name) LIKE '%inject%')
      OR (LOWER(c.concept_name) LIKE '%ocular%' AND LOWER(c.concept_name) LIKE '%inject%')
      OR (LOWER(c.concept_name) LIKE '%eye%' AND LOWER(c.concept_name) LIKE '%inject%')
      OR (LOWER(c.concept_name) LIKE '%intravit%' AND LOWER(c.concept_name) LIKE '%implant%')
    )
),

cdf_with_signal_dose_form AS (
  SELECT DISTINCT
      itc.concept_id_1 AS clinical_drug_form_id,
      df.concept_id    AS dose_form_concept_id,
      df.concept_name  AS dose_form_name
  FROM concept_relationship itc
  JOIN ocular_signal_dose_form df
    ON df.concept_id = itc.concept_id_2
  JOIN concept cdf
    ON cdf.concept_id = itc.concept_id_1
   AND cdf.domain_id = 'Drug'
   AND cdf.concept_class_id IN ('Clinical Drug Form','Clinical Drug')
   AND cdf.invalid_reason IS NULL
  WHERE itc.relationship_id IN ('Has dose form','RxNorm has dose form')
),

rx_ingredients AS (
  SELECT
      c.concept_id   AS ingredient_concept_id,
      c.concept_name AS ingredient_name
  FROM concept c
  WHERE c.domain_id = 'Drug'
    AND c.concept_class_id = 'Ingredient'
    AND c.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
    AND c.invalid_reason IS NULL
),

rolled_to_ingredient AS (
  SELECT DISTINCT
      ca.ancestor_concept_id AS ingredient_concept_id,
      cdf.clinical_drug_form_id AS drug_concept_id,
      cdf.dose_form_concept_id,
      cdf.dose_form_name
  FROM cdf_with_signal_dose_form cdf
  JOIN concept_ancestor ca
    ON ca.descendant_concept_id = cdf.clinical_drug_form_id
  JOIN rx_ingredients ri
    ON ri.ingredient_concept_id = ca.ancestor_concept_id
)

SELECT
  ri.ingredient_concept_id,
  ri.ingredient_name,

  r.drug_concept_id,

  -- === FULL ATLAS "concept" FIELDS FOR THE DRUG CONCEPT (items[].concept) ===
  dc.concept_class_id AS CONCEPT_CLASS_ID,
  dc.concept_code     AS CONCEPT_CODE,
  dc.concept_id       AS CONCEPT_ID,
  dc.concept_name     AS CONCEPT_NAME,
  dc.domain_id        AS DOMAIN_ID,

  CASE WHEN dc.invalid_reason IS NULL THEN 'V' ELSE dc.invalid_reason END AS INVALID_REASON,
  CASE WHEN dc.invalid_reason IS NULL THEN 'Valid'
       WHEN dc.invalid_reason = 'D' THEN 'Deleted'
       WHEN dc.invalid_reason = 'U' THEN 'Updated'
       ELSE 'Invalid' END AS INVALID_REASON_CAPTION,

  dc.standard_concept AS STANDARD_CONCEPT,
  CASE WHEN dc.standard_concept = 'S' THEN 'Standard'
       WHEN dc.standard_concept = 'C' THEN 'Classification'
       ELSE NULL END AS STANDARD_CONCEPT_CAPTION,

  dc.vocabulary_id    AS VOCABULARY_ID,

  -- keep provenance (optional but nice)
  r.dose_form_concept_id,
  r.dose_form_name

INTO results.ophthalmic_ingredient_incl_injectables_enriched
FROM rolled_to_ingredient r
JOIN rx_ingredients ri
  ON ri.ingredient_concept_id = r.ingredient_concept_id
JOIN seed_ingredients s                      -- ✅ NEW: filter here by drug seed list
  ON s.ingredient_concept_id = ri.ingredient_concept_id
JOIN concept dc
  ON dc.concept_id = r.drug_concept_id
ORDER BY ri.ingredient_name, dc.concept_name, r.dose_form_name;