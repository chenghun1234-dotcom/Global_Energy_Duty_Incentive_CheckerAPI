CREATE TABLE IF NOT EXISTS tariff_rules (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  origin_country TEXT NOT NULL,
  destination_country TEXT NOT NULL,
  trade_type TEXT NOT NULL,
  asset_type TEXT NOT NULL,
  hs_code TEXT,
  base_tariff_rate REAL NOT NULL,
  additional_tax_rate REAL NOT NULL DEFAULT 0,
  vat_rate REAL NOT NULL DEFAULT 0,
  effective_from TEXT NOT NULL,
  effective_to TEXT,
  source_url TEXT NOT NULL,
  version TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_tariff_lookup
ON tariff_rules(origin_country, destination_country, trade_type, asset_type, effective_from, effective_to);

CREATE INDEX IF NOT EXISTS idx_tariff_lookup_hs
ON tariff_rules(origin_country, destination_country, trade_type, hs_code, effective_from, effective_to);

CREATE TABLE IF NOT EXISTS incentive_zones (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  country_code TEXT NOT NULL,
  zone_code TEXT NOT NULL,
  zone_name TEXT NOT NULL,
  city TEXT,
  asset_type TEXT,
  incentives_json TEXT NOT NULL,
  conditions TEXT,
  effective_from TEXT NOT NULL,
  effective_to TEXT,
  source_url TEXT NOT NULL,
  version TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_zone_lookup
ON incentive_zones(country_code, asset_type, effective_from, effective_to);

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
