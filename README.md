# FoodPlanner

Plan meals around what's already in your kitchen: recipes, pantry and shopping list that keep each other in sync.

[![CI](https://github.com/Catalyst4K/FoodPlanner/actions/workflows/ci.yml/badge.svg)](https://github.com/Catalyst4K/FoodPlanner/actions/workflows/ci.yml)
[![CodeQL](https://github.com/Catalyst4K/FoodPlanner/actions/workflows/codeql.yml/badge.svg)](https://github.com/Catalyst4K/FoodPlanner/actions/workflows/codeql.yml)
![iOS 26+](https://img.shields.io/badge/iOS-26%2B-blue)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Firebase-orange)
![Licence: all rights reserved](https://img.shields.io/badge/licence-all%20rights%20reserved-lightgrey)

> **Status:** early development. The app isn't released yet. See the [implementation plan](docs/IMPLEMENTATION_PLAN.md) and the [changelog](CHANGELOG.md).

## Features

- Sign up and sign in with email and password (Firebase Auth).
- Recipes with ingredients and instructions, edited inline, with optional sharing to other signed-in users.
- A pantry of what you have, and a shopping list of what you need.
- Recipes ordered by how many of their ingredients are already in your pantry.
- An in-app list of third-party licences.

## Engineering highlights

- **Real-time sync.** Recipes, pantry and shopping list are kept live with Firestore snapshot listeners owned by a single [`DataManager`](FoodPlanner/Models/DataManager.swift); views never talk to Firebase directly.
- **Testable core logic.** Pantry matching and ordering are pure static functions, covered by [Swift Testing](FoodPlannerTests/DataManagerHelperTests.swift) suites, with a [coverage ratchet](scripts/check-coverage.sh) that fails CI if business-logic coverage drops.
- **CI that needs no secrets.** [Workflows](.github/workflows) build and test against a [fake Firebase config](ci/GoogleService-Info.plist), run CodeQL for Swift and for the workflows themselves, pin actions to commit SHAs, and check the third-party licence files are up to date.
- **Repo hygiene.** `swift-format` lint in CI, a [`Makefile`](Makefile) entry point, pinned dependencies, Dependabot, a [security policy](SECURITY.md), and a dated [decision log](docs/decisions.md).
- **Privacy by default.** A [privacy manifest](FoodPlanner/PrivacyInfo.xcprivacy), no analytics, and no tracking.

More will be listed here as the planned work (security rules with tests, emulator-backed UI tests, the meal planner) merges.

## Architecture

`FoodPlannerApp` holds an `AuthViewModel` that wraps Firebase Auth. While signed out it shows `LoginView`; once signed in it creates one `DataManager` for that user and injects it into the whole view tree. Form state lives in small view models. Read [`CLAUDE.md`](CLAUDE.md) for the details and the working rules.

## Data and privacy

| What | Where it goes |
|---|---|
| Email address | Firebase Authentication |
| Recipes, pantry and shopping list | Cloud Firestore, under your account |
| Recipes you choose to share | Readable by every signed-in user |

Nothing is used for advertising or tracking. A hosted privacy policy will come before release.

## Building from source

Requires Xcode 26.

```bash
make plist   # copies a fake Firebase config so the app compiles
make test    # unit tests
make check   # lint, build, unit tests and the coverage ratchet
```

To run the app against a backend you need your own Firebase project: put its `GoogleService-Info.plist` in `FoodPlanner/` (it is gitignored). An emulator mode that needs no Firebase account is planned.

## Project structure

```
FoodPlanner/           app source (Models, ViewModels, Views, Resources)
FoodPlannerTests/      unit tests (Swift Testing)
FoodPlannerUITests/    UI tests (XCUITest)
ci/                    fake Firebase config used by CI
docs/                  implementation plan and decision log
scripts/               repo security settings, coverage ratchet, licence generator
```

## Licence

All rights reserved. The source is published for evaluation only; see [LICENSE](LICENSE) and [COPYRIGHT](COPYRIGHT). Third-party notices are in [THIRD-PARTY-LICENSES.md](THIRD-PARTY-LICENSES.md).

## Author

Callum Jones, [@Catalyst4K](https://github.com/Catalyst4K)
