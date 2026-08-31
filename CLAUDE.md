# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

FoodPlanner is an iOS SwiftUI app (iOS 26.0 deployment target, Swift 5) for managing recipes, a pantry, and a shopping list, backed by Firebase (Auth + Firestore). There is no `Package.swift` — dependencies (FirebaseCore, FirebaseAuth, FirebaseFirestore, FirebaseStorage) are resolved via Swift Package Manager integrated directly into the Xcode project (`FoodPlanner.xcodeproj`).

`FoodPlanner/GoogleService-Info.plist` is required to run the app (Firebase config) but is gitignored and not tracked — it must exist locally, copied in by the developer, before building.

## Commands

Building/testing requires a full Xcode install selected via `xcode-select` (the CLI-tools-only default won't have `xcodebuild`).

```bash
# Build
xcodebuild -project FoodPlanner.xcodeproj -scheme FoodPlanner -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run all unit + UI tests
xcodebuild -project FoodPlanner.xcodeproj -scheme FoodPlanner -destination 'platform=iOS Simulator,name=iPhone 16' test

# Run a single test (Swift Testing suite/test, e.g. one @Test in DataManagerHelperTests)
xcodebuild -project FoodPlanner.xcodeproj -scheme FoodPlanner -destination 'platform=iOS Simulator,name=iPhone 16' \
  test -only-testing:FoodPlannerTests/DataManagerHelperTests/hasMissingIngredients

# Run only UI tests
xcodebuild -project FoodPlanner.xcodeproj -scheme FoodPlanner -destination 'platform=iOS Simulator,name=iPhone 16' \
  test -only-testing:FoodPlannerUITests
```

Prefer opening `FoodPlanner.xcodeproj` in Xcode and using Product > Test / ⌘U for iterative work; it's faster to target a single test via the Test navigator than via `xcodebuild`.

Unit tests (`FoodPlannerTests`) use the **Swift Testing** framework (`import Testing`, `@Suite`/`@Test`/`#expect`), not XCTest. UI tests (`FoodPlannerUITests`) use XCTest/XCUIApplication.

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

**View-local form state lives in view models, not `DataManager`.** `RecipeListViewModel` owns the transient add/edit-recipe form (title/ingredients/instructions draft) and only talks to Firestore indirectly by handing a built `Recipe` to `DataManager`. It has a dedicated `init(editing:)` for pre-filling from an existing `Recipe`.

**Core Data is present but effectively unused for app data.** `Persistence.swift` / `FoodPlanner.xcdatamodeld` set up an `NSPersistentContainer` and are wired into the environment (`\.managedObjectContext`), but all real app data (recipes, pantry, shopping list) is Firestore-backed via `DataManager`, not Core Data.

**Orientation locking.** Individual screens can lock device orientation via `AppDelegate.setAllowedOrientations(_:)` (a static UIKit shim bridged into SwiftUI via `@UIApplicationDelegateAdaptor`); this is re-applied whenever `scenePhase` becomes `.active` to avoid a rotate-then-snap-back glitch.

**UI test hooks.** Launching with `-uitest-signed-out` (checked in `FoodPlannerApp.init` under `#if DEBUG`) force-signs-out before the app UI is shown, so UI tests can reliably start at `LoginView`. Accessibility identifiers used by `FoodPlannerUITests` follow a `screen.element` convention (e.g. `login.title`, `login.email`, `login.submit`) — keep this convention when adding new interactive elements that tests should target.
