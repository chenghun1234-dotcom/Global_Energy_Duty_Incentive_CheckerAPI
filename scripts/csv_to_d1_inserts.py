import csv
import os

INPUT_CSV = "data/source_collection_checklist_kr_jp_us_sg_ae.csv"
OUTPUT_SQL = "sql/staging_inserts.sql"
TABLE_NAME = "source_collection_staging"


def sql_escape(value: str) -> str:
  return value.replace("'", "''")


def to_sql_literal(value: str) -> str:
  if value is None:
    return "NULL"
  v = value.strip()
  if v == "":
    return "NULL"
  return "'" + sql_escape(v) + "'"


def main():
  os.makedirs(os.path.dirname(OUTPUT_SQL), exist_ok=True)
  with open(INPUT_CSV, "r", encoding="utf-8-sig", newline="") as f:
    reader = csv.DictReader(f)
    headers = reader.fieldnames or []
    rows = list(reader)

  cols = ", ".join(headers)
  lines = ["BEGIN TRANSACTION;"]
  for r in rows:
    values = ", ".join(to_sql_literal(r.get(h)) for h in headers)
    lines.append(f"INSERT INTO {TABLE_NAME} ({cols}) VALUES ({values});")
  lines.append("COMMIT;")

  with open(OUTPUT_SQL, "w", encoding="utf-8", newline="\n") as out:
    out.write("\n".join(lines) + "\n")

  print(f"Wrote {len(rows)} rows to {OUTPUT_SQL}")


if __name__ == "__main__":
  main()
