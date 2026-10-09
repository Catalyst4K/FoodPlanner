#!/usr/bin/env bash
# Runs the emulator-backed UI tests (FoodPlannerUITests/SignedInFlowTests): starts the Auth and Firestore
# emulators, then the tests against them. Run via `make test-ui-emulated`. Uses the fake CI Firebase config
# (project demo-foodplanner), restoring your real FoodPlanner/GoogleService-Info.plist afterwards.
set -euo pipefail
cd "$(dirname "$0")/.."

SIMULATOR="${SIMULATOR:-iPhone 17}"
ONLY="${ONLY:-SignedInFlowTests}" # e.g. ONLY=SignedInFlowTests/test_editAndDeleteRecipe
PLIST=FoodPlanner/GoogleService-Info.plist
export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@21}"
export PATH="$JAVA_HOME/bin:$PATH"

mkdir -p build-output
BACKUP=""
if [ -f "$PLIST" ]; then BACKUP="$(mktemp)"; cp "$PLIST" "$BACKUP"; fi
restore() { if [ -n "$BACKUP" ]; then cp "$BACKUP" "$PLIST"; rm -f "$BACKUP"; else rm -f "$PLIST"; fi; }
trap restore EXIT
cp ci/GoogleService-Info.plist "$PLIST"

[ -d firebase/node_modules ] || (cd firebase && npm ci)
rm -rf build-output/ui-emulated.xcresult

(cd firebase && npx firebase emulators:exec --project demo-foodplanner --only auth,firestore \
  "cd .. && TEST_RUNNER_FIREBASE_EMULATOR=1 xcodebuild test \
     -project FoodPlanner.xcodeproj -scheme FoodPlanner \
     -destination 'platform=iOS Simulator,name=$SIMULATOR' \
     -only-testing:FoodPlannerUITests/$ONLY \
     -resultBundlePath build-output/ui-emulated.xcresult")
