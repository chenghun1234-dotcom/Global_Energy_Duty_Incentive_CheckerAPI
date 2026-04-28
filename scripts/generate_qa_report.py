import argparse
import datetime as dt
import json
import os
import subprocess
import sys
from typing import Any, Dict, List


def run_sql(db: str, sql: str, remote: bool) -> List[Dict[str, Any]]:
  cmd = ["npx", "wrangler", "d1", "execute", db, "--json", "--command", sql]
  cmd.append("--remote" if remote else "--local")
  p = subprocess.run(cmd, capture_output=True, text=True)
  if p.returncode != 0:
    raise RuntimeError(f"SQL failed:\n{sql}\n\nstdout:\n{p.stdout}\n\nstderr:\n{p.stderr}")

  try:
    payload = json.loads(p.stdout)
  except json.JSONDecodeError:
    raise RuntimeError(f"Failed to parse JSON output:\n{p.stdout}")

  if isinstance(payload, list) and len(payload) > 0:
    first = payload[0]
    if isinstance(first, dict) and "results" in first and isinstance(first["results"], list):
      return first["results"]
  return []


def get_one_int(rows: List[Dict[str, Any]], key: str) -> int:
  if not rows:
    return 0
  return int(rows[0].get(key, 0))


def main():
  parser = argparse.ArgumentParser()
  parser.add_argument("--db", default="energy-duty-db")
  parser.add_argument("--remote", action="store_true")
  parser.add_argument("--version", default="v2026.04.28")
  args = parser.parse_args()

  today = dt.date.today().isoformat()
  now_utc = dt.datetime.utcnow().replace(microsecond=0).isoformat() + "Z"
  os.makedirs("qa_reports", exist_ok=True)
  report_path = f"qa_reports/{today}_kr_jp_us_21.md"

  version = args.version.replace("'", "''")

  total_rows = run_sql(
    args.db,
    f"SELECT COUNT(*) AS total_rules FROM tariff_rules WHERE version = '{version}';",
    args.remote,
  )
  total_rules = get_one_int(total_rows, "total_rules")

  by_origin = run_sql(
    args.db,
    f"""
SELECT origin_country, COUNT(*) AS cnt
FROM tariff_rules
WHERE version = '{version}'
GROUP BY origin_country
ORDER BY origin_country;
""".strip(),
    args.remote,
  )

  by_asset = run_sql(
    args.db,
    f"""
SELECT asset_type, COUNT(*) AS cnt
FROM tariff_rules
WHERE version = '{version}'
GROUP BY asset_type
ORDER BY asset_type;
""".strip(),
    args.remote,
  )

  by_hs = run_sql(
    args.db,
    f"""
SELECT hs_code, COUNT(*) AS cnt
FROM tariff_rules
WHERE version = '{version}'
GROUP BY hs_code
ORDER BY hs_code;
""".strip(),
    args.remote,
  )

  duplicate_rows = run_sql(
    args.db,
    f"""
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
WHERE version = '{version}'
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
""".strip(),
    args.remote,
  )

  bad_rate_rows = run_sql(
    args.db,
    f"""
SELECT COUNT(*) AS bad_rate_cnt
FROM tariff_rules
WHERE version = '{version}'
  AND (
    base_tariff_rate < 0 OR base_tariff_rate > 1 OR
    additional_tax_rate < 0 OR additional_tax_rate > 1 OR
    vat_rate < 0 OR vat_rate > 1
  );
""".strip(),
    args.remote,
  )
  bad_rate_cnt = get_one_int(bad_rate_rows, "bad_rate_cnt")

  missing_meta_rows = run_sql(
    args.db,
    f"""
SELECT COUNT(*) AS missing_meta_cnt
FROM tariff_rules
WHERE version = '{version}'
  AND (source_url IS NULL OR TRIM(source_url) = '' OR version IS NULL OR TRIM(version) = '');
""".strip(),
    args.remote,
  )
  missing_meta_cnt = get_one_int(missing_meta_rows, "missing_meta_cnt")

  is_pass = (
    total_rules == 21
    and len(by_origin) == 3
    and all(int(r.get("cnt", 0)) == 7 for r in by_origin)
    and len(duplicate_rows) == 0
    and bad_rate_cnt == 0
    and missing_meta_cnt == 0
  )

  lines = []
  lines.append(f"# QA Report - KR/JP/US 21 ({today})")
  lines.append("")
  lines.append(f"- Generated at (UTC): `{now_utc}`")
  lines.append(f"- DB: `{args.db}`")
  lines.append(f"- Mode: `{'remote' if args.remote else 'local'}`")
  lines.append(f"- Version: `{args.version}`")
  lines.append(f"- Result: `{'PASS' if is_pass else 'FAIL'}`")
  lines.append("")
  lines.append("## Summary Checks")
  lines.append("")
  lines.append(f"- Total rules: `{total_rules}` (expected `21`)")
  lines.append(f"- Duplicate key rows: `{len(duplicate_rows)}` (expected `0`)")
  lines.append(f"- Bad rate rows: `{bad_rate_cnt}` (expected `0`)")
  lines.append(f"- Missing source/version rows: `{missing_meta_cnt}` (expected `0`)")
  lines.append("")
  lines.append("## Coverage by Origin")
  lines.append("")
  for r in by_origin:
    lines.append(f"- {r.get('origin_country')}: `{r.get('cnt')}`")
  lines.append("")
  lines.append("## Coverage by Asset")
  lines.append("")
  for r in by_asset:
    lines.append(f"- {r.get('asset_type')}: `{r.get('cnt')}`")
  lines.append("")
  lines.append("## Coverage by HS")
  lines.append("")
  for r in by_hs:
    lines.append(f"- {r.get('hs_code')}: `{r.get('cnt')}`")

  if duplicate_rows:
    lines.append("")
    lines.append("## Duplicate Details")
    lines.append("")
    for r in duplicate_rows:
      lines.append(
        "- "
        + f"{r.get('origin_country')}->{r.get('destination_country')} "
        + f"{r.get('trade_type')} {r.get('asset_type')} hs:{r.get('hs_code')} "
        + f"from:{r.get('effective_from')} to:{r.get('effective_to')} dup:{r.get('dup_cnt')}"
      )

  with open(report_path, "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(lines) + "\n")

  print(f"QA report generated: {report_path}")
  if not is_pass:
    sys.exit(2)


if __name__ == "__main__":
  main()
