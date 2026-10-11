#!/usr/bin/env bash
# Runs the emulator-backed UI tests (FoodPlannerUITests/SignedInFlowTests): starts the Auth and Firestore
# emulators, then the tests against them. Run via `make test-ui-emulated`. Uses the fake CI Firebase config
# (project demo-foodplanner), restoring your real FoodPlanner/GoogleService-Info.plist afterwards.
set -euo pipefail
cd "$(dirname "$0")/.."

SIMULATOR="${SIMULATOR:-iPhone 17}"
# UI_RETRIES: how many times a failed test is retried (CI sets 2: the hosted macOS runners are slow enough
# that a different test times out on most runs). Locally 0, so a failure is a failure.
UI_RETRIES="${UI_RETRIES:-0}"
RETRY_FLAGS=""
if [ "$UI_RETRIES" -gt 0 ]; then RETRY_FLAGS="-retry-tests-on-failure -test-iterations $((UI_RETRIES + 1))"; fi
ONLY="${ONLY:-SignedInFlowTests}" # e.g. ONLY=SignedInFlowTests/test_editAndDeleteRecipe
PLIST=FoodPlanner/GoogleService-Info.plist
export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@21}"
export PATH="$JAVA_HOME/bin:$PATH"

mkdir -p build-output
# shellcheck source=_plist-swap.sh
. "$(dirname "$0")/_plist-swap.sh"

[ -d firebase/node_modules ] || (cd firebase && npm ci)
rm -rf build-output/ui-emulated.xcresult

(cd firebase && npx firebase emulators:exec --project demo-foodplanner --only auth,firestore \
  "cd .. && TEST_RUNNER_FIREBASE_EMULATOR=1 xcodebuild test \
     -project FoodPlanner.xcodeproj -scheme FoodPlanner \
     -destination 'platform=iOS Simulator,name=$SIMULATOR' \
     -only-testing:FoodPlannerUITests/$ONLY $RETRY_FLAGS \
     -resultBundlePath build-output/ui-emulated.xcresult")
