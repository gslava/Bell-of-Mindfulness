#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
import subprocess

result = subprocess.run(["git", "log", "--all", "--format=%H%x09%an%x09%ae%x09%cn%x09%ce"],
                        text=True, capture_output=True, check=True)
rows = result.stdout.splitlines()
if not rows:
    raise SystemExit("No commits to audit.")
expected = ["gslava", "itic1gm@gmail.com", "gslava", "itic1gm@gmail.com"]
bad = [row.split("\t") for row in rows if row.split("\t")[1:] != expected]
if bad:
    for row in bad:
        print(f"Unexpected author/committer: {row[0]}: {row[1:]}")
    raise SystemExit(1)
print(f"Verified author and committer for all {len(rows)} commits: gslava <itic1gm@gmail.com>.")
PY
