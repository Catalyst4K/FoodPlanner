#!/usr/bin/env bash
# Runs the DataManager integration tests (FoodPlannerTests/Integration) against the Auth and Firestore emulators
# (project demo-foodplanner, real firestore.rules). Run via `make test-integration`. Uses the fake CI Firebase
# config, restoring your real FoodPlanner/GoogleService-Info.plist afterwards.
set -euo pipefail
cd "$(dirname "$0")/.."

SIMULATOR="${SIMULATOR:-iPhone 17}"
export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@21}"
export PATH="$JAVA_HOME/bin:$PATH"

mkdir -p build-output
# shellcheck source=_plist-swap.sh
. "$(dirname "$0")/_plist-swap.sh"

[ -d firebase/node_modules ] || (cd firebase && npm ci)
rm -rf build-output/integration.xcresult

(cd firebase && npx firebase emulators:exec --project demo-foodplanner --only auth,firestore \
  "cd .. && TEST_RUNNER_FIREBASE_EMULATOR=1 xcodebuild test \
     -project FoodPlanner.xcodeproj -scheme FoodPlanner \
     -destination 'platform=iOS Simulator,name=$SIMULATOR' \
     -only-testing:FoodPlannerTests/DataManagerIntegrationTests \
     -resultBundlePath build-output/integration.xcresult")
