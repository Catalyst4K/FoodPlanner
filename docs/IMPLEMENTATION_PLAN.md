# FoodPlanner — Implementation Plan

_Written 2026-10-02 against `main` @ `fd4101f`; Phase R + Appendices G/H added 2026-10-07. Audience: the agent (or person) implementing this, plus Callum reviewing it._

This document is the single source of truth for "what to build next and how". It contains:

1. [How to use this plan](#1-how-to-use-this-plan) — ground rules for the implementer
2. [Current state](#2-current-state) — what exists today
3. [Findings](#3-findings) — every issue found in the review, with file references
4. [Decisions](#4-decisions-defaults-chosen) — choices already made (with defaults Callum can override)
5. [Phases](#5-phases) — the ordered work, broken into PR-sized tasks with acceptance criteria
6. [Appendices](#appendices) — schema v2 spec, security rules draft, normalisation spec, error-message table, units, release checklist, **working agreement (G)**, **licence + README templates (H)**

Start with **Phase R** (repository foundations). The repo is public, so licensing and security settings come before feature work.

---

## 1. How to use this plan

### 1.1 Ground rules

- **Read `CLAUDE.md` first.** Its architecture rules still apply unless a task below explicitly changes them. When a task changes an architectural rule (e.g. schema, listener pattern), **update `CLAUDE.md` in the same PR**.
- **One task (or a tightly-related group of tasks) per PR.** Each task below lists its scope. Don't widen it. Small PRs make Xcode build errors easy to localise — this matters a lot (see 1.2).
- **Work the phases in order** unless the dependency table in §5.0 says otherwise. Phase 1 (data layer) changes the Firestore schema; almost everything after it assumes schema v2.
- **Tick the checkbox** next to a task in this file in the same PR that completes it, so the plan stays live.
- **Tests:** unit tests use Swift Testing (`import Testing`, `@Suite`/`@Test`/`#expect`). Any new pure logic goes in a Foundation-only file (no `Firebase`, no `SwiftUI` imports) so it is unit-testable without a Firebase project — follow the existing "pure static helper" split described in `CLAUDE.md`.
- **Accessibility identifiers** follow `screen.element` (e.g. `login.email`, `signup.submit`, `account.delete`). Add them to every new interactive element.
- **Never commit `FoodPlanner/GoogleService-Info.plist`.**
- **Xcode project file:** the three targets use `PBXFileSystemSynchronizedRootGroup`, so **adding/removing/renaming `.swift` files under `FoodPlanner/`, `FoodPlannerTests/`, `FoodPlannerUITests/` needs no `project.pbxproj` edit** — just create/move the file. Do **not** hand-edit `project.pbxproj` unless a task says so. Corollary: any non-Swift file placed inside `FoodPlanner/` gets bundled into the app — so Firebase config (`firestore.rules`, `firebase.json`, Node tests) lives at the **repo root / `firebase/`**, never inside `FoodPlanner/`.

### 1.2 Build environment caveat (important)

The iOS app **cannot be compiled in a Linux cloud container** — there is no Swift toolchain or `xcodebuild` there. Only Node 22 + Java are available, which is enough for the Firestore rules tests (Phase 2) and nothing else.

Recommended setup for implementation:

- **Preferred:** run the implementing agent via Claude Code **locally on Callum's Mac**, where `xcodebuild` works. Then the agent must build + run unit tests after every task:
  ```bash
  xcodebuild -project FoodPlanner.xcodeproj -scheme FoodPlanner \
    -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:FoodPlannerTests
  ```
  (Use whatever simulator `xcrun simctl list devices available` shows; `CLAUDE.md` says iPhone 16, which may not exist on Xcode 26 — fix `CLAUDE.md` if so.)
- **If running in the cloud:** the agent must say clearly in each PR description that the change is **unbuilt**, keep PRs small, and Callum runs ⌘B / ⌘U before merging. Tasks marked **[Mac]** below should not be attempted from the cloud. Tasks marked **[Callum]** need a human (Xcode UI, Firebase console, App Store Connect).

Tags used below: **[cloud-ok]** can be done and verified without a Mac · **[Mac]** needs Xcode to verify · **[Callum]** needs a human.

---

## 2. Current state

~3,000 lines of Swift, 17 commits. `main` and `claude/elegant-goodall-v6ju1f` are identical.

| Area | Status |
|---|---|
| Auth | Email/password login, sign-up, log-out, account screen (email + log out). No password reset, no account deletion. |
| Recipes | Add, inline edit, delete (confirm), share/unshare (global public), save shared recipe as own copy. "My Recipes / Shared" segmented control. Sort by pantry match / name. Pantry match badge (e.g. 3/5). |
| Recipe detail | Per-ingredient pantry + shopping toggles, "Add All" missing → shopping list, landscape split layout for cooking, rotation-mask overlay. |
| Pantry | Quick add, delete. |
| Shopping list | Quick add, tick (moves to pantry), delete, "Group by Recipe" view with multi-recipe highlight. |
| Tests | 16 Swift Testing unit tests (matching helpers + form VM), 4 XCTest UI tests (login flow only; one hits real Firebase). |
| Infra | No CI, no Firestore rules/indexes in repo, no shared Xcode scheme, `Package.resolved` gitignored. |

Data model today (v1): recipes store ingredients in an `Ingredients` **subcollection** of `DocumentReference`s into a global `/Ingredients` collection; pantry and shopping list docs are random-ID docs holding a `DocumentReference` into `/Ingredients`.

---

## 3. Findings

Severity: 🔴 must fix before any external users · 🟠 should fix soon · 🟡 polish / tech debt.

### 3.1 Data layer (`FoodPlanner/Models/DataManager.swift`)

| # | Sev | Finding | Where |
|---|---|---|---|
| D1 | 🔴 | **N+1 read amplification.** Hydrating one recipe = 1 recipe doc + 1 subcollection query + 1 `getDocument` per ingredient. Pantry/shopping = 1 `getDocument` per item. The shared-recipes listener does this for **every shared recipe from every user** and re-hydrates **all** of them on **any** change to any of them. Cost and latency scale with total app usage, not with the user. | `buildRecipes` L110, `parseRecipeDoc` L135, `fetchRecipeIngredients` L159, `fetchIngredients` L463, `fetchIngredient` L494 |
| D2 | 🔴 | **`updateRecipe` is not atomic.** It deletes all ingredient docs, then adds new ones, then updates the parent. A failure (or app kill / offline) between steps leaves a recipe with zero or partial ingredients. | L247–295 |
| D3 | 🟠 | **`addUniqueIngredient` races.** Query-then-create isn't transactional; two concurrent adds of the same name (e.g. "Add All" + typing, or two devices) create duplicate `/Ingredients` docs. Pantry/shopping dedupe by *ref*, so duplicates leak into the pantry as two "Milk" rows. Same query-then-write race in `addIngredientToPantry(ref:)` / `addIngredientToShoppingList(ref:)`. | L511, L355, L408 |
| D4 | 🟠 | **Global `/Ingredients` collection is world-writable by necessity** (every user writes to it), and grows unbounded with typos. It adds a security surface without adding value — all matching logic is by lowercased *name*, not by ref. | L511 |
| D5 | 🟠 | **Data races.** `DataManager` isn't `@MainActor`, yet its `async` methods (e.g. `addMissingIngredientsToShoppingList` L550, `togglePantry` L649) read `@Published` arrays from whatever executor they run on, while listeners write them on main. | class decl L12 |
| D6 | 🟠 | **Non-atomic multi-step writes**: `moveShoppingItemToPantry` (add then remove — can lose or duplicate the item), `deleteRecipe` (sequential subcollection deletes then parent). | L545, L298 |
| D7 | 🟠 | **Silent listener errors.** User-recipes, pantry and shopping listeners only `print` errors; only the shared listener calls `report`. A permission-denied (e.g. after rules change) shows as an empty app. | L61, L332, L385 |
| D8 | 🟡 | **Name matching is inconsistent.** Matching uses `name.lowercased()` only; "Olive  oil" (double space), "olive oil " and "Jalapeño"/"jalapeno" don't match. `addUniqueIngredient` trims but the matchers don't. | static helpers L615–647 |
| D9 | 🟡 | `toggleShareRecipe` does a read-then-write round trip when the current value is already in memory. | L313 |
| D10 | 🟡 | `deinit` removes listeners but doesn't cancel the four in-flight fetch tasks. | L38 |
| D11 | 🟡 | Shared-recipes query has no `limit`/order — loads every shared recipe in the database. | L81 |

### 3.2 Security & backend config

| # | Sev | Finding |
|---|---|---|
| S1 | 🔴 | **No `firestore.rules` in the repo.** Whatever is live in the console is unreviewed and unversioned. The sharing design (collection-group read across all users) means a lax rule like `allow read, write: if request.auth != null` lets any signed-in user read **and overwrite/delete** every user's recipes, pantry and list. |
| S2 | 🟠 | No `firestore.indexes.json` — the composite index the shared query needs exists only in the console. |
| S3 | 🟠 | No server-side validation (field types, sizes). A client can write arbitrarily large docs or flip `OwnerId`. |
| S4 | 🟡 | No App Check — the Firebase backend accepts traffic from any client with the (public) API key. |

### 3.3 Auth & account (`ViewModels/AuthViewModel.swift`, `Views/LoginView.swift`, `Views/SignUpView.swift`, `Views/AccountView.swift`)

| # | Sev | Finding |
|---|---|---|
| A1 | 🔴 | **No in-app account deletion.** App Store Review Guideline 5.1.1(v) requires it for any app that supports account creation. Will be rejected. |
| A2 | 🟠 | Every login failure shows "Invalid credentials" (`LoginView.swift:39`); every sign-up failure shows "Sign Up Failed" (`SignUpView.swift:33`). Network errors, weak passwords (<6 chars), email-in-use, rate-limiting are indistinguishable. |
| A3 | 🟠 | Email fields lack `.keyboardType(.emailAddress)`, `.textInputAutocapitalization(.never)`, `.autocorrectionDisabled()`, `.textContentType(.username/.emailAddress)`; password fields lack `.textContentType(.password / .newPassword)`. iOS capitalises the first letter of the email and Password AutoFill/strong-password suggestions don't work. (`LoginView.swift:18`, `SignUpView.swift:15`) |
| A4 | 🟠 | No password reset. No password confirmation on sign-up. No loading/disabled state while a request is in flight (double-tap submits twice). |
| A5 | 🟡 | Completion-handler API; `AuthViewModel` isn't `@MainActor`; auth state listener handle is discarded. Sign-up screen has no accessibility identifiers (UI test has to match on the "Sign Up" text). |

### 3.4 UI structure (`Views/`)

| # | Sev | Finding |
|---|---|---|
| U1 | 🟠 | **Nested navigation containers.** `MainTabView` wraps the whole `TabView` in a `NavigationStack` (L29), and each tab then has its own deprecated `NavigationView` (`MainTabView.swift:35,39`, `RecipieListView.swift:9`). This is the root cause of the "detail view doesn't re-render" workaround in `RecipeDetailView.swift:1–60` (manual `onReceive` syncing) and risks double nav bars / toolbar items leaking between levels. |
| U2 | 🟠 | Custom sort overlay (`MainTabView.swift:76–108`) re-implements what a native `Menu` + `Picker` gives for free (accessibility, dismissal, haptics). Sort options are stringly-typed (`"Sort by Pantry Match"` duplicated in `MainTabView.swift:9,13` and `RecipieListView.swift:124`). Sort choice isn't persisted. |
| U3 | 🟠 | **Dark mode broken** in three places: `Color.white` backgrounds at `AddRecipeView.swift:148`, `RecipeDetailView.swift:350`, `SplashScreenView.swift:13`. |
| U4 | 🟠 | **Optimistic-hide never rolls back.** Pantry and shopping rows are hidden immediately on delete/tick (`hiddenIds`), and only un-hidden when the id disappears from the listener. If the write fails the item stays invisible until relaunch. (`PantryView.swift:115`, `ShoppingListView.swift:208,215`) |
| U5 | 🟡 | `RecipeDetailView.swift` is ~570 lines and duplicates the whole add-recipe form from `AddRecipeView.swift`. The quick-add row + tap-to-focus spacer is copy-pasted 4× (Pantry, Shopping, AddRecipe, Detail edit form). |
| U6 | 🟡 | Dead code: `AddRecipeView.editingRecipeId` / `onSave` (editing moved inline into the detail view); `RecipeListViewModel.init(editing:)` used only by a test. |
| U7 | 🟡 | Sorting by title uses `<` (case-sensitive: "apple pie" sorts after "Zucchini"). (`RecipieListView.swift:121,127`, `ShoppingListView.swift:116`) |
| U8 | 🟡 | Shopping "Group by Recipe" keys sections by recipe **title** — two recipes with the same title merge. (`ShoppingListView.swift:101,104`) |
| U9 | 🟡 | "Pantry match" sort ranks by absolute matched count, so a 10-ingredient recipe with 5 matches outranks a 2-ingredient recipe you can cook right now. |
| U10 | 🟡 | Deprecated APIs: `@Environment(\.presentationMode)` (AddRecipeView, RecipeDetailView), `.navigationBarItems` (AddRecipeView:34), `NavigationView`. |
| U11 | 🟡 | Filename typo `RecipieListView.swift` (type is `RecipeListScreen`). `RecipeListViewModel` is really the recipe *form* view model. |
| U12 | 🟡 | Splash says "Recipe App" (`SplashScreenView.swift:14`). |

### 3.5 Project hygiene

| # | Sev | Finding |
|---|---|---|
| H1 | 🟠 | `Package.resolved` is gitignored (`.gitignore:13`) — builds aren't reproducible; CI and other machines can resolve different Firebase versions. For an app (not a library) it should be committed. |
| H2 | 🟠 | No shared Xcode scheme (`FoodPlanner.xcodeproj/xcshareddata/xcschemes/` doesn't exist) — CI relies on scheme autogeneration. |
| H3 | 🟡 | Core Data template is dead weight: `Persistence.swift` (with `fatalError`s and a template `Item` entity), `FoodPlanner.xcdatamodeld`, `managedObjectContext` injection at `FoodPlannerApp.swift:88,107`. |
| H4 | 🟡 | Unused: `FirebaseStorage` package product (until photos feature), `AppUser` (`Models/UserItem.swift`), `UIApplication.endEditing` (`Helpers/Helpers.swift`), placeholder `FoodPlannerTests/FoodPlannerTests.swift`. |
| H5 | 🟡 | `FoodPlanner.entitlements` contains **macOS** sandbox keys (`com.apple.security.app-sandbox`, `files.user-selected.read-only`) that mean nothing on iOS. |
| H6 | 🟡 | `AppIcon.appiconset` has no image. Bundle ID is `Callum.FoodPlanner` (valid, but changing it later means re-registering the Firebase iOS app). |
| H7 | 🟡 | Swift 5 language mode, no strict concurrency checking. |

### 3.7 Repository, licensing & standards (the repo is public)

| # | Sev | Finding |
|---|---|---|
| R1 | 🔴 | **No licence.** With no `LICENSE`, the code is "all rights reserved" by default. That's legally fine, but readers can't tell whether it was deliberate, and nothing states who holds the copyright. |
| R2 | 🔴 | **`GoogleService-Info.plist` is in the public git history.** It was added in `e04ad85` and deleted in `d4a87d5`, but deleting a file doesn't remove it from history. Firebase iOS config values are identifiers rather than true secrets, but together with permissive Firestore rules (S1) they're everything an attacker needs to read or write the database directly. Rewriting history doesn't help once a public repo has been cloned or cached; mitigate on the backend instead (Task R.2). |
| R3 | 🟠 | **No README.** For a portfolio piece this is the first (often only) thing a reviewer reads. |
| R4 | 🟠 | No `SECURITY.md`, no private vulnerability reporting, no secret-scanning push protection, no branch protection, no Dependabot, no CodeQL. |
| R5 | 🟠 | Commits made from the Mac use a **misspelled author email**, so they aren't linked to the GitHub account. They don't show on the contribution graph or as authored by the profile, which undercuts the portfolio purpose. |
| R6 | 🟡 | Ten files carry Xcode's `// Created by …` template headers, several with the **wrong filename** (`IngredientItem.swift` says `NewIngredient.swift`, `RecipeItem.swift` says `NewRecipie.swift`). |
| R7 | 🟡 | No formatter or linter config, no `.editorconfig`, no single entry point for common commands. |
| R8 | 🟡 | No third-party licence attribution. The Firebase iOS SDK and its transitive packages (Apache-2.0, BSD, MIT, zlib, ISC/OpenSSL…) require their notices to be reproduced when the app is distributed. |
| R9 | 🟡 | No decision log, no changelog, no release tags. |

### 3.6 Testing

| # | Sev | Finding |
|---|---|---|
| T1 | 🟠 | Nothing tests Firestore reads/writes, parsing, or rules. All signed-in UI flows are untested. |
| T2 | 🟡 | `test_invalidLoginShowsError` hits production Firebase Auth — flaky offline, and pollutes rate limits. |

---

## 4. Decisions (defaults chosen)

The implementer should proceed with these defaults. Callum can override any of them by editing this section before the relevant phase starts.

| ID | Decision | Default |
|---|---|---|
| DEC-1 | Keep existing Firestore data through the schema change? | **Resolved 2026-10-09: No.** Nothing worth keeping, so no migration (task 1.6 skipped); delete the old data in the console. |
| DEC-2 | What does "shared" mean? | **Public to every signed-in user of the app** (current behaviour). Friends/groups sharing is out of scope. |
| DEC-3 | Fate of the global `/Ingredients` collection | **Retire it** (resolved 2026-10-09). Ingredient names are stored inline; attributes such as nutrition go in a future read-only, owner-written `Catalogue/{ingredientKey}` collection joined on `IngredientKey`. |
| DEC-4 | Ingredient identity | **Normalised name key** (Appendix C): trimmed, whitespace-collapsed, case- and diacritic-insensitive. Plurals ("egg" vs "eggs") are **not** merged (future work). |
| DEC-5 | "Pantry match" ordering | **Fewest missing ingredients first**, then higher match ratio, then name (A→Z, localized). |
| DEC-6 | Account entry point after nav refactor | **Gear button in each tab's toolbar opens Account as a sheet.** |
| DEC-7 | Bundle ID | **Decide before Phase 5.** Recommendation: `com.callumjones.foodplanner` (or keep `Callum.FoodPlanner` — it's valid). Changing it requires registering a new iOS app in Firebase and replacing `GoogleService-Info.plist`. **[Callum]** |
| DEC-8 | Week start for meal planner | **Monday** (UK). |
| DEC-9 | Units | **Metric-first**, free-text unit allowed; known units normalised (Appendix E). |
| DEC-10 | Licence | **All rights reserved, source visible for evaluation** (Appendix H.1). This repo deliberately differs from WingLog's GPL-3.0. Callum's goal here is ownership plus a portfolio, not reuse. The app is headed for the App Store, where GPL terms are widely considered incompatible with Apple's distribution terms for anyone redistributing. And there's no outside contribution to protect. If Callum later wants it open-source, GPL-3.0 + `COPYRIGHT` as in WingLog, or MIT, are drop-in swaps. **[Callum to confirm]** |
| DEC-11 | Outside contributions | **Not accepted** (issues welcome). That keeps sole copyright simple and avoids WingLog's inbound-MIT arrangement, which only matters for an open-source licence. |
| DEC-12 | Where development docs live | **In this public repo**, under `docs/` (plan, decision log). This also differs from WingLog, which keeps them in a private repo: for a portfolio, visible planning and decision records are part of what's being shown. Nothing secret goes in them (security rules for docs are in Appendix G). |
| DEC-13 | Branching | **Trunk-based.** Protected `main` (PR + green CI required, admins included); short-lived `feature/<name>` and `fix/<name>` branches. Add a `develop` branch only if TestFlight releases become frequent enough to need batching. One person on one codebase doesn't need WingLog's three-branch model yet. |
| DEC-14 | Formatting / lint tooling | **Apple's `swift-format`** (ships with Xcode 16+, so no extra dependency) for both formatting and linting. Add SwiftLint later only if a rule is needed that swift-format lacks. |

---

## 5. Phases

### 5.0 Order and dependencies

```
Phase R  Repository foundations (licence, security settings, README, standards, CI) — START HERE
   │       R.1–R.4 first (public-repo exposure); R.5+ alongside Phase 0–1
   ▼
Phase 0  Housekeeping ──────────────┐
Phase 1  Data layer v2 ─────────────┼─► Phase 2 Security rules ─► Phase 5 Release readiness ─► TestFlight
Phase 3  Auth & account (needs 1.x for 3.5 deletion) ──┘                    ▲
Phase 4  UI structure & polish (after 1) ──────────────────────────────────┘
Phase 6  Features (after 1, 4) ─► Phase 7 Meal planner
Phase 8  CI & test infra — 8.1 can start any time; 8.3+ after 1
```

Phases 0, 3.1–3.4 and 8.1 can run in parallel with Phase 1. Everything else waits for Phase 1 to merge.

---

### Phase R — Repository foundations: licence, security, presentation, standards

**Why first:** the repo is already public, with no licence, no security settings and the Firebase config in its history. It's also meant to work as a portfolio piece, so the README and visible engineering standards matter as much as the code. Most of these tasks are docs and config, so they're **[cloud-ok]** unless tagged otherwise.

The model is the WingLog repo's setup, **adapted rather than copied**. Each task notes where and why FoodPlanner differs.

#### R-A: Ownership & licensing

- [x] **R.1 Licence + copyright** [cloud-ok] (R1, DEC-10, DEC-11)
  - `LICENSE`: the all-rights-reserved text in **Appendix H.1**. It's short and plain-English; don't use an invented "source-available" licence with clauses that conflict with GitHub's terms.
  - `COPYRIGHT`: one line of notice (`Copyright © 2025–2026 Callum Jones. All rights reserved.`) plus a short "why this file exists" note, the third-party pointer, and the trademark disclaimer (Appendix H.2). As in WingLog, `COPYRIGHT` and `LICENSE` are the authoritative statement, so there are **no per-file headers**.
  - `CONTRIBUTING.md`: short and specific to this repo. It's a personal portfolio project, issues and suggestions are welcome, and pull requests aren't accepted because the code isn't open-licensed (link `LICENSE`). Point at `CLAUDE.md` as the working agreement. Don't copy WingLog's inbound-MIT section: it exists to protect a GPL dual-licence, which this repo doesn't have.
  - ✅ GitHub's sidebar shows the licence as "Other" (expected for a custom all-rights-reserved file); the README licence section links both files.
- [x] **R.2 Contain the leaked Firebase config** 🔴 [Callum] (R2)
  - Google Cloud console ▸ APIs & Services ▸ Credentials ▸ the iOS API key: add an **iOS app restriction** (bundle ID) and an **API restriction** limiting it to the APIs Firebase actually uses (Identity Toolkit, Token Service, Cloud Firestore, Firebase Installations, Firebase App Check, Cloud Storage for Firebase once 6.3 lands).
  - Ship Phase 2 (security rules) as the first code change after Phase 1. Until then, consider pulling Phase 2 forward with a stop-gap owner-only ruleset (Appendix B without validation) so the exposed config can't be used against other users' data.
  - Check the repo's Security tab for an existing secret-scanning alert on the old commit. Close it as "revoked/mitigated" with a note once the key is restricted.
  - Don't rewrite history (forks and caches already have it); the key restrictions plus security rules are the real fix. Record this in the decision log (R.8).
  - Plan App Check (5.4) for before public TestFlight.
- [x] **R.3 Strip template file headers** [Mac] (R6) — Remove the `//\n//  X.swift\n//  FoodPlanner\n//\n//  Created by …\n//` blocks from all 10 files. Add `FoodPlanner.xcodeproj/xcshareddata/IDETemplateMacros.plist` with an empty `FILEHEADER` so Xcode stops generating them for new files. ✅ `grep -rn "Created by" FoodPlanner*` is empty.
- [x] **R.4 Fix commit identity** [Callum] (R5) — `git config --global user.email` → the GitHub **noreply** address (`<id>+Catalyst4K@users.noreply.github.com`, under GitHub ▸ Settings ▸ Emails), which keeps a real email out of public history. Also enable "Block command line pushes that expose my email". Add a `.mailmap` mapping the misspelled address to the canonical identity so `git log`/`shortlog` read correctly. GitHub's contribution graph doesn't use `.mailmap`, so past commits stay unlinked; accept that rather than rewriting public history.

#### R-B: GitHub security settings

- [x] **R.5 `SECURITY.md`** [cloud-ok] — Written for *this* app's real risk surface, not WingLog's (no SimConnect, no local files; instead accounts and a cloud backend). Include:
  - Reporting via GitHub private vulnerability reporting, not public issues; best-effort solo response time; no bounty.
  - **In scope:** Firestore/Storage security rules (reading or modifying another user's data, bypassing validation, reading unshared recipes); auth flows (account takeover, account-deletion leaving data behind); shared-recipe content able to do anything beyond being displayed as text; a leaked credential in the repo or its history; the app's dependency supply chain.
  - **Out of scope:** the public Firebase iOS config itself (it's an identifier, protected by key restrictions, rules and App Check; explain this so nobody reports it in good faith); vulnerabilities in Firebase, iOS or Google Cloud themselves; attacks that need an unlocked device; missing hardening with no demonstrated impact.
  - Supported versions: latest TestFlight / App Store build and `main`.
- [x] **R.6 `scripts/github-repo-security.sh`** [cloud-ok to write, Callum to run] — An idempotent `gh api` script, as in WingLog, so the settings live in the repo rather than as one-off console clicks. **Default `REPO` must be `Catalyst4K/FoodPlanner`.** WingLog's copy defaults to `Catalyst4K/flightdeck`, so don't carry that over. Applies:
  - Dependabot alerts + automated security fixes; secret scanning + **push protection**; private vulnerability reporting.
  - Branch protection on `main` per DEC-13: PR required (0 approvals), required checks = the CI job names from R.10 (`build-test`, `rules`), `enforce_admins: true`, no force-push, no deletion.
  - `delete_branch_on_merge: true`. Disable Wiki and Projects if unused.
  - Repo metadata: description, homepage (the GitHub Pages privacy page from 5.3 once it exists), topics (`ios`, `swift`, `swiftui`, `firebase`, `firestore`, `swift-concurrency`, `portfolio`).
  - Prints the resulting state at the end. Only enable the branch-protection part once R.10's checks exist and have passed at least once; required checks that never report would block every merge.
- [x] **R.7 `.github/dependabot.yml`** [cloud-ok] — `github-actions` (monthly) and `npm` in `/firebase` (weekly, grouped minor+patch, majors separate). For Swift packages, add the `swift` ecosystem, then **verify it actually raises PRs for an Xcode-project-embedded `Package.resolved`**. Its support for `.xcodeproj` (as opposed to `Package.swift`) is limited. If it doesn't, drop the entry and add a monthly "check Firebase SDK releases" note to `CLAUDE.md`'s dependency rule instead. Commit prefixes `deps:` / `ci:`.

#### R-C: Standards (the working agreement)

- [x] **R.8 Decision log + changelog** [cloud-ok] (R9)
  - `docs/decisions.md`: dated entries (`## YYYY-MM-DD — Title`, then context, decision, consequences). Backfill DEC-1…DEC-14 from §4 of this plan, plus the R.2 history decision. From now on, any decision that changes architecture, data leaving the device, dependencies, or licensing gets an entry **before** it's built.
  - `CHANGELOG.md` in Keep a Changelog format, starting at `0.1.0` for the current state. Tag releases `v<marketing>+<build>` (e.g. `v1.0.0+3`) when a build goes to TestFlight.
- [x] **R.9 Rewrite `CLAUDE.md` as the working agreement** [cloud-ok] — Keep the existing architecture content (updated as Phase 1 lands) and add **Rules**, **Security** and **Testing** sections from **Appendix G**. These are written for a SwiftUI + Firebase app, not translated line by line from WingLog. They also apply to human contributors; say so.
- [x] **R.10 Tooling & single entry point** [Mac] (R7, DEC-14)
  - `.swift-format` at the root: 4-space indent, 120 line length, and the opt-in rules `NeverForceUnwrap`, `NeverUseForceTry` and `NeverUseImplicitlyUnwrappedOptionals` turned on. Tests may relax them: give `FoodPlannerTests/` and `FoodPlannerUITests/` their own nested `.swift-format` with those three set to `false`. Run `swift format --in-place --recursive FoodPlanner FoodPlannerTests FoodPlannerUITests` once **in its own commit** (pure formatting, nothing else), and list that commit's SHA in `.git-blame-ignore-revs` so `git blame` skips it.
  - `.editorconfig` (Swift 4 spaces, YAML/JSON 2 spaces, LF line endings, final newline).
  - `Makefile` as the single command entry point, referenced from the README and `CLAUDE.md`. iOS projects have no `package.json`, so this plays that role: `make format`, `make lint` (`swift format lint --strict --recursive …`), `make build`, `make test` (unit), `make test-ui`, `make coverage` (unit with coverage, then the ratchet check), `make emulators`, `make rules-test`, `make licenses`, `make check` (the full checkpoint battery: lint + build with warnings as errors + unit + coverage + rules). The simulator is a variable defaulting to one that exists on Xcode 26.
  - `.gitignore` hardening: add `xcuserdata/`, `node_modules/`, `.firebase/`, `firebase-debug*.log`, `firestore-debug.log`, `ui-debug.log`, `*.p8`, `*.p12`, `*.mobileprovision`, `*.cer`, `AuthKey_*.p8`, `.env`, `*-service-account*.json`, `/build-output/`, `*.xcresult`. Remove `Package.resolved` (Task 0.5).
- [x] **R.11 CI** _(done: `lint`, `build-test` with coverage ratchet and licence check, `rules`, CodeQL, and a `ui` job that runs on pushes to `main` and on demand rather than on every PR)_ [cloud-ok to write; Callum adds nothing — no secrets needed] — Replaces 8.1/8.2.
  - **No secrets in CI at all.** Commit `ci/GoogleService-Info.plist` with obviously fake values pointing at the emulator project `demo-foodplanner`. Use a value for `API_KEY` that does *not* match Google's `AIza…` key pattern, or push protection will block it; confirm `FirebaseApp.configure()` accepts it. CI copies it into `FoodPlanner/` before building. Fork PRs can then run everything safely, and there's nothing to leak.
  - `.github/workflows/ci.yml`, on push to `main` and on PRs:
    - `lint` (macOS): `make lint`.
    - `build-test` (macOS, latest image with Xcode 26): build with `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`; unit tests with `-enableCodeCoverage YES`; coverage ratchet (R.13); upload the `.xcresult` as an artifact on failure. Cache SPM checkouts keyed on `Package.resolved`.
    - `rules` (Ubuntu): Node 22 + Java 21, `npm ci` in `firebase/`, `firebase emulators:exec --project demo-foodplanner --only firestore,storage "npm test"`.
    - `ui` (macOS, after 8.3/8.4 exist): start the emulators, run XCUITests against them. Start it as non-required; make it required once it's been green for a couple of weeks.
  - `.github/workflows/codeql.yml`: languages **`swift`** (macOS, `build-mode: manual` running the same `xcodebuild build`) and **`actions`** (scans the workflows themselves for injection mistakes), plus `javascript-typescript` for `firebase/`. Use `queries: security-extended`, weekly schedule plus push/PR to `main`, least-privilege `permissions`.
  - All workflows: top-level `permissions: contents: read`; pin third-party actions to a full commit SHA (with a `# vX.Y` comment, so Dependabot still updates them); never use `pull_request_target`.
  - Add CI and CodeQL badges to the README.
- [x] **R.12 PR template** [cloud-ok] — `.github/pull_request_template.md` (this repo will be worked on by agent sessions, so make it a checklist they fill in): Summary · Linked plan task (e.g. "Phase 1.4") · Test layers touched (unit / integration / rules / UI — at least one, or why none) · Security checklist (no secrets or real user data in fixtures; rules and rules tests updated if a Firestore path changed; user content rendered as plain text) · Built and tested on Xcode? (yes/no; cloud sessions must say no) · Screenshots for UI changes (light + dark).
- [x] **R.13 Coverage ratchet** [Mac] — `scripts/check-coverage.sh` reads `xcrun xccov view --report --json` from the test `.xcresult`. It computes line coverage for **business logic only**: `FoodPlanner/Models/**` and `FoodPlanner/ViewModels/**`, excluding `DataManager.swift`'s Firestore plumbing until integration tests (8.5) cover it. Compare against the number in `.coverage-threshold` and fail if lower. The threshold only ever goes up: raise it in the same PR that raises coverage, and never lower it to make a build green. The target for pure logic is effectively 100%; Views are excluded and covered by UI tests instead.

#### R-D: Presentation (portfolio)

- [x] **R.14 README** [cloud-ok for text; Mac for screenshots] (R3) — Structure in **Appendix H.3**. It's written for two readers: a reviewer evaluating Callum's iOS skills (lead with what the app does, then **Engineering highlights**, which link to the actual code that demonstrates each point) and a developer who wants to build it (which, thanks to R.11 + 8.3, needs no Firebase account at all). Keep claims factual and verifiable: only list a highlight once the code for it has merged, and grow the section as phases land.
- [x] **R.15 Screenshots** _(done for portrait, light and dark; the landscape recipe-detail shot isn't automated: `XCUIDevice` rotation leaves the app in its portrait layout in the simulator, although rotating by hand works. Revisit if it matters.)_ [Mac] — An XCUITest class `ScreenshotTests` behind a `-screenshots` launch argument. It runs against the emulator seeded with a fixed demo account (realistic, made-up recipes; no real personal data). It captures Recipes, Recipe detail (portrait + landscape), Pantry, Shopping (grouped), and later Plan, in light and dark, saving PNGs to `docs/screenshots/` through `make screenshots`. Re-run it before each release so the README never shows a stale UI. These images can also serve as the App Store screenshots.
- [x] **R.16 Third-party licences** [Mac] (R8) — `scripts/generate-third-party-licenses.sh` (`make licenses`) reads `Package.resolved` for the exact pins. It then reads each package's `LICENSE`/`NOTICE` from Xcode's SourcePackages checkout and writes:
  - `THIRD-PARTY-LICENSES.md` at the repo root: one section per package with name, version, licence (SPDX) and full text, and Apache `NOTICE` text where present. Header: "generated — don't edit".
  - `FoodPlanner/Resources/Acknowledgements.json`, which a new **Account ▸ Acknowledgements** screen renders. Apache-2.0 requires the notices to ship *with* the app, not just in the repo.
  - CI (`build-test`) regenerates and fails if either file is out of date relative to `Package.resolved`.
  - Rule for `CLAUDE.md`: new dependencies must be MIT, BSD, Apache-2.0, zlib, ISC or similarly permissive. **No GPL/AGPL/LGPL** (App Store distribution plus the all-rights-reserved licence).
- [x] **R.17 Privacy manifest** [Mac] — Add `FoodPlanner/PrivacyInfo.xcprivacy`, required for App Store submission since 2024. Declare `NSPrivacyTracking = false`, the collected data types (email address and other user content, linked to the user, for app functionality, not for tracking), and required-reason API usage (`NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1`, since `@AppStorage` is used from 4.2). Firebase's own SDKs ship their own manifests. The privacy policy (5.3), App Privacy labels, this manifest and the README's "Data & privacy" table must agree, so update all four together.

---

### Phase 0 — Housekeeping (low risk, do first to prove the build loop)

- [x] **0.1 Remove Core Data template** [Mac]
  - Delete `FoodPlanner/Persistence.swift` and `FoodPlanner/FoodPlanner.xcdatamodeld/`.
  - In `FoodPlannerApp.swift` remove `persistenceController` (L88) and the `.environment(\.managedObjectContext, …)` modifier (L107).
  - Remove the "Core Data is present but effectively unused" paragraph from `CLAUDE.md`.
  - ✅ App builds, launches, all unit tests pass.

- [x] **0.2 Remove dead code** [Mac]
  - Delete `Models/UserItem.swift` (`AppUser` — unused), `Helpers/Helpers.swift` (`endEditing` — unused; the keyboard-dismiss gesture uses `UIView.endEditing` directly), `FoodPlannerTests/FoodPlannerTests.swift` (placeholder).
  - In `AddRecipeView.swift` remove `editingRecipeId`, `onSave`, `isEditing` and the edit branches (`navigationTitle`, `actionLabel`, `actionIcon`, the `if let editingRecipeId` in `submit()`).
  - Leave `FirebaseStorage` linked (Phase 6.3 uses it).
  - ✅ `grep -rn "editingRecipeId\|onSave\|AppUser\|endEditing()" FoodPlanner` returns nothing except `UIView.endEditing` in `FoodPlannerApp.swift`.

- [x] **0.3 Fix entitlements** [Mac] — Replace `FoodPlanner/FoodPlanner.entitlements` contents with an empty `<dict/>` (keep the file — push notifications / Sign in with Apple may need it later). ✅ Builds and runs on a device.

- [x] **0.4 Rename for clarity** [Mac]
  - `Views/RecipieListView.swift` → `Views/RecipeListScreen.swift`.
  - `RecipeListViewModel` → `RecipeFormViewModel` (type + file `ViewModels/RecipeFormViewModel.swift` + test file `FoodPlannerTests/RecipeFormViewModelTests.swift` + all references + `CLAUDE.md`).
  - ✅ `grep -rn "RecipeListViewModel\|RecipieListView" .` returns nothing.

- [x] **0.5 Reproducible builds** [Callum]
  - Remove `Package.resolved` from `.gitignore`; commit `FoodPlanner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.
  - Xcode ▸ Product ▸ Scheme ▸ Manage Schemes ▸ tick **Shared** for `FoodPlanner`; commit `FoodPlanner.xcodeproj/xcshareddata/xcschemes/FoodPlanner.xcscheme`.
  - Update the simulator name in `CLAUDE.md` commands to one that exists on the installed Xcode.

- [ ] **0.6 Export current Firestore rules + indexes** [Callum] — Copy the live rules from Firebase console ▸ Firestore ▸ Rules into an issue/PR comment so Phase 2 knows the starting point. Check whether they're permissive (S1). If they are `allow read, write: if request.auth != null;` or looser, **prioritise Phase 2 immediately after Phase 1.**

---

### Phase 1 — Data layer v2 (biggest and most important)

**Goal:** inline ingredient names on recipe docs, deterministic doc IDs for pantry/shopping, atomic writes, main-actor isolation, consistent name matching, with a one-time migration from v1. Full target schema: **Appendix A**.

Split into these PRs, in order. 1.1–1.3 add pure, tested building blocks; 1.4–1.5 switch `DataManager` over; 1.6 migrates data; 1.7 updates docs.

- [x] **1.1 `IngredientKey` normalisation** [Mac for tests; code is cloud-ok]
  - New file `FoodPlanner/Models/IngredientKey.swift` (Foundation-only). Implements Appendix C: `IngredientKey.normalized(_:)` and `IngredientKey.documentID(for:)`.
  - New tests `FoodPlannerTests/IngredientKeyTests.swift` covering every rule in Appendix C (case, whitespace, diacritics, `/`, `%`, `.`/`..`, `__x__`, empty input, long input).
  - Switch the five static matchers in `DataManager` (L615–647) and `RecipeFormViewModel.addIngredient` dedupe to compare `IngredientKey.normalized` instead of `lowercased()`. Add tests: "Olive  Oil " matches "olive oil"; "Jalapeño" matches "jalapeno".
  - ✅ All existing + new tests pass.

- [x] **1.2 Firestore ↔ model mapping as pure functions** [Mac]
  - New file `FoodPlanner/Models/FirestoreMapping.swift` (Foundation-only — no `Timestamp`/`DocumentReference` types). Provides:
    - `static func recipe(from data: [String: Any], id: String, fallbackOwnerId: String) -> Recipe?` — returns nil if `Name` or `Ingredients` missing/wrong type (that's how v1 docs are detected and skipped).
    - `static func recipeFields(_ recipe: Recipe) -> [String: Any]` — `Name`, `Instructions`, `Ingredients` (array of maps per Appendix A). Excludes `OwnerId`/`IsShared`/timestamps (DataManager adds those).
    - `static func listItem(from data: [String: Any], id: String) -> IngredientItem?` for pantry/shopping docs.
  - `IngredientItem.id` semantics change: for pantry/shopping it's the doc ID (= `IngredientKey.documentID`); for recipe ingredients it's `IngredientKey.documentID(for: name)`. Document this on the struct. Remove the now-unused `IngredientItem.from(dictionary:id:)`.
  - Add `servings: Int?` to `Recipe` now (optional, unused by UI until 6.1) so the schema doesn't churn twice.
  - Tests `FoodPlannerTests/FirestoreMappingTests.swift`: round-trip recipe with/without quantity/unit, order preserved, malformed data → nil, v1-shaped doc (no `Ingredients`) → nil, `OwnerId` fallback.

- [x] **1.3 Make `DataManager` `@MainActor`** [Mac]
  - Annotate `DataManager` with `@MainActor`. Remove now-redundant `await MainActor.run` / `@MainActor` on `report`/`clearError`. Firestore listener callbacks are delivered on the main queue; wrap their bodies in `MainActor.assumeIsolated { … }` if the compiler requires it.
  - `deinit`: cancel the fetch tasks too (D10) — or, after 1.4, delete them entirely.
  - Same for `AuthViewModel` (A5) — mark `@MainActor`.
  - ✅ Builds with no new warnings; app behaves identically.

- [x] **1.4 Switch recipes to inline ingredients** [Mac]
  - Rewrite `listenToUserRecipes`/`listenToSharedRecipes` to parse synchronously with `FirestoreMapping.recipe(from:…)`. No per-recipe `Task`, no subcollection fetch, no task groups. Keep the `CreatedAt` `.estimate` sort. With no async hydration, the fetch-task cancellation machinery (`userRecipesFetchTask`, `sharedRecipesFetchTask`) is deleted.
  - `addRecipe`: one `setData` with `recipeFields` + `OwnerId`, `IsShared: false`, `CreatedAt: serverTimestamp()`, `UpdatedAt: serverTimestamp()`. Return/propagate errors (see 1.5 for the error convention).
  - `updateRecipe`: one `updateData` with `recipeFields` + `UpdatedAt`. Atomic (D2 fixed).
  - `deleteRecipe`: delete the doc; if a legacy `Ingredients` subcollection exists, delete it in a `WriteBatch` first (keep until migration has run everywhere).
  - `toggleShareRecipe(recipeId:)` → `setShared(recipeId:isShared:)` taking the desired value; single `updateData` (D9).
  - `saveSharedRecipeToMyList`: also write `SourceRecipePath` (the shared recipe's `/Users/{owner}/Recipes/{id}` path) for attribution later.
  - Shared query: add `.order(by: "CreatedAt", descending: true).limit(to: 200)` (D11). This needs a new composite **collection-group** index `IsShared ASC, CreatedAt DESC` — add it to `firestore.indexes.json` in Phase 2 and tell Callum to create it (the console link appears in the error banner).
  - Delete: `buildRecipes`, `parseRecipeDoc`, `fetchRecipeIngredients`, `fetchIngredientsPreservingOrder`, `resolveIngredientsPreservingOrder`.
  - ✅ Add/edit/delete/share/save-shared all work; one listener fire per write; recipe ingredient order preserved; no reads besides the listeners.

- [x] **1.5 Switch pantry + shopping list to keyed docs** [Mac]
  - Doc ID = `IngredientKey.documentID(for: name)`; fields per Appendix A. Parse synchronously with `FirestoreMapping.listItem`. Delete `pantryFetchTask`/`shoppingFetchTask`, `fetchIngredients`, `fetchIngredient`, `addUniqueIngredient`, the `ref:` overloads.
  - `addToPantry(name:)` / `addToShoppingList(name:)`: `setData` on the keyed doc (idempotent — D3 fixed). Skip the write if the key is already present locally (avoids resetting `CreatedAt`, which would move the row).
  - `removeFromPantry(id:)` / `removeFromShoppingList(id:)`: `delete()` the keyed doc. No query.
  - `moveShoppingItemToPantry`: one `WriteBatch` — set pantry doc, delete shopping doc (D6 fixed).
  - `addMissingIngredientsToShoppingList`: keep the batch + strictly increasing client timestamps; use keyed doc IDs.
  - `togglePantry` / `toggleShoppingList`: membership by key.
  - **Error convention:** mutating methods become `async throws` *or* return `Bool`; pick `Bool` (`@discardableResult`) to keep call sites simple. They still call `report(...)` on failure so the banner shows. Views use the result to roll back optimistic UI (U4 — done in 4.6).
  - All listeners call `report(error, context:)` on error (D7).
  - Update `CLAUDE.md` "Firestore schema", "Listener/fetch-task race handling" and "Write ordering" sections — the latter two no longer apply; replace with: "Listeners parse synchronously; every multi-doc write uses a `WriteBatch`."
  - ✅ Rapidly adding the same item twice (or from two devices) produces one row. Ticking an item moves it atomically. Unit tests still pass.

- [x] **1.6 One-time v1 → v2 migration** _(skipped: DEC-1 resolved as "no migration", see `docs/decisions.md` 2026-10-09)_ [Mac]
  - New file `FoodPlanner/Models/LegacyMigrator.swift`, called once from `DataManager.init` (fire-and-forget `Task`) after listeners are attached.
  - Guard: read `/Users/{uid}`; if `SchemaVersion >= 2`, return.
  - Steps (each idempotent, so an interrupted run is safe to repeat):
    1. **Recipes:** for each `/Users/{uid}/Recipes/*` doc without an `Ingredients` array field: read its `Ingredients` subcollection sorted by `Order` (legacy docs without `Order` last, then doc ID), resolve each `Ref` to its `/Ingredients` `Name`, then in one `WriteBatch`: `updateData` the recipe with the `Ingredients` array (+ `UpdatedAt`) **and** delete each subcollection doc.
    2. **Pantry / ShoppingList:** for each doc with an `Ingredient` ref and no `Name`: resolve the name; batch: `setData` at the keyed ID (`Name`, keep old `CreatedAt` if present), delete the old doc if its ID differs. If two legacy docs resolve to the same key, the second just overwrites — that's the desired dedupe.
    3. `setData(["SchemaVersion": 2], merge: true)` on `/Users/{uid}`.
  - Legacy docs are invisible to the new listeners until migrated (mapping returns nil) — acceptable; they appear seconds later when the batch lands.
  - Shared recipes owned by **other** users that are still v1 won't show until their owner runs the new build. Acceptable (dev-only data).
  - Log a summary (`print`) of migrated counts. Remove `LegacyMigrator` in a later release once all accounts are migrated (add a TODO with the date).
  - ✅ Test manually on a copy: create v1 data with the old build, install the new build, verify recipes/pantry/shopping all appear with correct order and no duplicates, then relaunch and confirm the migrator exits early.

- [x] **1.7 Docs** — Update `CLAUDE.md` (schema, listener pattern, testable core now includes `IngredientKey` + `FirestoreMapping`). Tick boxes in this file.

---

### Phase 2 — Security rules, indexes, rules tests [cloud-ok]

This phase is fully doable in a Linux container (Node 22 + Java 21 present; the Firebase emulator jar downloads from `storage.googleapis.com` — if the network policy blocks it, write the tests and mark them for Callum/CI to run).

- [x] **2.1 Firebase project config** _(lives in `firebase/`: `firebase.json`, `.firebaserc`, `firestore.rules`, `firestore.indexes.json`)_
  - `firebase.json` → `{ "firestore": { "rules": "firestore.rules", "indexes": "firestore.indexes.json" }, "emulators": { "firestore": { "port": 8080 }, "auth": { "port": 9099 }, "ui": { "enabled": false } } }`
  - `.firebaserc` → `{ "projects": { "default": "<project-id>" } }` — project ID is in `GoogleService-Info.plist` (`PROJECT_ID`); **[Callum]** fills it in (don't guess).
  - `firestore.rules` — start from **Appendix B**.
  - `firestore.indexes.json` — collection-group index on `Recipes`: `IsShared ASC, CreatedAt DESC` (+ the existing `IsShared` single-field collection-group exemption if the console shows one).
- [x] **2.2 Rules unit tests** in `firebase/` (`package.json`, `vitest` or `mocha`, `@firebase/rules-unit-testing`, `firebase-tools` as devDependency). Cover at minimum:
  - Owner can CRUD own recipes / pantry / shopping / meal plan / user doc.
  - Another signed-in user **cannot** read unshared recipes, **can** read shared recipes (direct get and collection-group query with `IsShared == true`), **cannot** write/delete anyone else's anything.
  - Unauthenticated: everything denied.
  - Validation: recipe with `OwnerId != uid` denied; changing `OwnerId` on update denied; > 100 ingredients denied; non-string `Name` denied; extra unknown top-level fields denied.
  - Legacy `/Ingredients` readable by signed-in users, not writable.
  - Run with `npx firebase emulators:exec --only firestore "npm test"`.
- [ ] **2.3 Deploy** [Callum] — `npx firebase deploy --only firestore:rules,firestore:indexes` after Phase 1 is live on Callum's device and the migration (1.6) has run on his account. Smoke-test the app afterwards (permission-denied errors will now surface in the banner thanks to D7).
- [x] **2.4 Document** in `CLAUDE.md`: rules live in `firestore.rules`, how to run rules tests, how to deploy.

---

### Phase 3 — Auth & account

- [x] **3.1 `AuthFailure` + friendly messages** [Mac]
  - New Foundation-only file `FoodPlanner/Models/AuthFailure.swift`: `enum AuthFailure: Equatable { case invalidCredentials, invalidEmail, emailInUse, weakPassword, network, tooManyRequests, requiresRecentLogin, userDisabled, unknown }` with `var message: String` (Appendix D).
  - Mapping from `AuthErrorCode` lives in `AuthViewModel` (`static func failure(from error: Error) -> AuthFailure`) — not unit-tested because it needs FirebaseAuth; the messages are.
  - Tests: every case has a non-empty, user-facing message.
- [x] **3.2 Modernise `AuthViewModel`** [Mac]
  - `@MainActor` (if not done in 1.3). Store the `AuthStateDidChangeListenerHandle` and remove it in `deinit`.
  - `func signIn(email:password:) async -> AuthFailure?`, `func signUp(email:password:) async -> AuthFailure?`, `func sendPasswordReset(email:) async -> AuthFailure?`, `func reauthenticate(password:) async -> AuthFailure?`, `func deleteAuthUser() async -> AuthFailure?` using Firebase's async APIs. Trim + lowercase the email before sending.
  - `@Published var isWorking = false` toggled around calls.
- [x] **3.3 Login & sign-up screens** [Mac]
  - Email fields: `.keyboardType(.emailAddress)`, `.textInputAutocapitalization(.never)`, `.autocorrectionDisabled()`, `.textContentType(.username)`. Password: `.textContentType(.password)` on login, `.textContentType(.newPassword)` on sign-up.
  - Sign-up: confirm-password field; client-side checks (valid-looking email, ≥ 6 chars, passwords match) with inline messages before calling Firebase.
  - Show `AuthFailure.message`; disable submit + show `ProgressView` while `isWorking`. Submit on keyboard return from the password field.
  - "Forgot password?" button on login → sheet with email field → `sendPasswordReset` → always show "If an account exists for that email, we've sent a reset link." (don't leak account existence).
  - Accessibility IDs: `signup.title`, `signup.email`, `signup.password`, `signup.confirmPassword`, `signup.submit`, `signup.error`, `login.error`, `login.forgotPassword`, `reset.email`, `reset.submit`.
  - Update `test_invalidLoginShowsError` to look for `login.error` rather than literal text; update `test_loginToSignupNavigation` to use `signup.title`.
- [x] **3.4 Account screen polish** [Mac] — Show email, app version (`CFBundleShortVersionString`), "Log Out" (with confirmation), links to privacy policy (placeholder URL constant until 5.3). IDs `account.email`, `account.logout`, `account.delete`.
- [x] **3.5 Account deletion** 🔴 [Mac] _(needs Phase 1)_
  - `DataManager.deleteAllUserData() async -> Bool`: for each of `Recipes` (plus any legacy `Ingredients` subcollections), `Pantry`, `ShoppingList`, `MealPlan` (if Phase 7 has landed): page through docs and delete in `WriteBatch`es of ≤ 450; then delete `/Users/{uid}`. (Photos in Storage too once 6.3 lands.)
  - Flow in `AccountView`: "Delete Account" (destructive, red) → confirmation dialog explaining it's permanent and deletes all recipes including shared ones → password sheet → `reauthenticate(password:)` → `deleteAllUserData()` → `deleteAuthUser()`. On success the auth listener flips to `LoginView`. On failure at any step show the message; if data deletion succeeded but auth deletion failed, the user can retry (data delete is idempotent).
  - Order matters: **re-auth first**, so a `requiresRecentLogin` failure can't strand an account with its data already gone.
  - ✅ Manual test: create account, add data, share a recipe, delete account → can't log in; data gone in console; shared recipe gone from another account's Shared tab.

---

### Phase 4 — UI structure & polish _(after Phase 1)_

- [ ] **4.1 Navigation restructure** [Mac] (U1, U10)
  - `MainTabView`: remove the outer `NavigationStack`. Use iOS 18+ `TabView(selection:)` with `Tab(…, value:)`; each tab's content is wrapped in **its own `NavigationStack`**. Remove every `NavigationView`.
  - Recipes tab uses value-based navigation: `NavigationLink(value: recipe.id)` + `.navigationDestination(for: String.self) { RecipeDetailView(recipeId: $0) }`. "Add Recipe" pushes via a separate destination value (e.g. an enum `RecipeRoute { case detail(String), add }`).
  - Each tab gets its own `.toolbar`: gear button (opens `AccountView` as a `.sheet`, DEC-6) and, where relevant, the sort menu (4.2).
  - Replace `presentationMode` with `@Environment(\.dismiss)`; `.navigationBarItems` with `.toolbar`.
  - `RecipeDetailView` takes a `recipeId` and reads the live recipe from `dataManager` (`userRecipes` then `sharedRecipes`) each render; keep a `@State` fallback copy (for the moment between delete and pop, and for the optimistic edit). **Then delete the `onReceive` syncing hack** (`syncFrom…`) — but only after verifying on device that edits reflect immediately on return from the edit form and when another device edits the recipe. If staleness reappears, keep the hack and note why in a comment.
  - Keep the rotation overlay and orientation locking unchanged.
  - Error banner stays as an overlay on the `TabView`.
  - ✅ One nav bar per screen; back gestures work; tab state is preserved when switching tabs; UI tests pass.
- [ ] **4.2 Native sort menus + typed options** [Mac] (U2, U7, U9)
  - `enum RecipeSort: String, CaseIterable, Identifiable { case pantryMatch, name, newest }` and `enum ShoppingSort: String, CaseIterable { case newest, byRecipe }` (add `.byAisle` in 6.4). Persist with `@AppStorage("recipeSort")` / `@AppStorage("shoppingSort")`.
  - Toolbar `Menu { Picker("Sort", selection: $sort) { … } } label: { Image(systemName: "arrow.up.arrow.down") }`. Delete `sortMenuOverlay`, `showSortMenu`, `applySort`.
  - New pure helper `DataManager.sortedRecipes(_:by:pantry:)` implementing DEC-5 for `.pantryMatch`, `localizedStandardCompare` for `.name`, and `CreatedAt` order (as delivered by the listener) for `.newest`. Replace `recipesSortedByPantryMatch` and update its test to the new ordering. Use `localizedStandardCompare` everywhere titles are sorted (shared list, shopping sections).
- [ ] **4.3 Extract shared form + components** [Mac] (U5)
  - `Views/Components/QuickAddRow.swift` — the "+ Add ingredient" text field row (binding text, focus binding, `onCommit`), including commit-on-focus-loss.
  - `Views/Components/TapToFocusSpacer.swift`.
  - `Views/Components/RecipeFormView.swift` — title, ingredient list, quick-add row, instructions editor; driven by a `RecipeFormViewModel`. Used by both `AddRecipeView` (push) and `RecipeDetailView` edit mode.
  - Split `RecipeDetailView` into `RecipeDetailView` (state, toolbar, layout switching) + `RecipeIngredientsSection` + `RecipeInstructionsSection` + `SharedRecipeBanner`. Target: no file > ~250 lines.
  - Use `QuickAddRow`/`TapToFocusSpacer` in Pantry and Shopping.
  - ✅ No visual change; behaviour identical.
- [x] **4.4 Dark mode** [Mac] (U3, U12) — Replace `Color.white` with `Color(.secondarySystemBackground)` for text editors, `Color(.systemBackground)` for splash. Splash text → "FoodPlanner". Audit every screen in dark mode (simulator: Features ▸ Toggle Appearance).
- [x] **4.5 Shopping grouping by recipe ID** [Mac] (U8) — Key sections by `recipe.id`, title for display; move the grouping into a pure static helper `DataManager.shoppingSections(items:recipes:)` returning a small `ShoppingSection` struct, with tests (multi-recipe bucket, per-recipe, other, same-title recipes stay separate, sort order).
- [x] **4.6 Roll back optimistic hides** [Mac] (U4) — In Pantry/Shopping, if the `Bool` result from the DataManager call is `false`, remove the id from `hiddenIds` with animation.
- [x] **4.7 Empty states** [Mac] — Pantry and Shopping list currently show nothing when empty; add `ContentUnavailableView` with a hint ("Add what's in your cupboards…").
- [ ] **4.8 Swift 6 / strict concurrency** [Mac] (H7) — Set `SWIFT_STRICT_CONCURRENCY = complete` (warnings), fix what's reasonable; then consider `SWIFT_VERSION = 6.0`. This is a build-setting change in `project.pbxproj` — do it via Xcode's Build Settings UI, not by hand. Separate PR; may be deferred.

---

### Phase 5 — Release readiness (TestFlight) _(after 1, 2, 3)_

- [ ] **5.1 App icon** [Callum] — Single 1024×1024 PNG in `AppIcon.appiconset` (Xcode 26 single-size icon; optionally dark/tinted variants via Icon Composer).
- [ ] **5.2 Identity** [Callum] — Resolve DEC-7 (bundle ID). Set display name: `INFOPLIST_KEY_CFBundleDisplayName = FoodPlanner` in Build Settings. Set version 1.0 build 1.
- [ ] **5.3 Privacy** [Callum] — Host a privacy policy. Simplest option: `docs/privacy.md` in this repo, published with GitHub Pages; that becomes the App Store privacy URL and the repo homepage (R.6). It should cover what's collected (email, recipes/pantry/list content), that it's stored in Google Firebase, and deletion via in-app account deletion. Keep it consistent with R.17's manifest. Fill App Privacy labels in App Store Connect (Contact Info → email; User Content → other user content; linked to user; not used for tracking). Put the URL into the constant from 3.4.
- [ ] **5.4 App Check** [Mac + Callum] (S4) — Add `FirebaseAppCheck` package product; App Attest provider in release, debug provider in DEBUG (print token for console allow-list). Enable enforcement for Firestore in the console **only after** monitoring shows verified traffic.
- [ ] **5.5 Budget alert** [Callum] — Google Cloud console ▸ Billing ▸ Budgets: alert at a small monthly amount so a bug or abuse can't run up a bill.
- [ ] **5.6 TestFlight** [Callum] — Archive, upload, internal testing. Run through the manual checklist in **Appendix F**.

---

### Phase 6 — Core features _(after Phases 1 and 4)_

- [ ] **6.1 Quantities, units, servings** [Mac]
  - New Foundation-only `Models/IngredientParser.swift`: `parse("200g plain flour") -> (quantity: 200, unit: "g", name: "plain flour")`. Handle: integers/decimals (`1.5`, `1,5`), fractions (`1/2`, `1 1/2`), unicode fractions (`½ ¼ ¾ ⅓ ⅔`), attached or spaced units (`200g`, `200 g`), unit words incl. plurals (Appendix E), no-unit counts (`3 eggs`), no quantity (`salt`, `salt to taste`), ranges (`2-3 cloves garlic` → take the upper bound, keep it simple). Never fail — worst case the whole string is the name.
  - New `Models/IngredientFormatter.swift`: format back (`200 g plain flour`, `1½ tbsp sugar`, `3 eggs`), sensible rounding.
  - Heavy unit tests for both (aim 40+ cases).
  - Form: the quick-add row parses on commit; rows display formatted text; tapping a row lets the user edit it as text (re-parse on commit).
  - Matching (pantry/shopping status) stays by name key only — quantity is ignored for pantry presence.
  - Recipe `servings` field: stepper in form; on detail view a servings stepper scales displayed quantities (pure `scaled(by:)` helper + tests).
  - "Add All" / cart toggle carry quantity+unit onto the shopping list doc. If the key already exists on the list, merge with `ShoppingQuantity.merge(existing:adding:)`: same unit → sum; g↔kg, ml↔l → convert and sum; otherwise keep existing and append the new amount to a `Note` string ("+ 1 cup"). Pure + tested.
  - Schema: fields already defined in Appendix A; no migration needed.
- [ ] **6.2 Search** [Mac] — `.searchable` on Recipes (both scopes) matching title or any ingredient name (normalised, substring). Pure `DataManager.filterRecipes(_:query:)` + tests. Pantry/Shopping search optional.
- [ ] **6.3 Recipe photos** [Mac + Callum]
  - `PhotosPicker` in the recipe form; downscale to max 1600 px long edge, JPEG q≈0.7, strip metadata; upload to Storage `users/{uid}/recipes/{recipeId}/cover.jpg`; store `ImagePath` on the recipe doc.
  - Display with `AsyncImage` (URL fetched once via `downloadURL()` and cached in memory per path) — hero image on detail, thumbnail on list rows.
  - `storage.rules` at repo root: owner write (image/*, < 5 MB); read if owner **or** the corresponding recipe is shared (use `firestore.get()` cross-service rule) — plus rules tests with the Storage emulator. Add to `firebase.json`.
  - Deleting a recipe deletes its image; account deletion (3.5) deletes `users/{uid}/` images.
- [ ] **6.4 Shopping list by aisle** [Mac] — Foundation-only `Models/AisleClassifier.swift`: keyword table → aisle (`Produce`, `Dairy & Eggs`, `Meat & Fish`, `Bakery`, `Tins & Jars`, `Dry Goods`, `Frozen`, `Spices & Condiments`, `Drinks`, `Household`, `Other`) matching on normalised name tokens. Add `ShoppingSort.byAisle`. Tests for the table. (User overrides = future.)
- [ ] **6.5 Shared recipe attribution** [Mac] — Ask for a display name at sign-up (optional field; default = email prefix); store on `/Users/{uid}.DisplayName`. When sharing, write `OwnerName` on the recipe; show "Shared by {name}" in the banner and list. Rules: `OwnerName` string ≤ 50.
- [ ] **6.6 Ingredient autocomplete** [Mac] — While typing in a quick-add row, suggest from the user's known names (all recipe ingredients + pantry + shopping, deduped by key, prefix-matched, max 5). Pure helper + tests.

---

### Phase 7 — Meal planner (the "Planner" in FoodPlanner) _(after Phase 6.1)_

- [x] **7.1 Schema + data layer** [Mac]
  - `/Users/{uid}/MealPlan/{yyyy-MM-dd}` → `{ Date: "2026-10-05", Meals: [ { Id, RecipeId, RecipeName, Slot: "breakfast"|"lunch"|"dinner"|"snack", Servings? } ], UpdatedAt }`. `RecipeName` is denormalised so a deleted recipe still shows something sensible.
  - Date keys via a pure `PlanDate` helper: `Calendar(identifier: .iso8601)` with `firstWeekday = 2` (DEC-8), `DateFormatter` with `en_US_POSIX` locale and `yyyy-MM-dd`. Tests for week boundaries, DST changes, year boundaries.
  - `DataManager`: `@Published var mealPlan: [String: [PlannedMeal]]`, a listener scoped to the visible week (`whereField(FieldPath.documentID(), isGreaterThanOrEqualTo:)`/`isLessThanOrEqualTo:`) that is re-pointed when the week changes (remove old registration first). `addMeal`, `removeMeal`, `moveMeal` (batched), `clearWeek`.
  - Rules: owner-only on `MealPlan`; validate shape. Add rules tests. Include `MealPlan` in account deletion (3.5).
- [x] **7.2 Plan tab UI** [Mac] — New "Plan" tab (`calendar` icon) between Recipes and Pantry. Week header with ◀ ▶ and "This week"; a list section per day showing meals by slot; "+" per day → recipe picker sheet (searchable, shows pantry match); swipe to delete; drag to another day (optional). Tapping a meal pushes the recipe detail. Recipe detail gets an "Add to plan" toolbar action → date + slot picker. IDs `plan.*`.
- [x] **7.3 Generate shopping list from plan** [Mac] — Button on the Plan tab: "Add missing for this week". Pure `DataManager.missingIngredients(forPlan:recipes:pantry:shopping:)` → keyed, quantity-merged (6.1 merge rules, scaled by planned servings) list of what isn't already in the pantry or on the list. Confirmation sheet listing what will be added (checkboxes), then one batch write. Thorough tests.
- [x] **7.4 "What can I cook?"** [Mac] (optional) — On the Plan or Recipes tab: recipes you can make with zero missing ingredients, then one missing, then two. Reuses the DEC-5 sort.

---

### Phase 8 — CI & test infrastructure

> 8.1 and 8.2 are **superseded by R.11**, which builds the same jobs into `ci.yml` with no secrets. They're kept here only for the detail.

- [x] **8.1 Rules CI** _(done as the `rules` job in `ci.yml`, R.11)_ [cloud-ok] — `.github/workflows/firestore-rules.yml` on `ubuntu-latest`: `actions/setup-node@v4` (22), `actions/setup-java@v4` (21, temurin), cache `~/.cache/firebase/emulators`, `npm ci` in `firebase/`, `npx firebase emulators:exec --only firestore --project demo-foodplanner "npm test"` (a `demo-` project ID needs no credentials). Trigger on changes to `firestore.rules`, `storage.rules`, `firebase/**`.
- [x] **8.2 iOS CI** _(superseded by R.11)_ [cloud-ok to write, Callum to configure] — `.github/workflows/ios.yml` on a `macos-26` runner (or latest with Xcode 26): select Xcode, write `GoogleService-Info.plist` from a base64 repo secret `GOOGLE_SERVICE_INFO_PLIST_B64`, cache SPM (`~/Library/Developer/Xcode/DerivedData/**/SourcePackages`), run `xcodebuild test -only-testing:FoodPlannerTests` on an available simulator. Requires 0.5 (shared scheme + Package.resolved). UI tests job optional / nightly.
- [x] **8.3 Emulator mode in the app** [Mac] — In `FoodPlannerApp.init` under `#if DEBUG`: if launch argument `-use-firebase-emulator` is present, call `Auth.auth().useEmulator(withHost: "127.0.0.1", port: 9099)` and set Firestore `settings.host = "127.0.0.1:8080"`, `isSSLEnabled = false`, `cacheSettings = MemoryCacheSettings()` **before** any other Firestore use. Document in `CLAUDE.md`.
- [x] **8.4 Signed-in UI tests** [Mac] — With the emulators running (`npx firebase emulators:start --only auth,firestore --project demo-foodplanner`), UI tests that sign up a fresh random user and cover: add recipe → appears in list; pantry toggle from detail → badge updates; Add All → items on shopping list; tick item → moves to pantry; edit recipe; delete recipe; share → visible from a second account; account deletion. Switch `test_invalidLoginShowsError` to the emulator too (T2). Add the required accessibility IDs as you go.
- [ ] **8.5 DataManager integration tests** [Mac] (optional) — Swift Testing suite gated on an env var that runs `DataManager` against the emulator: write-then-listen round trips, batch atomicity, migration (seed v1 data via the emulator REST API, run `LegacyMigrator`, assert v2 shape).

---

## Appendices

### Appendix A — Firestore schema v2

```
/Users/{uid}
    SchemaVersion: Int            // 2
    Email: String
    DisplayName: String?          // 6.5
    CreatedAt: Timestamp

/Users/{uid}/Recipes/{recipeId}   // recipeId = auto ID
    Name: String                  // 1…200 chars
    Instructions: String          // 0…20,000 chars
    Ingredients: [                // 1…100 entries, array order = display order
        { Name: String,           // 1…100 chars, display casing as typed
          Quantity: Double?,      // 6.1
          Unit: String? }         // 6.1, normalised (Appendix E), ≤ 20 chars
    ]
    Servings: Int?                // 6.1, 1…100
    OwnerId: String               // == uid, immutable
    OwnerName: String?            // 6.5, set when shared
    IsShared: Bool
    SourceRecipePath: String?     // set when saved from a shared recipe
    ImagePath: String?            // 6.3
    CreatedAt: Timestamp
    UpdatedAt: Timestamp

/Users/{uid}/Pantry/{key}         // key = IngredientKey.documentID(for: Name)
    Name: String
    CreatedAt: Timestamp

/Users/{uid}/ShoppingList/{key}   // key = IngredientKey.documentID(for: Name)
    Name: String
    Quantity: Double?             // 6.1
    Unit: String?                 // 6.1
    Note: String?                 // 6.1 (un-mergeable extra amounts)
    CreatedAt: Timestamp

/Users/{uid}/MealPlan/{yyyy-MM-dd}  // Phase 7
    Date: String
    Meals: [ { Id: String, RecipeId: String, RecipeName: String, Slot: String, Servings: Int? } ]
    UpdatedAt: Timestamp

/Ingredients/{id}                 // LEGACY v1 — read-only, used only by LegacyMigrator
```

Why ingredient keys aren't stored on recipe ingredients: they're cheap to recompute from `Name` client-side, and storing them invites drift if the normalisation rules change.

### Appendix B — `firestore.rules` draft

Starting point for Task 2.1 — the implementer must make the tests in 2.2 pass and adjust as needed.

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function signedIn() { return request.auth != null; }
    function isOwner(uid) { return signedIn() && request.auth.uid == uid; }

    function validIngredient(i) {
      return i is map
        && i.keys().hasOnly(['Name', 'Quantity', 'Unit'])
        && i.Name is string && i.Name.size() > 0 && i.Name.size() <= 100
        && (!('Quantity' in i) || i.Quantity is number)
        && (!('Unit' in i) || (i.Unit is string && i.Unit.size() <= 20));
    }

    function validRecipe(d) {
      return d.keys().hasOnly(['Name', 'Instructions', 'Ingredients', 'Servings', 'OwnerId', 'OwnerName',
                               'IsShared', 'SourceRecipePath', 'ImagePath', 'CreatedAt', 'UpdatedAt'])
        && d.Name is string && d.Name.size() > 0 && d.Name.size() <= 200
        && d.Instructions is string && d.Instructions.size() <= 20000
        && d.Ingredients is list && d.Ingredients.size() > 0 && d.Ingredients.size() <= 100
        // Rules have no loops: check the first entries explicitly, or validate the
        // per-item shape client-side and only bound the list size here. Implementer: pick
        // one and document it; per-item validation of all 100 entries is not possible.
        && d.IsShared is bool
        && (!('Servings' in d) || (d.Servings is int && d.Servings > 0 && d.Servings <= 100))
        && (!('OwnerName' in d) || (d.OwnerName is string && d.OwnerName.size() <= 50));
    }

    function validListItem(d) {
      return d.keys().hasOnly(['Name', 'Quantity', 'Unit', 'Note', 'CreatedAt'])
        && d.Name is string && d.Name.size() > 0 && d.Name.size() <= 100;
    }

    match /Users/{uid} {
      allow read, write: if isOwner(uid);

      match /Recipes/{recipeId} {
        allow read: if isOwner(uid);
        allow create: if isOwner(uid) && validRecipe(request.resource.data)
                      && request.resource.data.OwnerId == uid;
        allow update: if isOwner(uid) && validRecipe(request.resource.data)
                      && request.resource.data.OwnerId == resource.data.OwnerId;
        allow delete: if isOwner(uid);

        // LEGACY v1 subcollection — owner may read (migration) and delete (cleanup) only.
        match /Ingredients/{ingredientId} {
          allow read, delete: if isOwner(uid);
        }
      }

      match /Pantry/{key} {
        allow read, delete: if isOwner(uid);
        allow create, update: if isOwner(uid) && validListItem(request.resource.data);
      }

      match /ShoppingList/{key} {
        allow read, delete: if isOwner(uid);
        allow create, update: if isOwner(uid) && validListItem(request.resource.data);
      }

      match /MealPlan/{date} {
        allow read, write: if isOwner(uid);   // tighten with shape validation in 7.1
      }
    }

    // Shared recipes: readable by any signed-in user, via direct get or the
    // collectionGroup("Recipes").where("IsShared", "==", true) query.
    match /{path=**}/Recipes/{recipeId} {
      allow read: if signedIn() && resource.data.IsShared == true;
    }

    // LEGACY v1 global ingredient catalogue — read-only for the migration.
    match /Ingredients/{id} {
      allow read: if signedIn();
      allow write: if false;
    }
  }
}
```

Note: rules validate the *resulting* document, so the migration's `updateData` on a v1 recipe must leave it fully v2-shaped — write `Ingredients` entries with `Name` (+ `Quantity`/`Unit` if present) only, never the v1 `Ref`/`Order` fields, which belong to the subcollection docs and must not be copied onto the parent. Deploy rules only after Callum's own account has migrated (Task 2.3) to avoid surprises.

### Appendix C — Ingredient key normalisation

`IngredientKey.normalized(_ name: String) -> String`
1. Trim leading/trailing whitespace and newlines.
2. Collapse every run of internal whitespace to a single ASCII space.
3. `folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)`.
4. Result may be empty (callers must reject empty names before writing).

`IngredientKey.documentID(for name: String) -> String`
1. `k = normalized(name)`.
2. Percent-escape `%` → `%25` first, then `/` → `%2F`.
3. If `k` is `.` or `..`, or matches `^__.*__$`, prefix with `k_`.
4. If UTF-8 length > 400 bytes, truncate to 400 bytes on a character boundary (names are capped at 100 chars, so this is defence in depth).
5. Precondition: non-empty.

Examples: `"  Olive   Oil "` → `"olive oil"`; `"Jalapeño"` → `"jalapeno"`; `"1/2 & 1/2"` → `"1%2F2 & 1%2F2"`; `".."` → `"k_.."`.

### Appendix D — Auth error messages

| `AuthFailure` | Firebase codes | Message |
|---|---|---|
| `invalidCredentials` | `.invalidCredential`, `.wrongPassword`, `.userNotFound` | "That email and password don't match an account." |
| `invalidEmail` | `.invalidEmail` | "That doesn't look like a valid email address." |
| `emailInUse` | `.emailAlreadyInUse` | "An account already exists for that email. Try logging in." |
| `weakPassword` | `.weakPassword` | "Choose a password with at least 6 characters." |
| `network` | `.networkError` | "Can't reach the server. Check your connection and try again." |
| `tooManyRequests` | `.tooManyRequests` | "Too many attempts. Wait a moment and try again." |
| `requiresRecentLogin` | `.requiresRecentLogin` | "For your security, please enter your password again." |
| `userDisabled` | `.userDisabled` | "This account has been disabled." |
| `unknown` | anything else | "Something went wrong. Please try again." |

(Firebase projects created after Sept 2023 have email-enumeration protection on by default, so wrong-password and unknown-user both surface as `.invalidCredential` — hence the merged case.)

### Appendix E — Units (for 6.1)

Normalised unit → accepted spellings (case-insensitive, optional trailing `.`):

| Unit | Accepts |
|---|---|
| `g` | g, gram, grams, gr |
| `kg` | kg, kilo, kilos, kilogram(s) |
| `ml` | ml, millilitre(s), milliliter(s) |
| `l` | l, litre(s), liter(s) |
| `tsp` | tsp, teaspoon(s), t |
| `tbsp` | tbsp, tbs, tablespoon(s), T |
| `cup` | cup, cups |
| `oz` | oz, ounce(s) |
| `lb` | lb, lbs, pound(s) |
| `pinch` | pinch, pinches |
| `clove` | clove, cloves |
| `can` | can, cans, tin, tins |
| `pack` | pack, packs, packet(s) |
| `slice` | slice, slices |
| `bunch` | bunch, bunches |

Convertible pairs for merging: g↔kg (×1000), ml↔l (×1000). Everything else merges only with the identical unit. Note `t` vs `T` is the one case-sensitive pair — handle explicitly or drop both single-letter forms (recommended: drop them).

### Appendix F — Manual pre-release checklist

- [ ] Fresh install → sign up (with confirm password) → land on empty Recipes with helpful empty state
- [ ] Log out / log in; wrong password shows the friendly message; forgot-password email arrives
- [ ] Add recipe with 5 ingredients → order preserved after relaunch
- [ ] Edit recipe (title, add/remove ingredient, instructions) → reflected immediately and after relaunch
- [ ] Pantry toggles on detail update the list badge and pantry tab
- [ ] Add All → only missing items added, in recipe order; no duplicates when tapped twice
- [ ] Shopping: tick moves to pantry; delete removes; group-by-recipe correct
- [ ] Airplane mode: add pantry item → appears; reconnect → persists. A failed delete un-hides the row.
- [ ] Share recipe → visible on second account's Shared tab → save copy → copy is independent
- [ ] Rotate on recipe detail → landscape split, no flash; other screens stay portrait
- [ ] Dark mode on every screen
- [ ] Dynamic Type at XXL on every screen — nothing truncated unusably
- [ ] VoiceOver: every button has a label
- [ ] Delete account → data gone, can't log in, shared recipes gone for others

### Appendix G — Working agreement for `CLAUDE.md` (Task R.9)

These are the sections to add to `CLAUDE.md`. They follow WingLog's shape (Rules, then Security, then Testing), but each rule is written for this codebase. Where a WingLog rule has no equivalent here (SimConnect, Electron IPC, Drizzle migrations, units at the IPC boundary), it's left out instead of being forced in.

#### G.1 Rules

- **Views never touch Firebase.** Only `DataManager` imports `FirebaseFirestore` (and `AuthViewModel` imports `FirebaseAuth`). Views read published state and call `DataManager` methods. A view that imports a Firebase module is a review failure.
- **Firestore paths and field names live in one place**: a `FirestoreSchema` enum of constants (`collection.recipes`, `field.name`, …) introduced in Phase 1. No string literals for paths or fields anywhere else. A rename then becomes a one-line change plus a migration, not a grep hunt.
- **Every schema change ships as a unit:** bump `SchemaVersion`, add the migration step, update `firestore.rules` **and** its tests, and update Appendix A of this plan and the schema section of `CLAUDE.md`, all in the same PR. Rules that lag the schema mean either a broken app (writes denied) or an open database.
- **Anything that sends user data somewhere new is a decision, not an implementation detail.** That covers a new SDK (analytics, crash reporting, ads), a new Firebase product, or a new field others can see (like `OwnerName`). Record it in `docs/decisions.md` first, then update the privacy policy, `PrivacyInfo.xcprivacy`, the App Privacy labels and the README's data table together.
- **Pure logic is Foundation-only and has tests.** Matching, parsing, formatting, sorting, grouping, date keys, merge rules: `static` functions or small types with no Firebase/SwiftUI import, as `DataManager`'s helpers already do.
- **Observable state is `@MainActor`.** `DataManager`, `AuthViewModel` and form view models. No `DispatchQueue.main.async` to patch over isolation warnings; fix the isolation.
- **No `!`, `try!` or `fatalError` in app code** (enforced by swift-format, R.10). Parse Firestore data defensively: a malformed doc is skipped and logged, never a crash.
- **Optimistic UI must roll back.** Any view that changes local state ahead of a write handles the failure path (Task 4.6 sets the pattern).
- **Accessibility identifiers** on every interactive element, `screen.element` style. Every image-only button gets an `accessibilityLabel`.
- **Prefer boring.** Native SwiftUI components over custom overlays; one way of doing a thing. This is a small app maintained by one person.
- **Commits:** imperative subject line ≤ 72 chars, optional area prefix (`recipes:`, `auth:`, `rules:`, `ci:`, `deps:`, `docs:`). One logical change per commit; formatting-only changes go in their own commit.

#### G.2 Security

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

#### G.3 Testing

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
- **Cloud sessions can't build the app.** They must say so in the PR (template, R.12), and that PR can't merge until CI's `build-test` is green.

### Appendix H — Licence, copyright and README templates

#### H.1 `LICENSE` (all rights reserved)

```
Copyright © 2025–2026 Callum Jones. All rights reserved.

This repository is published so that its source code can be read and evaluated,
for example as part of a portfolio or job application. Publication does not grant
any licence to it.

You may view the source code on GitHub and, as GitHub's Terms of Service allow,
fork it within GitHub. You may not copy, modify, distribute, sublicense, publish,
or use the code or any substantial part of it, in source or compiled form, or
build and distribute the app, without prior written permission from the
copyright holder.

Third-party components included in or used by this project are licensed under
their own terms; see THIRD-PARTY-LICENSES.md.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED. IN NO EVENT SHALL THE COPYRIGHT HOLDER BE LIABLE FOR ANY CLAIM, DAMAGES
OR OTHER LIABILITY ARISING FROM THE SOFTWARE OR ITS USE.

For permission requests, open an issue at
https://github.com/Catalyst4K/FoodPlanner/issues.
```

(Not legal advice. If the app ever becomes commercial, a quick check with a solicitor is worth it.)

#### H.2 `COPYRIGHT`

Contents: the notice line; the app name and one-line description; "see LICENSE for terms"; a short note that this file plus `LICENSE` are authoritative and per-file headers deliberately aren't used (decision-log reference); a pointer to `THIRD-PARTY-LICENSES.md`; and a trademark disclaimer: "Apple, iPhone and iOS are trademarks of Apple Inc. Firebase is a trademark of Google LLC. FoodPlanner is an independent project and is not affiliated with or endorsed by either."

#### H.3 README outline

1. **Header:** icon, name, one-line pitch ("Plan meals around what's already in your kitchen: recipes, pantry and a shopping list that keep each other in sync."), and badges: CI, CodeQL, `iOS 26+`, `Swift 5`→`6`, `SwiftUI`, licence "All rights reserved".
2. **Screenshots:** grid from R.15, light and dark.
3. **Features:** short bullets that only claim what has shipped. Add the meal planner when Phase 7 lands.
4. **Engineering highlights** (the portfolio section). Each item is 1–2 sentences with a link to the code:
   - Real-time sync with Firestore snapshot listeners, plus optimistic UI with rollback.
   - Security rules as the backend, with a rules test suite covering allow and deny cases.
   - Firebase-free, unit-tested core logic (matching, parsing, normalisation), with a coverage ratchet.
   - Swift Concurrency: a `@MainActor` data layer and atomic batched writes.
   - The ingredient parser and quantity merging (once 6.1 has landed).
   - Accessibility: VoiceOver labels, Dynamic Type, and UI tests driven by accessibility identifiers.
   - CI with no secrets, emulator-backed tests, and CodeQL for Swift.
5. **Architecture:** a Mermaid diagram (App → AuthViewModel → DataManager → Firestore/Auth; Views → DataManager; pure core ← DataManager) and a short paragraph per layer. Link `CLAUDE.md` for depth.
6. **Data & privacy:** a "What leaves your device" table (email → Firebase Auth; recipes/pantry/list → Firestore under your account; shared recipes → readable by all signed-in users; photos → Firebase Storage), how to delete your account, and a link to the privacy policy.
7. **Building from source:** Xcode 26, `make emulators`, copy `ci/GoogleService-Info.plist` into `FoodPlanner/`, run with `-use-firebase-emulator`. No Firebase account needed. Then `make test` / `make check`.
8. **Project structure:** a short annotated tree.
9. **Roadmap:** link to this plan and the changelog.
10. **Licence:** "All rights reserved — see LICENSE. Source published for evaluation." Link `COPYRIGHT` and `THIRD-PARTY-LICENSES.md`.
11. **Author:** name and GitHub profile (plus LinkedIn or portfolio site if wanted; no personal email).
