import argparse
import subprocess
import sys


def run(cmd):
  p = subprocess.run(cmd, capture_output=True, text=True)
  return p.returncode, p.stdout, p.stderr


def main():
  parser = argparse.ArgumentParser()
  parser.add_argument("--db", default="energy-duty-db")
  parser.add_argument("--remote", action="store_true")
  args = parser.parse_args()

  base = ["npx", "wrangler", "d1", "execute", args.db]
  base.append("--remote" if args.remote else "--local")

  rc, out, err = run(base + ["--command", "PRAGMA table_info(source_observation);"])
  if rc != 0:
    print(out)
    print(err, file=sys.stderr)
    raise SystemExit(rc)

  if "captured_at" in out:
    print("captured_at already exists. Skipping ALTER TABLE.")
  else:
    rc2, out2, err2 = run(
      base + ["--command", "ALTER TABLE source_observation ADD COLUMN captured_at TEXT;"]
    )
    if rc2 != 0:
      print(out2)
      print(err2, file=sys.stderr)
      raise SystemExit(rc2)
    print("captured_at added.")

  rc3, out3, err3 = run(
    base
    + [
      "--command",
      "CREATE INDEX IF NOT EXISTS idx_observation_source_captured ON source_observation(source_id, captured_at);",
    ]
  )
  if rc3 != 0:
    print(out3)
    print(err3, file=sys.stderr)
    raise SystemExit(rc3)
  print("Index ensured: idx_observation_source_captured")


if __name__ == "__main__":
  main()
