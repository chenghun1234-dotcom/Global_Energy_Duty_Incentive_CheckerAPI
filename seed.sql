DELETE FROM tariff_rules;
DELETE FROM incentive_zones;
DELETE FROM api_keys;
DELETE FROM usage_daily;

INSERT INTO tariff_rules (
  origin_country, destination_country, trade_type, asset_type, hs_code,
  base_tariff_rate, additional_tax_rate, vat_rate,
  effective_from, effective_to, source_url, version
) VALUES
  ('KR', 'JP', 'export', 'diesel', '271019', 0.03, 0.00, 0.10, '2026-01-01', NULL, 'https://www.customs.go.jp/english/tariff/index.htm', 'v2026.04.28'),
  ('KR', 'JP', 'export', 'lng', '271111', 0.02, 0.00, 0.10, '2026-01-01', NULL, 'https://www.customs.go.jp/english/tariff/index.htm', 'v2026.04.28'),
  ('KR', 'JP', 'export', 'crude_oil', '270900', 0.00, 0.00, 0.10, '2026-01-01', NULL, 'https://www.customs.go.jp/english/tariff/index.htm', 'v2026.04.28'),
  ('KR', 'US', 'export', 'diesel', '271019', 0.05, 0.00, 0.00, '2026-01-01', NULL, 'https://www.usitc.gov/harmonized_tariff_information', 'v2026.04.28'),
  ('KR', 'US', 'export', 'lng', '271111', 0.00, 0.00, 0.00, '2026-01-01', NULL, 'https://www.usitc.gov/harmonized_tariff_information', 'v2026.04.28'),
  ('KR', 'US', 'export', 'crude_oil', '270900', 0.00, 0.00, 0.00, '2026-01-01', NULL, 'https://www.usitc.gov/harmonized_tariff_information', 'v2026.04.28'),
  ('JP', 'KR', 'export', 'diesel', '271019', 0.03, 0.00, 0.10, '2026-01-01', NULL, 'https://customs.go.kr/ftaportalkor/ad/ftaCnvn/AllTariffRate.do', 'v2026.04.28'),
  ('JP', 'KR', 'export', 'lng', '271111', 0.00, 0.00, 0.10, '2026-01-01', NULL, 'https://customs.go.kr/ftaportalkor/ad/ftaCnvn/AllTariffRate.do', 'v2026.04.28'),
  ('JP', 'KR', 'export', 'crude_oil', '270900', 0.00, 0.00, 0.10, '2026-01-01', NULL, 'https://customs.go.kr/ftaportalkor/ad/ftaCnvn/AllTariffRate.do', 'v2026.04.28'),
  ('JP', 'US', 'export', 'diesel', '271019', 0.05, 0.00, 0.00, '2026-01-01', NULL, 'https://www.usitc.gov/harmonized_tariff_information', 'v2026.04.28'),
  ('JP', 'US', 'export', 'lng', '271111', 0.00, 0.00, 0.00, '2026-01-01', NULL, 'https://www.usitc.gov/harmonized_tariff_information', 'v2026.04.28'),
  ('JP', 'US', 'export', 'crude_oil', '270900', 0.00, 0.00, 0.00, '2026-01-01', NULL, 'https://www.usitc.gov/harmonized_tariff_information', 'v2026.04.28'),
  ('US', 'KR', 'export', 'diesel', '271019', 0.03, 0.00, 0.10, '2026-01-01', NULL, 'https://customs.go.kr/ftaportalkor/ad/ftaCnvn/AllTariffRate.do', 'v2026.04.28'),
  ('US', 'KR', 'export', 'lng', '271111', 0.00, 0.00, 0.10, '2026-01-01', NULL, 'https://customs.go.kr/ftaportalkor/ad/ftaCnvn/AllTariffRate.do', 'v2026.04.28'),
  ('US', 'KR', 'export', 'crude_oil', '270900', 0.00, 0.00, 0.10, '2026-01-01', NULL, 'https://customs.go.kr/ftaportalkor/ad/ftaCnvn/AllTariffRate.do', 'v2026.04.28'),
  ('US', 'JP', 'export', 'diesel', '271019', 0.03, 0.00, 0.10, '2026-01-01', NULL, 'https://www.customs.go.jp/english/tariff/index.htm', 'v2026.04.28'),
  ('US', 'JP', 'export', 'lng', '271111', 0.02, 0.00, 0.10, '2026-01-01', NULL, 'https://www.customs.go.jp/english/tariff/index.htm', 'v2026.04.28'),
  ('US', 'JP', 'export', 'crude_oil', '270900', 0.00, 0.00, 0.10, '2026-01-01', NULL, 'https://www.customs.go.jp/english/tariff/index.htm', 'v2026.04.28'),
  ('KR', 'KR', 'import', 'diesel', '271019', 0.03, 0.00, 0.10, '2026-01-01', NULL, 'https://customs.go.kr/ftaportalkor/ad/ftaCnvn/AllTariffRate.do', 'v2026.04.28'),
  ('KR', 'KR', 'import', 'lng', '271111', 0.00, 0.00, 0.10, '2026-01-01', NULL, 'https://customs.go.kr/ftaportalkor/ad/ftaCnvn/AllTariffRate.do', 'v2026.04.28'),
  ('KR', 'KR', 'import', 'crude_oil', '270900', 0.00, 0.00, 0.10, '2026-01-01', NULL, 'https://customs.go.kr/ftaportalkor/ad/ftaCnvn/AllTariffRate.do', 'v2026.04.28');

INSERT INTO incentive_zones (
  country_code, zone_code, zone_name, city, asset_type, incentives_json,
  conditions, effective_from, effective_to, source_url, version
) VALUES
  ('AE', 'AE-DMCC', 'DMCC Free Zone', 'Dubai', 'energy',
   '["corporate_tax_reduction","import_duty_exemption"]',
   'licensed entities only', '2025-01-01', NULL, 'https://example.gov/freezone/dmcc', 'v2026.04.20'),
  ('SG', 'SG-JURONG', 'Jurong Energy Hub', 'Singapore', 'energy',
   '["duty_relief","fast_customs_clearance"]',
   'approved energy operators only', '2025-06-01', NULL, 'https://example.gov/freezone/jurong', 'v2026.04.20');

INSERT INTO api_keys (api_key_hash, client_name, plan, daily_limit, is_active)
VALUES
  ('f28dd4e2d4fb7ae946cff14ede2047cd08974df5533670855fb5e2f54bd4a26f', 'demo-client', 'free', 1000, 1);
