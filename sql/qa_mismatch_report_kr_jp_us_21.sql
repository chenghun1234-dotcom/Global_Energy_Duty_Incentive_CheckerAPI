-- Mismatch report SQL for KR/JP/US first-load dataset
-- This query returns only suspicious rows ("mismatches") for review.

WITH base AS (
  SELECT
    id,
    origin_country,
    destination_country,
    trade_type,
    asset_type,
    hs_code,
    base_tariff_rate,
    additional_tax_rate,
    vat_rate,
    effective_from,
    effective_to,
    source_url,
    version
  FROM tariff_rules
  WHERE version = 'v2026.04.28'
),
dup_key AS (
  SELECT
    origin_country,
    destination_country,
    trade_type,
    asset_type,
    hs_code,
    effective_from,
    COALESCE(effective_to, 'NULL') AS effective_to_key,
    COUNT(*) AS cnt
  FROM base
  GROUP BY
    origin_country,
    destination_country,
    trade_type,
    asset_type,
    hs_code,
    effective_from,
    COALESCE(effective_to, 'NULL')
  HAVING COUNT(*) > 1
),
row_flags AS (
  SELECT
    b.*,
    CASE WHEN d.cnt IS NOT NULL THEN 1 ELSE 0 END AS is_duplicate,
    CASE WHEN b.source_url IS NULL OR TRIM(b.source_url) = '' THEN 1 ELSE 0 END AS missing_source,
    CASE WHEN b.version IS NULL OR TRIM(b.version) = '' THEN 1 ELSE 0 END AS missing_version,
    CASE WHEN b.hs_code IS NULL OR TRIM(b.hs_code) = '' THEN 1 ELSE 0 END AS missing_hs,
    CASE WHEN b.base_tariff_rate < 0 OR b.base_tariff_rate > 1 THEN 1 ELSE 0 END AS bad_base_rate,
    CASE WHEN b.additional_tax_rate < 0 OR b.additional_tax_rate > 1 THEN 1 ELSE 0 END AS bad_additional_rate,
    CASE WHEN b.vat_rate < 0 OR b.vat_rate > 1 THEN 1 ELSE 0 END AS bad_vat_rate,
    CASE WHEN b.effective_to IS NOT NULL AND b.effective_to < b.effective_from THEN 1 ELSE 0 END AS bad_effective_window
  FROM base b
  LEFT JOIN dup_key d
    ON d.origin_country = b.origin_country
   AND d.destination_country = b.destination_country
   AND d.trade_type = b.trade_type
   AND d.asset_type = b.asset_type
   AND d.hs_code = b.hs_code
   AND d.effective_from = b.effective_from
   AND d.effective_to_key = COALESCE(b.effective_to, 'NULL')
)
SELECT
  id,
  origin_country,
  destination_country,
  trade_type,
  asset_type,
  hs_code,
  base_tariff_rate,
  additional_tax_rate,
  vat_rate,
  effective_from,
  effective_to,
  source_url,
  version,
  TRIM(
    (CASE WHEN is_duplicate = 1 THEN 'DUPLICATE;' ELSE '' END) ||
    (CASE WHEN missing_source = 1 THEN 'MISSING_SOURCE;' ELSE '' END) ||
    (CASE WHEN missing_version = 1 THEN 'MISSING_VERSION;' ELSE '' END) ||
    (CASE WHEN missing_hs = 1 THEN 'MISSING_HS;' ELSE '' END) ||
    (CASE WHEN bad_base_rate = 1 THEN 'BAD_BASE_RATE;' ELSE '' END) ||
    (CASE WHEN bad_additional_rate = 1 THEN 'BAD_ADDITIONAL_RATE;' ELSE '' END) ||
    (CASE WHEN bad_vat_rate = 1 THEN 'BAD_VAT_RATE;' ELSE '' END) ||
    (CASE WHEN bad_effective_window = 1 THEN 'BAD_EFFECTIVE_WINDOW;' ELSE '' END)
  ) AS mismatch_flags
FROM row_flags
WHERE
  is_duplicate = 1 OR
  missing_source = 1 OR
  missing_version = 1 OR
  missing_hs = 1 OR
  bad_base_rate = 1 OR
  bad_additional_rate = 1 OR
  bad_vat_rate = 1 OR
  bad_effective_window = 1
ORDER BY id;
