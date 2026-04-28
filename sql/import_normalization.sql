-- 1) Raw staging table (CSV header 1:1)
CREATE TABLE IF NOT EXISTS source_collection_staging (
  country TEXT,
  domain TEXT,
  category TEXT,
  source_name TEXT,
  source_url TEXT,
  collection_method TEXT,
  update_frequency TEXT,
  priority TEXT,
  status TEXT,
  last_checked_at TEXT,
  effective_from TEXT,
  effective_to TEXT,
  hs_code TEXT,
  asset_type TEXT,
  tariff_type TEXT,
  tax_type TEXT,
  incentive_type TEXT,
  zone_code TEXT,
  zone_name TEXT,
  eligibility_conditions TEXT,
  required_documents TEXT,
  currency TEXT,
  rate_value TEXT,
  rate_unit TEXT,
  source_published_at TEXT,
  fetched_at TEXT,
  version TEXT,
  reviewer TEXT,
  notes TEXT
);

-- 2) Normalized master tables
CREATE TABLE IF NOT EXISTS source_master (
  source_id INTEGER PRIMARY KEY AUTOINCREMENT,
  country TEXT NOT NULL,
  domain TEXT NOT NULL,
  category TEXT NOT NULL,
  source_name TEXT NOT NULL,
  source_url TEXT NOT NULL UNIQUE,
  collection_method TEXT,
  update_frequency TEXT,
  priority TEXT,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS collection_checklist (
  checklist_id INTEGER PRIMARY KEY AUTOINCREMENT,
  source_id INTEGER NOT NULL,
  status TEXT,
  last_checked_at TEXT,
  reviewer TEXT,
  notes TEXT,
  FOREIGN KEY (source_id) REFERENCES source_master(source_id)
);

CREATE TABLE IF NOT EXISTS source_observation (
  observation_id INTEGER PRIMARY KEY AUTOINCREMENT,
  source_id INTEGER NOT NULL,
  captured_at TEXT,
  effective_from TEXT,
  effective_to TEXT,
  hs_code TEXT,
  asset_type TEXT,
  tariff_type TEXT,
  tax_type TEXT,
  incentive_type TEXT,
  zone_code TEXT,
  zone_name TEXT,
  eligibility_conditions TEXT,
  required_documents TEXT,
  currency TEXT,
  rate_value REAL,
  rate_unit TEXT,
  source_published_at TEXT,
  fetched_at TEXT,
  version TEXT,
  UNIQUE(source_id, IFNULL(hs_code, ''), IFNULL(zone_code, ''), IFNULL(effective_from, ''), IFNULL(version, '')),
  FOREIGN KEY (source_id) REFERENCES source_master(source_id)
);

CREATE INDEX IF NOT EXISTS idx_source_master_country_category
ON source_master(country, category);

CREATE INDEX IF NOT EXISTS idx_observation_source
ON source_observation(source_id);

CREATE INDEX IF NOT EXISTS idx_observation_source_captured
ON source_observation(source_id, captured_at);

CREATE TABLE IF NOT EXISTS api_keys (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  api_key_hash TEXT NOT NULL UNIQUE,
  client_name TEXT NOT NULL,
  plan TEXT NOT NULL,
  daily_limit INTEGER NOT NULL DEFAULT 1000,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS usage_daily (
  usage_date TEXT NOT NULL,
  api_key_hash TEXT NOT NULL,
  endpoint TEXT NOT NULL,
  request_count INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (usage_date, api_key_hash, endpoint)
);

-- 3) Upsert from staging to normalized
INSERT INTO source_master (
  country, domain, category, source_name, source_url,
  collection_method, update_frequency, priority, is_active, updated_at
)
SELECT
  TRIM(country),
  TRIM(domain),
  TRIM(category),
  TRIM(source_name),
  TRIM(source_url),
  NULLIF(TRIM(collection_method), ''),
  NULLIF(TRIM(update_frequency), ''),
  NULLIF(TRIM(priority), ''),
  1,
  datetime('now')
FROM source_collection_staging
WHERE TRIM(source_url) <> ''
ON CONFLICT(source_url) DO UPDATE SET
  country = excluded.country,
  domain = excluded.domain,
  category = excluded.category,
  source_name = excluded.source_name,
  collection_method = excluded.collection_method,
  update_frequency = excluded.update_frequency,
  priority = excluded.priority,
  updated_at = datetime('now');

INSERT INTO collection_checklist (source_id, status, last_checked_at, reviewer, notes)
SELECT
  sm.source_id,
  NULLIF(TRIM(s.status), ''),
  NULLIF(TRIM(s.last_checked_at), ''),
  NULLIF(TRIM(s.reviewer), ''),
  NULLIF(TRIM(s.notes), '')
FROM source_collection_staging s
JOIN source_master sm ON sm.source_url = TRIM(s.source_url);

INSERT OR IGNORE INTO source_observation (
  source_id, effective_from, effective_to, hs_code, asset_type,
  tariff_type, tax_type, incentive_type, zone_code, zone_name,
  eligibility_conditions, required_documents, currency, rate_value,
  rate_unit, source_published_at, fetched_at, version
)
SELECT
  sm.source_id,
  NULLIF(TRIM(s.effective_from), ''),
  NULLIF(TRIM(s.effective_to), ''),
  NULLIF(TRIM(s.hs_code), ''),
  NULLIF(TRIM(s.asset_type), ''),
  NULLIF(TRIM(s.tariff_type), ''),
  NULLIF(TRIM(s.tax_type), ''),
  NULLIF(TRIM(s.incentive_type), ''),
  NULLIF(TRIM(s.zone_code), ''),
  NULLIF(TRIM(s.zone_name), ''),
  NULLIF(TRIM(s.eligibility_conditions), ''),
  NULLIF(TRIM(s.required_documents), ''),
  NULLIF(TRIM(s.currency), ''),
  CASE
    WHEN NULLIF(TRIM(s.rate_value), '') IS NULL THEN NULL
    ELSE CAST(TRIM(s.rate_value) AS REAL)
  END,
  NULLIF(TRIM(s.rate_unit), ''),
  NULLIF(TRIM(s.source_published_at), ''),
  NULLIF(TRIM(s.fetched_at), ''),
  NULLIF(TRIM(s.version), '')
FROM source_collection_staging s
JOIN source_master sm ON sm.source_url = TRIM(s.source_url);
