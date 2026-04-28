import csv
import os

SNAPSHOT_CSV = "data/source_snapshots.csv"
OUTPUT_SQL = "sql/snapshots_upsert.sql"


def q(value: str) -> str:
  if value is None:
    return "NULL"
  v = value.strip()
  if v == "":
    return "NULL"
  return "'" + v.replace("'", "''") + "'"


def main():
  if not os.path.exists(SNAPSHOT_CSV):
    raise FileNotFoundError(f"{SNAPSHOT_CSV} not found")

  with open(SNAPSHOT_CSV, "r", encoding="utf-8-sig", newline="") as f:
    rows = list(csv.DictReader(f))

  lines = ["BEGIN TRANSACTION;"]
  for r in rows:
    source_url = (r.get("source_url") or "").strip()
    if not source_url:
      continue

    status_code = (r.get("status_code") or "").strip()
    content_hash = (r.get("content_hash_sha256") or "").strip()
    captured_at = q(r.get("captured_at_utc"))
    source_published_at = q(r.get("last_modified_header"))
    fetched_at = captured_at
    version = q(content_hash) if content_hash else "NULL"
    notes = q(
      "crawl_status="
      + (r.get("status_code") or "")
      + "; title="
      + (r.get("title") or "")
      + "; etag="
      + (r.get("etag") or "")
      + "; hash="
      + (r.get("content_hash_sha256") or "")
      + "; error="
      + (r.get("error_message") or "")
    )

    # Optimization rule:
    # 1) Only load source_observation when crawl succeeded (HTTP 200)
    # 2) Use content hash as version key, so unchanged content is deduplicated
    if status_code == "200" and content_hash:
      lines.append(
        f"""
INSERT OR IGNORE INTO source_observation (
  source_id, captured_at, source_published_at, fetched_at, version
)
SELECT source_id, {captured_at}, {source_published_at}, {fetched_at}, {version}
FROM source_master
WHERE source_url = {q(source_url)};
""".strip()
      )

    lines.append(
      f"""
INSERT INTO collection_checklist (source_id, status, last_checked_at, notes)
SELECT
  source_id,
  CASE WHEN {q(status_code)} = '200' THEN 'ok' ELSE 'check' END,
  {captured_at},
  {notes}
FROM source_master
WHERE source_url = {q(source_url)};
""".strip()
    )

  lines.append("COMMIT;")

  os.makedirs(os.path.dirname(OUTPUT_SQL), exist_ok=True)
  with open(OUTPUT_SQL, "w", encoding="utf-8", newline="\n") as out:
    out.write("\n".join(lines) + "\n")

  print(f"Wrote {OUTPUT_SQL} from {len(rows)} snapshot rows")


if __name__ == "__main__":
  main()
