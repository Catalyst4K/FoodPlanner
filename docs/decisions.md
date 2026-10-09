# Decision log

Dated entries: context, decision, consequences. Any decision that changes
architecture, sends data off the device, adds a dependency, or affects licensing
gets an entry **here before it is built**. Nothing secret goes in this file.

The entries below backfill the defaults chosen in `IMPLEMENTATION_PLAN.md` §4.

## 2026-10-07 — DEC-1: Keep existing Firestore data through the schema change
- **Context:** Schema v2 changes the Firestore layout.
- **Decision:** Write a one-time migration (plan task 1.6). If there turns out to be no data worth keeping, skip it and delete the old data in the console.
- **Consequences:** Extra migration code and tests; no data loss for existing accounts.

## 2026-10-07 — DEC-2: Meaning of "shared"
- **Context:** Recipes can be marked shared.
- **Decision:** Shared means public to every signed-in user of the app (current behaviour). Friends/groups sharing is out of scope.
- **Consequences:** Shared content is untrusted input from other users and is rendered as plain text only.

## 2026-10-07 — DEC-3: Retire the global `/Ingredients` collection
- **Decision:** Ingredient names are stored inline. Existing docs stay read-only for the migration; nothing new is written to them.
- **Consequences:** Removes the shared mutable collection and the dedupe-on-write path.

## 2026-10-07 — DEC-4: Ingredient identity is a normalised name key
- **Decision:** Trimmed, whitespace-collapsed, case- and diacritic-insensitive (plan Appendix C). Plurals ("egg" vs "eggs") are not merged.
- **Consequences:** Plural merging is future work.

## 2026-10-07 — DEC-5: Pantry-match ordering
- **Decision:** Fewest missing ingredients first, then higher match ratio, then name (A→Z, localized).

## 2026-10-07 — DEC-6: Account entry point
- **Decision:** A gear button in each tab's toolbar opens Account as a sheet.

## 2026-10-07 — DEC-7: Bundle ID
- **Decision:** Open — to be decided by Callum before Phase 5 (recommendation: `com.callumjones.foodplanner`, or keep `Callum.FoodPlanner`).
- **Consequences:** Changing it requires registering a new iOS app in Firebase and replacing `GoogleService-Info.plist`.

## 2026-10-07 — DEC-8: Meal planner week start
- **Decision:** Monday (UK).

## 2026-10-07 — DEC-9: Units
- **Decision:** Metric-first; free-text units allowed; known units normalised (plan Appendix E).

## 2026-10-07 — DEC-10: Licence
- **Context:** The repo is public but the app is headed for the App Store, and Callum's goal is ownership plus a portfolio rather than reuse.
- **Decision:** All rights reserved, source visible for evaluation (`LICENSE`). Callum to confirm.
- **Consequences:** GPL terms are widely considered incompatible with App Store distribution. Switching to open source later is a drop-in swap (e.g. MIT, or GPL-3.0 plus `COPYRIGHT`). `COPYRIGHT` and `LICENSE` are authoritative, so there are no per-file headers.

## 2026-10-07 — DEC-11: Outside contributions
- **Decision:** Not accepted; issues are welcome (`CONTRIBUTING.md`).
- **Consequences:** Sole copyright stays simple.

## 2026-10-07 — DEC-12: Development docs live in this public repo
- **Decision:** Plan and decision log live under `docs/`.
- **Consequences:** Planning is visible as part of the portfolio. Docs must contain no secrets or personal data.

## 2026-10-07 — DEC-13: Trunk-based branching
- **Decision:** Protected `main` (PR plus green CI required, admins included); short-lived `feature/<name>` and `fix/<name>` branches. Add `develop` only if TestFlight releases need batching.

## 2026-10-07 — DEC-14: Formatting and lint tooling
- **Decision:** Apple's `swift-format` for both formatting and linting. Add SwiftLint later only if a missing rule is needed.

## 2026-10-07 — R.2: Do not rewrite history for the leaked Firebase config
- **Context:** `GoogleService-Info.plist` was committed (`e04ad85`) and later deleted (`d4a87d5`), so it remains in the public history. Its values are identifiers rather than true secrets, but with permissive Firestore rules they would be enough to access the database directly.
- **Decision:** Don't rewrite history, since forks and caches already hold it. Mitigate on the backend: restrict the API key (iOS bundle ID and API restrictions), ship security rules (Phase 2), and add App Check before public TestFlight.
- **Consequences:** The old config stays visible in history; `SECURITY.md` lists it as out of scope for reports.

## 2026-10-09 — R.2 update: API key replaced and restricted
- **Context:** The key in the leaked config was replaced some time before this entry, so the key in the public history is no longer the one the app uses. The current key still wasn't restricted.
- **Decision:** Restrict the current key to the iOS bundle ID (`Callum.FoodPlanner`) and to the APIs the app uses (Identity Toolkit, Token Service, Cloud Firestore, Firebase Installations; App Check and Cloud Storage for Firebase once those features land). Remove the leaked key's access; confirm it is deleted in Google Cloud ▸ Credentials.
- **Consequences:** The remaining values in the old config (project ID, app ID, bundle ID) can't be rotated, so Firestore security rules (Phase 2) remain the real protection for data. Until Phase 2 ships, check that the live rules are not open.

## 2026-10-09 — DEC-1 resolved: no v1 → v2 migration
- **Context:** DEC-1 defaulted to writing a one-time migration. The only data in Firestore is experimental, created while building the app.
- **Decision:** Don't migrate. Skip plan task 1.6 (`LegacyMigrator`) and treat Firestore as empty when schema v2 lands. Callum deletes the old data in the console.
- **Consequences:** No migration code or `SchemaVersion` bookkeeping to maintain. v1-shaped documents are simply ignored by the v2 mapping (it returns nil for them). If real user data ever exists before a future schema change, that change needs its own migration.

## 2026-10-09 — DEC-3 refined: no user-writable ingredient collection; catalogue later
- **Context:** DEC-3 retires the global `/Ingredients` collection that every user can create entries in. Callum raised that a shared ingredient dictionary could hold attributes such as nutrition values.
- **Decision:** Retire the user-writable `/Ingredients` collection as planned: v2 stores ingredient names inline on recipes, pantry and shopping items, identified by the normalised `IngredientKey`. Ingredient attributes (nutrition, aisle, density) will live in a separate read-only `Catalogue/{ingredientKey}` collection, written only by the app owner (seed or admin tooling), never by clients, and joined on the same key.
- **Consequences:** No abuse or cost surface from a collection anyone can write to, and no per-ingredient reads on the hot path. Attaching nutrition later needs no schema change to recipes: look up `Catalogue/{documentID(for: name)}`. The catalogue gets its own rules (read for signed-in users, no client writes), schema entry and decision when it is built (Phase 6+).
