#!/usr/bin/env bash
# Coverage ratchet: fails if line coverage of business logic drops below the
# number in .coverage-threshold. The threshold only goes up: raise it in the
# same PR that raises coverage; never lower it to make a build green.
#
# Business logic = FoodPlanner/Models/** and FoodPlanner/ViewModels/**, except
# Models/DataManager.swift (mostly Firestore plumbing; excluded until
# integration tests cover it, plan 8.5). Views are covered by UI tests.
#
# Usage: scripts/check-coverage.sh path/to/tests.xcresult
set -euo pipefail

RESULT="${1:?usage: check-coverage.sh <xcresult>}"
THRESHOLD_FILE="$(cd "$(dirname "$0")/.." && pwd)/.coverage-threshold"
THRESHOLD="$(tr -d '[:space:]' <"$THRESHOLD_FILE")"

xcrun xccov view --report --json "$RESULT" | python3 -c '
import json, sys
threshold = float(sys.argv[1])
report = json.load(sys.stdin)
covered = total = 0
rows = []
for target in report["targets"]:
    if not target["name"].startswith("FoodPlanner.app"):
        continue
    for f in target["files"]:
        path = f["path"]
        if "/FoodPlanner/Models/" not in path and "/FoodPlanner/ViewModels/" not in path:
            continue
        if path.endswith("/DataManager.swift"):
            continue
        covered += f["coveredLines"]
        total += f["executableLines"]
        rows.append((path.split("/FoodPlanner/")[-1], f["coveredLines"], f["executableLines"]))
for name, c, t in sorted(rows):
    print(f"  {name}: {c}/{t}")
pct = 100.0 * covered / total if total else 100.0
print(f"Business-logic line coverage: {pct:.1f}% ({covered}/{total}); threshold {threshold:.1f}%")
if pct + 1e-9 < threshold:
    print("FAIL: coverage dropped below the ratchet. Add tests; do not lower the threshold.")
    sys.exit(1)
if pct > threshold + 1.0:
    print(f"Note: coverage is well above the threshold. Raise .coverage-threshold to {int(pct)} in this PR.")
' "$THRESHOLD"
