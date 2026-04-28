import argparse
import json
import urllib.error
import urllib.request


def request_json(method, url, headers=None, body=None):
  data = None
  if body is not None:
    data = json.dumps(body).encode("utf-8")
  req = urllib.request.Request(url, data=data, method=method)
  for k, v in (headers or {}).items():
    req.add_header(k, v)
  if body is not None:
    req.add_header("content-type", "application/json")
  with urllib.request.urlopen(req, timeout=20) as resp:
    return resp.status, json.loads(resp.read().decode("utf-8"))


def main():
  parser = argparse.ArgumentParser()
  parser.add_argument("--base-url", default="http://127.0.0.1:8787")
  parser.add_argument("--api-key", default="demo-free-key-001")
  args = parser.parse_args()

  base = args.base_url.rstrip("/")
  auth = {"x-api-key": args.api_key}

  st, health = request_json("GET", f"{base}/health")
  assert st == 200 and health.get("status") == "ok", "health check failed"

  st, tax = request_json(
    "POST",
    f"{base}/tax-lookup",
    headers=auth,
    body={
      "origin_country": "KR",
      "destination_country": "JP",
      "trade_type": "export",
      "asset_type": "diesel",
      "hs_code": "271019",
      "trade_date": "2026-04-29",
      "declared_value_usd": 100000,
    },
  )
  assert st == 200, "tax-lookup failed"
  assert "result" in tax and "estimated_total_tax_usd" in tax["result"], "tax payload invalid"

  st, zones = request_json(
    "GET",
    f"{base}/incentive-zones?country=AE&asset_type=energy&as_of=2026-04-29",
    headers=auth,
  )
  assert st == 200, "incentive-zones failed"
  assert "zones" in zones and isinstance(zones["zones"], list), "incentive payload invalid"

  # Unauthorized check
  try:
    request_json("POST", f"{base}/tax-lookup", body={"origin_country": "KR"})
    raise AssertionError("unauthorized check failed")
  except urllib.error.HTTPError as e:
    assert e.code == 401, "expected 401 without api key"

  print("Smoke test passed")


if __name__ == "__main__":
  main()
