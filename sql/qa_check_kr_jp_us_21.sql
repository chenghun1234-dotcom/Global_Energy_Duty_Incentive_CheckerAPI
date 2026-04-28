-- QA check set for KR/JP/US first-load tariff rules (target: 21 rows)

-- 1) Total row count should be exactly 21
SELECT COUNT(*) AS total_rules
FROM tariff_rules
WHERE version = 'v2026.04.28';

-- 2) Country pair coverage count (should be 7 per country in current seed)
SELECT origin_country, COUNT(*) AS cnt
FROM tariff_rules
WHERE version = 'v2026.04.28'
GROUP BY origin_country
ORDER BY origin_country;

-- 3) Asset coverage check
SELECT asset_type, COUNT(*) AS cnt
FROM tariff_rules
WHERE version = 'v2026.04.28'
GROUP BY asset_type
ORDER BY asset_type;

-- 4) HS coverage check
SELECT hs_code, COUNT(*) AS cnt
FROM tariff_rules
WHERE version = 'v2026.04.28'
GROUP BY hs_code
ORDER BY hs_code;

-- 5) Duplicate rule detection by route + type + asset + date window
SELECT
  origin_country,
  destination_country,
  trade_type,
  asset_type,
  hs_code,
  effective_from,
  COALESCE(effective_to, 'NULL') AS effective_to,
  COUNT(*) AS dup_cnt
FROM tariff_rules
WHERE version = 'v2026.04.28'
GROUP BY
  origin_country,
  destination_country,
  trade_type,
  asset_type,
  hs_code,
  effective_from,
  COALESCE(effective_to, 'NULL')
HAVING COUNT(*) > 1
ORDER BY dup_cnt DESC;

-- 6) Rate sanity checks (0 <= rate <= 1)
SELECT
  id, origin_country, destination_country, asset_type, hs_code,
  base_tariff_rate, additional_tax_rate, vat_rate
FROM tariff_rules
WHERE version = 'v2026.04.28'
  AND (
    base_tariff_rate < 0 OR base_tariff_rate > 1 OR
    additional_tax_rate < 0 OR additional_tax_rate > 1 OR
    vat_rate < 0 OR vat_rate > 1
  )
ORDER BY id;

-- 7) Missing source or version checks
SELECT id, origin_country, destination_country, asset_type, hs_code, source_url, version
FROM tariff_rules
WHERE version = 'v2026.04.28'
  AND (source_url IS NULL OR TRIM(source_url) = '' OR version IS NULL OR TRIM(version) = '')
ORDER BY id;
