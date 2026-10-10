#!/usr/bin/env bash
# Regenerates docs/screenshots/*.png. Starts the Firebase emulators, seeds a demo
# account with made-up data, runs ScreenshotTests, and exports the images.
# Run via `make screenshots`. Uses the fake CI Firebase config (project demo-foodplanner),
# restoring your real FoodPlanner/GoogleService-Info.plist afterwards.
set -euo pipefail
cd "$(dirname "$0")/.."

SIMULATOR="${SIMULATOR:-iPhone 17}"
PLIST=FoodPlanner/GoogleService-Info.plist
OUT=build-output/screenshots
export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@21}"
export PATH="$JAVA_HOME/bin:$PATH"

mkdir -p build-output docs/screenshots
# shellcheck source=_plist-swap.sh
. "$(dirname "$0")/_plist-swap.sh"

[ -d firebase/node_modules ] || (cd firebase && npm ci)
rm -rf "$OUT"
rm -rf build-output/screenshots-*.xcresult

UDID="$(xcrun simctl list devices available -j | python3 -c "
import json, sys
name = sys.argv[1]
for runtime, devices in json.load(sys.stdin)['devices'].items():
    if 'iOS' in runtime:
        for d in devices:
            if d['name'] == name:
                print(d['udid']); sys.exit(0)
sys.exit('No available simulator named ' + name)
" "$SIMULATOR")"
xcrun simctl boot "$UDID" 2>/dev/null || true

(cd firebase && npx firebase emulators:exec --project demo-foodplanner --only auth,firestore \
  "../scripts/_screenshots-run.sh '$UDID' '$SIMULATOR'")

for mode in light dark; do
  xcrun xcresulttool export attachments --path "build-output/screenshots-$mode.xcresult" --output-path "$OUT/$mode"
done
python3 - "$OUT" <<'PY'
import json, os, shutil, sys
out = sys.argv[1]
n = 0
for mode in ("light", "dark"):
    base = os.path.join(out, mode)
    for test in json.load(open(os.path.join(base, "manifest.json"))):
        for att in test.get("attachments", []):
            name = att["suggestedHumanReadableName"].split("_")[0]
            if not name.endswith(("-light", "-dark")):
                continue  # skip videos, snapshots and other automatic attachments
            shutil.copy(os.path.join(base, att["exportedFileName"]), os.path.join("docs/screenshots", name + ".png"))
            n += 1
print(f"Wrote {n} screenshots to docs/screenshots/")
PY
