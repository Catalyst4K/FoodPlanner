#!/usr/bin/env bash
# Inner step of screenshots.sh; runs inside `firebase emulators:exec`. Not for direct use.
set -euo pipefail
cd "$(dirname "$0")/.."
UDID="$1"
SIMULATOR_NAME="$2"

(cd firebase && node seed.mjs)

for mode in light dark; do
  # xcodebuild shuts the simulator down afterwards, so boot it again for each mode.
  xcrun simctl bootstatus "$UDID" -b >/dev/null
  xcrun simctl ui "$UDID" appearance "$mode"
  rm -rf "build-output/screenshots-$mode.xcresult"
  TEST_RUNNER_SCREENSHOTS=1 TEST_RUNNER_SCREENSHOT_MODE="$mode" xcodebuild test \
    -project FoodPlanner.xcodeproj -scheme FoodPlanner \
    -destination "platform=iOS Simulator,id=$UDID" \
    -only-testing:FoodPlannerUITests/ScreenshotTests \
    -resultBundlePath "build-output/screenshots-$mode.xcresult"
done
xcrun simctl ui "$UDID" appearance light 2>/dev/null || true
