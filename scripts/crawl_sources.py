import csv
import datetime as dt
import hashlib
import os
import re
import urllib.error
import urllib.request

INPUT_CSV = "data/source_collection_checklist_kr_jp_us_sg_ae.csv"
OUTPUT_CSV = "data/source_snapshots.csv"
TIMEOUT_SEC = 20


def fetch_snapshot(url: str):
  req = urllib.request.Request(
    url,
    headers={
      "User-Agent": "energy-duty-checker-bot/1.0 (+github-actions)"
    },
    method="GET",
  )
  try:
    with urllib.request.urlopen(req, timeout=TIMEOUT_SEC) as resp:
      status = getattr(resp, "status", 200)
      headers = resp.headers
      body_bytes = resp.read(512 * 1024)
      body = body_bytes.decode("utf-8", errors="ignore")

      title = ""
      m = re.search(r"<title[^>]*>(.*?)</title>", body, flags=re.IGNORECASE | re.DOTALL)
      if m:
        title = re.sub(r"\s+", " ", m.group(1)).strip()

      etag = headers.get("ETag", "")
      last_modified = headers.get("Last-Modified", "")
      body_hash = hashlib.sha256(body_bytes).hexdigest()
      return {
        "status_code": str(status),
        "title": title,
        "etag": etag,
        "last_modified_header": last_modified,
        "content_hash_sha256": body_hash,
        "error_message": "",
      }
  except urllib.error.HTTPError as e:
    return {
      "status_code": str(e.code),
      "title": "",
      "etag": "",
      "last_modified_header": "",
      "content_hash_sha256": "",
      "error_message": f"HTTPError: {e.reason}",
    }
  except Exception as e:
    return {
      "status_code": "0",
      "title": "",
      "etag": "",
      "last_modified_header": "",
      "content_hash_sha256": "",
      "error_message": f"Error: {str(e)}",
    }


def ensure_output_header(path: str):
  os.makedirs(os.path.dirname(path), exist_ok=True)
  if os.path.exists(path):
    return
  with open(path, "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow([
      "captured_at_utc",
      "country",
      "category",
      "source_name",
      "source_url",
      "status_code",
      "title",
      "etag",
      "last_modified_header",
      "content_hash_sha256",
      "error_message",
    ])


def main():
  ensure_output_header(OUTPUT_CSV)
  now = dt.datetime.utcnow().replace(microsecond=0).isoformat() + "Z"

  with open(INPUT_CSV, "r", encoding="utf-8-sig", newline="") as src:
    reader = csv.DictReader(src)
    rows = list(reader)

  out_rows = []
  for r in rows:
    url = (r.get("source_url") or "").strip()
    if not url:
      continue
    snapshot = fetch_snapshot(url)
    out_rows.append([
      now,
      (r.get("country") or "").strip(),
      (r.get("category") or "").strip(),
      (r.get("source_name") or "").strip(),
      url,
      snapshot["status_code"],
      snapshot["title"],
      snapshot["etag"],
      snapshot["last_modified_header"],
      snapshot["content_hash_sha256"],
      snapshot["error_message"],
    ])

  with open(OUTPUT_CSV, "a", newline="", encoding="utf-8") as out:
    w = csv.writer(out)
    w.writerows(out_rows)

  print(f"Wrote {len(out_rows)} snapshots to {OUTPUT_CSV}")


if __name__ == "__main__":
  main()
