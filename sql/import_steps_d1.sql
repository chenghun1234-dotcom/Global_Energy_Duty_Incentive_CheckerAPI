-- D1 import guide (run in order)
-- 0) Create normalized tables + staging table
-- wrangler d1 execute energy-duty-db --local --file=sql/import_normalization.sql

-- 1) Load CSV to staging (SQLite shell style; useful for local sqlite)
-- .mode csv
-- .headers on
-- .import data/source_collection_checklist_kr_jp_us_sg_ae.csv source_collection_staging

-- 2) For D1 CLI, if you cannot use .import directly:
--    - convert CSV to INSERT statements once, then execute them
--    - keep this file as orchestration reference

-- 3) Normalize/upsert (already included at bottom of import_normalization.sql)

-- 4) Verify
SELECT country, category, COUNT(*) AS cnt
FROM source_master
GROUP BY country, category
ORDER BY country, category;

SELECT sm.country, sm.source_name, so.hs_code, so.zone_code, so.version
FROM source_observation so
JOIN source_master sm ON sm.source_id = so.source_id
ORDER BY sm.country, sm.source_name;
