import os

TEMPLATE = "sql/cleanup_source_observation_keep_latest_n.sql"
OUTPUT = "sql/cleanup_source_observation_keep_latest_n.generated.sql"


def main():
  keep_n = os.getenv("KEEP_N", "5").strip()
  if not keep_n.isdigit() or int(keep_n) <= 0:
    raise ValueError("KEEP_N must be a positive integer")

  with open(TEMPLATE, "r", encoding="utf-8") as f:
    raw = f.read()
  rendered = raw.replace("__KEEP_N__", keep_n)

  with open(OUTPUT, "w", encoding="utf-8", newline="\n") as out:
    out.write(rendered)

  print(f"Generated {OUTPUT} with KEEP_N={keep_n}")


if __name__ == "__main__":
  main()
