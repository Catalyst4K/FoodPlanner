# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

FoodPlanner is an iOS SwiftUI app (iOS 26.0 deployment target, Swift 5) for managing recipes, a pantry, and a shopping list, backed by Firebase (Auth + Firestore). There is no `Package.swift` — dependencies (FirebaseCore, FirebaseAuth, FirebaseFirestore, FirebaseStorage) are resolved via Swift Package Manager integrated directly into the Xcode project (`FoodPlanner.xcodeproj`).

`FoodPlanner/GoogleService-Info.plist` is required to run the app (Firebase config) but is gitignored and not tracked — it must exist locally, copied in by the developer, before building.

## Commands

Building/testing requires a full Xcode install selected via `xcode-select` (the CLI-tools-only default won't have `xcodebuild`).

Common tasks have a `make` entry point: `make format`, `make lint`, `make build`, `make test`, `make test-ui`, `make coverage`, `make check` (lint + build + unit tests + coverage ratchet; run it at checkpoints). `make help` lists them. The raw `xcodebuild` equivalents:

```bash
# Build
xcodebuild -project FoodPlanner.xcodeproj -scheme FoodPlanner -destination 'platform=iOS Simulator,name=iPhone 17' build

# Run all unit + UI tests
xcodebuild -project FoodPlanner.xcodeproj -scheme FoodPlanner -destination 'platform=iOS Simulator,name=iPhone 17' test

# Run a single test (Swift Testing suite/test, e.g. one @Test in DataManagerHelperTests)
xcodebuild -project FoodPlanner.xcodeproj -scheme FoodPlanner -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:FoodPlannerTests/DataManagerHelperTests/hasMissingIngredients

# Run only UI tests
xcodebuild -project FoodPlanner.xcodeproj -scheme FoodPlanner -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:FoodPlannerUITests
```

Prefer opening `FoodPlanner.xcodeproj` in Xcode and using Product > Test / ⌘U for iterative work; it's faster to target a single test via the Test navigator than via `xcodebuild`.

Unit tests (`FoodPlannerTests`) use the **Swift Testing** framework (`import Testing`, `@Suite`/`@Test`/`#expect`), not XCTest. UI tests (`FoodPlannerUITests`) use XCTest/XCUIApplication.

## Emulators and screenshots

`firebase/` holds the local Auth and Firestore emulators (project `demo-foodplanner`), a seed script and its README. Launching a DEBUG build with `-use-firebase-emulator` (handled in `FoodPlannerApp.init`) points Auth and Firestore at them, so no Firebase account is needed. `make screenshots` regenerates `docs/screenshots/` through `ScreenshotTests`, which only runs when `SCREENSHOTS=1` is set. Seed data follows the current Firestore schema; update `firebase/seed.mjs` with every schema change. Security rules live in `firebase/firestore.rules` with allow/deny tests in `firebase/test/` (`cd firebase && npm run test:emulated`); the rules are deployed by hand (Firebase console or `firebase deploy --only firestore:rules`), so after merging a rules change, publish it.

## Architecture

**Auth-gated single data owner.** `FoodPlannerApp` holds `AuthViewModel` (wraps `FirebaseAuth`'s state listener) at the app root. While `authViewModel.user` is nil, `LoginView` is shown; once signed in, `AuthenticatedRoot` is created and constructs a single `DataManager(userId:)` as a `@StateObject`, injected as an `@EnvironmentObject` for the whole authenticated view tree. The `.id(user.uid)` modifier on `AuthenticatedRoot` forces a full rebuild (fresh `DataManager`, fresh Firestore listeners) if the signed-in user changes — there is no manual teardown/re-init path for that.

**`DataManager` is the sole Firestore access point.** All reads/writes for recipes, pantry, and shopping list go through `FoodPlanner/Models/DataManager.swift`. It holds `@Published` arrays (`userRecipes`, `sharedRecipes`, `pantryIngredients`, `shoppingListIngredients`) kept live via Firestore `addSnapshotListener` calls set up in `init`. Views should never talk to `Firestore.firestore()` directly — they read `DataManager`'s published state and call its async methods to mutate.

**Firestore schema** (implicit, not modeled elsewhere — read `DataManager.swift` for the source of truth):
- `/Users/{uid}/Recipes/{recipeId}` — fields `Name`, `Instructions`, `OwnerId`, `IsShared`, `CreatedAt`; subcollection `Ingredients/{id}` with `Ref` (DocumentReference into `/Ingredients`), optional `Quantity`/`Unit`.
- `/Ingredients/{id}` — global, deduplicated case-insensitively via a `NameLower` field (`addUniqueIngredient`). Recipes, pantry, and shopping list all reference these by `DocumentReference` rather than duplicating ingredient names.
- `/Users/{uid}/Pantry/{id}` and `/Users/{uid}/ShoppingList/{id}` — each just `Ingredient` (a `DocumentReference` into `/Ingredients`) + `CreatedAt`.
- Shared recipes are queried with a `collectionGroup("Recipes")` + `whereField("IsShared", isEqualTo: true)` query, which needs a Firestore composite index — if that listener errors, the fix is almost always adding the index Firestore's console link points to (see the comment above `listenToSharedRecipes`).

**Listener/fetch-task race handling.** Each snapshot listener (`listenToUserRecipes`, `listenToSharedRecipes`, `listenToPantry`, `listenToShoppingList`) spawns an async `Task` to hydrate full objects (resolving `DocumentReference`s, etc.) and cancels the previous in-flight task for that same listener before starting a new one — this prevents a slow, stale snapshot from overwriting a newer one. Follow this pattern when adding new listeners.

**Write ordering matters for listener correctness.** `addRecipe`/`updateRecipe` write the `Ingredients` subcollection *before* the parent recipe document, specifically so the recipe listener only fires once the ingredients already exist (avoiding a flash of a recipe with zero ingredients). Preserve this ordering when touching recipe writes.

**Testable core is Firebase-free.** The ingredient/pantry matching logic (`ingredientsWithStatus`, `hasMissingIngredients`, `matchedIngredientCount`, `recipesSortedByPantryMatch`, `recipesContaining`) is implemented as `static` pure functions on `DataManager` at the bottom of the file, with instance methods just forwarding to them using current published state. New pieces of business logic that don't need live Firestore access should follow this split so they stay unit-testable without a Firebase project.

**View-local form state lives in view models, not `DataManager`.** `RecipeFormViewModel` owns the transient add/edit-recipe form (title/ingredients/instructions draft) and only talks to Firestore indirectly by handing a built `Recipe` to `DataManager`. It has a dedicated `init(editing:)` for pre-filling from an existing `Recipe`.

**Core Data is present but effectively unused for app data.** `Persistence.swift` / `FoodPlanner.xcdatamodeld` set up an `NSPersistentContainer` and are wired into the environment (`\.managedObjectContext`), but all real app data (recipes, pantry, shopping list) is Firestore-backed via `DataManager`, not Core Data.

**Orientation locking.** Individual screens can lock device orientation via `AppDelegate.setAllowedOrientations(_:)` (a static UIKit shim bridged into SwiftUI via `@UIApplicationDelegateAdaptor`); this is re-applied whenever `scenePhase` becomes `.active` to avoid a rotate-then-snap-back glitch.

**UI test hooks.** Launching with `-uitest-signed-out` (checked in `FoodPlannerApp.init` under `#if DEBUG`) force-signs-out before the app UI is shown, so UI tests can reliably start at `LoginView`. Accessibility identifiers used by `FoodPlannerUITests` follow a `screen.element` convention (e.g. `login.title`, `login.email`, `login.submit`) — keep this convention when adding new interactive elements that tests should target.

## Dependencies

Swift packages (Firebase) are embedded in the Xcode project, which Dependabot can't track. Once a month, check the [firebase-ios-sdk releases](https://github.com/firebase/firebase-ios-sdk/releases) and read the release notes before bumping. Don't bump a major version without a full test run.

New dependencies must have a permissive licence (MIT, BSD, Apache-2.0, zlib, ISC or similar). **No GPL/AGPL/LGPL**: App Store distribution and this repo's all-rights-reserved licence rule them out. After any dependency change run `make licenses` and commit `THIRD-PARTY-LICENSES.md` and `FoodPlanner/Resources/Acknowledgements.json` (the in-app Account ▸ Acknowledgements screen reads the latter; Apache-2.0 requires notices to ship with the app). `Package.resolved` is committed and pins exact versions.

## Working agreement

These rules apply to everyone who changes this repo, human or agent. "Phase 1", "R.10" and similar refer to tasks in [docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md). Some things named below (the `FirestoreSchema` enum, `make` targets, rules tests, `ci/GoogleService-Info.plist`) arrive with those tasks; follow the rule from then on.

### Rules

- **Views never touch Firebase.** Only `DataManager` imports `FirebaseFirestore` (and `AuthViewModel` imports `FirebaseAuth`). Views read published state and call `DataManager` methods. A view that imports a Firebase module is a review failure.
- **Firestore paths and field names live in one place**: a `FirestoreSchema` enum of constants (`collection.recipes`, `field.name`, …) introduced in Phase 1. No string literals for paths or fields anywhere else. A rename then becomes a one-line change plus a migration, not a grep hunt.
- **Every schema change ships as a unit:** bump `SchemaVersion`, add the migration step, update `firestore.rules` **and** its tests, and update Appendix A of the implementation plan and the schema section of `CLAUDE.md`, all in the same PR. Rules that lag the schema mean either a broken app (writes denied) or an open database.
- **Anything that sends user data somewhere new is a decision, not an implementation detail.** That covers a new SDK (analytics, crash reporting, ads), a new Firebase product, or a new field others can see (like `OwnerName`). Record it in `docs/decisions.md` first, then update the privacy policy, `PrivacyInfo.xcprivacy`, the App Privacy labels and the README's data table together.
- **Pure logic is Foundation-only and has tests.** Matching, parsing, formatting, sorting, grouping, date keys, merge rules: `static` functions or small types with no Firebase/SwiftUI import, as `DataManager`'s helpers already do.
- **Observable state is `@MainActor`.** `DataManager`, `AuthViewModel` and form view models. No `DispatchQueue.main.async` to patch over isolation warnings; fix the isolation.
- **No `!`, `try!` or `fatalError` in app code** (enforced by swift-format, R.10). Parse Firestore data defensively: a malformed doc is skipped and logged, never a crash.
- **Optimistic UI must roll back.** Any view that changes local state ahead of a write handles the failure path (Task 4.6 sets the pattern).
- **Accessibility identifiers** on every interactive element, `screen.element` style. Every image-only button gets an `accessibilityLabel`.
- **Prefer boring.** Native SwiftUI components over custom overlays; one way of doing a thing. This is a small app maintained by one person.
- **Commits:** imperative subject line ≤ 72 chars, optional area prefix (`recipes:`, `auth:`, `rules:`, `ci:`, `deps:`, `docs:`). One logical change per commit; formatting-only changes go in their own commit.

### Security

The repo is public and the app is going to the App Store, so mistakes here are both visible and shipped. Treat security as part of finishing a change, not a separate pass.

Before committing or pushing:

- **Never commit secrets or signing material**: `GoogleService-Info.plist` (real one), App Store Connect API keys (`AuthKey_*.p8`), certificates (`.p12`, `.cer`), provisioning profiles, Firebase service-account JSON, `.env` files. The only committed plist is `ci/GoogleService-Info.plist` with fake values. The real Firebase config has already leaked once (finding R2), so this isn't hypothetical.
- **Check what `git add` staged** (`git status`), and open any file whose name doesn't explain its contents.
- **No real personal data in fixtures, seeds or screenshots.** Demo accounts use made-up names, `example.com` emails and invented recipes.

When a change touches a trust boundary, actively look for the hole:

- **The security rules are the backend.** There is no server: anything a client can do with the public config is limited only by `firestore.rules` / `storage.rules`. Client-side checks are for UX. Any new collection, field or query needs rules **and** rules tests (allow *and* deny cases) in the same PR. Never use broad `allow read, write: if request.auth != null`.
- **Shared recipes are untrusted input from other users.** Render them only as plain text: `Text(someString)`, which doesn't parse markdown. Never pass them through `LocalizedStringKey`, `AttributedString(markdown:)` or a web view, because markdown links in a shared recipe would be a phishing vector. Enforce size limits in rules as well as in the form. Future URL fields (recipe source links) must be `https` only, checked before opening.
- **Images (6.3):** downscale and re-encode on device (which also strips EXIF/location metadata) before upload; Storage rules enforce `image/*` and a size limit.
- **Auth:** use Firebase Auth's APIs only. Never store passwords or tokens yourself (Firebase keeps them in the Keychain). Account deletion must remove the user's data (3.5). Password-reset messages never reveal whether an account exists.
- **Logging:** use `os.Logger`, not `print`. User content and emails are logged with `privacy: .private` (or not at all). Release builds must not log document contents.
- **Dependencies are supply chain.** Few, well-known packages (currently just Firebase). Every addition is a decision-log entry, must have a permissive licence (R.16), and `Package.resolved` is committed and pinned. Review Dependabot/Firebase release notes before bumping, and don't bump a major version without a full checkpoint run.
- **CI never needs or sees secrets** (R.11). Never add a workflow using `pull_request_target`, and never add a repo secret "just for CI". If a future job genuinely needs one (e.g. TestFlight upload), it runs only on `push` to `main` in a protected environment.
- **Docs are public too.** `docs/` notes and the decision log must not contain keys, project-internal URLs with tokens, or anyone's personal data.

If you find something, say so plainly and fix or flag it. Don't quietly work around it.

### Testing

Four layers; most changes need only one or two:

| Layer | Where | Runs against | Covers |
|---|---|---|---|
| **Unit** | `FoodPlannerTests/` (Swift Testing) | nothing external | pure logic, view models, mapping, parsers |
| **Integration** | `FoodPlannerTests/Integration/` (Swift Testing, skipped unless `FIREBASE_EMULATOR=1`) | Firestore + Auth emulators | `DataManager` reads/writes, batches, migration |
| **Rules** | `firebase/test/` (Node, `@firebase/rules-unit-testing`) | Firestore/Storage emulators | every allow and deny path in the rules |
| **Acceptance** | `FoodPlannerUITests/` (XCUITest, `-use-firebase-emulator`) | the built app + emulators | user-facing flows end to end |

- **Every feature and every fix carries its own tests, in the same branch**, in each layer it touches. A fix without a regression test isn't finished. Pure logic gets tests with realistic values (real ingredient strings, real dates across DST), not placeholders.
- **The coverage ratchet** (R.13) is a backstop for business logic. It only proves nothing dropped, not that the right things were tested. Never lower it.
- **Never hit production Firebase from tests.** Everything runs against emulators under a `demo-` project ID.
- **During iteration run only the relevant tests**; at checkpoints run `make check`. Checkpoints: opening or updating a PR, merging, archiving a TestFlight build.
- **Cloud sessions can't build the app.** They must say so in the PR (PR template, R.12), and that PR can't merge until CI's `build-test` is green.

