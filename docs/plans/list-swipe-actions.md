# Plan: Swipe-action redesign for Shopping List & Pantry

> Status: **planned, not started.** This branch holds the design only.

## Goal
Adopt standard Apple swipe gestures on the Shopping List and Pantry rows:
- **Swipe left (trailing edge) → Delete** (red, destructive).
- **Swipe right (leading edge) → Move to the other list** (Shopping ↔ Pantry).

This replaces the current inline trailing trash button and the tap-the-circle
"move to pantry" affordance with familiar system gestures.

## Current structure (what we're changing)
Both `ShoppingListView` and `PantryView` render rows in a custom
`ScrollView { LazyVStack { ForEach … } }`, **not** a SwiftUI `List`. Custom
stacks don't get `.swipeActions` for free. Two options:

- **Option A (recommended): move rows into a `List`.** `.swipeActions` is the
  native, correct behaviour (full-swipe, haptics, edge inference, red delete).
  Cost: restyling to match the current look (hidden separators, plain style,
  keep the custom header + add-row + tap-to-add spacer around/inside the List).
  The "Group by Recipe" sections in `ShoppingListView` map cleanly to `Section`s.
- **Option B: custom swipe** with a drag gesture + offset. Full control over
  styling but re-implements a lot of system behaviour (thresholds, full-swipe,
  rubber-banding, accessibility). Only if the List restyle proves too limiting.

Go with **A** unless the visual redesign can't be achieved inside `List`.

## Work
1. **ShoppingListView** (`ShoppingListView.swift`):
   - Convert `listContent` rows into `List` rows (keep newest / group-by-recipe
     via `Section`s).
   - Trailing swipe: Delete → `dataManager.removeIngredientFromShoppingList`.
   - Leading swipe: "Move to Pantry" → existing
     `dataManager.moveShoppingItemToPantry(_:)`. (This is what the check-circle
     does today — decide whether the circle stays, becomes the leading swipe, or
     both.)
   - Preserve the `hiddenIds` optimistic fade so moves/deletes feel instant.
2. **PantryView** (`PantryView.swift`) — mirror image:
   - Trailing swipe: Delete → `dataManager.removeIngredientFromPantry`.
   - Leading swipe: "Move to Shopping List" → **new** DataManager method
     `movePantryItemToShoppingList(_:)` (mirror `moveShoppingItemToPantry`).
3. **DataManager** (`DataManager.swift`):
   - Add `movePantryItemToShoppingList(_ ingredient:)` = add to shopping list +
     remove from pantry (symmetric with the existing
     `moveShoppingItemToPantry`).
4. **Polish**: full-swipe enabled for the primary action, appropriate SF Symbols
   (`trash`, `cart`/`refrigerator`), colours (red delete, blue/green move),
   and haptic on full-swipe. Keep the add-ingredient row and the app-wide
   tap-to-dismiss behaviour working.

## Open questions / decisions
- Keep the tap-the-circle "bought → move to pantry" shortcut in addition to the
  leading swipe, or replace it? (Recommend keep both; swipe is discoverable,
  tap is fast.)
- Does the "Group by Recipe" grouping survive as `List` `Section`s with the
  star/"multiple recipes" header styling? Verify the header look inside `List`.
- Confirm `List` styling can reproduce the current minimal look (`.listStyle`,
  separator/​background tweaks) under iOS 26 / Liquid Glass — check
  DocumentationSearch for current `List`/`swipeActions` guidance before starting.

## Files likely touched
- `FoodPlanner/Views/ShoppingListView.swift`
- `FoodPlanner/Views/PantryView.swift`
- `FoodPlanner/Models/DataManager.swift` (new `movePantryItemToShoppingList`)

## Tests
- UI tests (`FoodPlannerUITests`) for swipe-to-delete and swipe-to-move on both
  screens; add accessibility identifiers to the swipe action buttons following
  the existing `screen.element` convention.
- Keep move logic testable: the move is just compose of existing add/remove.
