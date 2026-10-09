# Single entry point for common commands. See CLAUDE.md.
# Override the simulator with: make test SIMULATOR="iPhone 17 Pro"

SIMULATOR ?= iPhone 17
PROJECT   := FoodPlanner.xcodeproj
SCHEME    := FoodPlanner
DEST      := platform=iOS Simulator,name=$(SIMULATOR)
SOURCES   := FoodPlanner FoodPlannerTests FoodPlannerUITests
OUT       := build-output
FIREBASE_PLIST := FoodPlanner/GoogleService-Info.plist

.PHONY: help format lint build test test-ui coverage licenses check plist

help:
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | sed 's/:.*##/\t/'

format: ## Format all Swift sources in place
	swift format --in-place --recursive $(SOURCES)

lint: ## swift-format lint, strict
	swift format lint --strict --recursive $(SOURCES)

# The app needs a Firebase plist to build; use the fake CI one if you have no real one.
plist:
	@test -f $(FIREBASE_PLIST) || { cp ci/GoogleService-Info.plist $(FIREBASE_PLIST); echo "Copied fake CI plist to $(FIREBASE_PLIST)"; }

build: plist ## Build the app for the simulator
	xcodebuild build -project $(PROJECT) -scheme $(SCHEME) -destination '$(DEST)'

test: plist ## Run unit tests
	xcodebuild test -project $(PROJECT) -scheme $(SCHEME) -destination '$(DEST)' -only-testing:FoodPlannerTests

test-ui: plist ## Run UI tests
	xcodebuild test -project $(PROJECT) -scheme $(SCHEME) -destination '$(DEST)' -only-testing:FoodPlannerUITests

coverage: plist ## Unit tests with coverage, then the ratchet check
	rm -rf $(OUT)/unit.xcresult
	xcodebuild test -project $(PROJECT) -scheme $(SCHEME) -destination '$(DEST)' -only-testing:FoodPlannerTests \
		-enableCodeCoverage YES -resultBundlePath $(OUT)/unit.xcresult
	scripts/check-coverage.sh $(OUT)/unit.xcresult

licenses: build ## Regenerate THIRD-PARTY-LICENSES.md and Acknowledgements.json
	scripts/generate-third-party-licenses.sh

check: lint build coverage ## Full checkpoint battery (lint, build, unit tests, coverage ratchet)
