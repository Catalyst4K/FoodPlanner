# Plan: Ingredient quantities in recipes & shopping list

> Status: **planned, not started.** This branch holds the design only.

## Goal
Let ingredients carry a quantity + unit (e.g. "2 cups flour", "500 g chicken"),
captured when editing a recipe, shown in the recipe detail, and carried through
to the shopping list when adding ingredients.

## What already exists (don't rebuild)
- `IngredientItem` already has `quantity: Double?` and `unit: String?`.
- Recipe ingredient subcollection docs already read/write `Quantity`/`Unit`
  (`DataManager.parseRecipeDoc` → `fetchRecipeIngredients`, and
  `addRecipe`/`updateRecipe` write them when non-nil).
- `resolveIngredientsPreservingOrder` already carries `quantity`/`unit` through.
- `fetchIngredients` (pantry/shopping) already parses `Quantity`/`Unit` from the
  doc, so surfacing them there is mostly a matter of *writing* them.

So the gap is almost entirely **UI capture** + **shopping-list write schema**.

## Work
1. **Form capture** (`RecipeListViewModel`, `AddRecipeView`, and the inline edit
   form in `RecipeDetailView`):
   - Add quantity + unit fields to the add-ingredient row and to each existing
     ingredient row so they can be edited.
   - `addIngredient(name:)` → `addIngredient(name:quantity:unit:)`; keep the
     case-insensitive dedupe.
   - `buildRecipe()` passes quantity/unit through (already on `IngredientItem`).
   - Note: the add form and the detail edit form share the same row UI — factor
     the ingredient row into one reusable view to avoid drift.
2. **Recipe detail display** (`RecipeDetailView.ingredientsSection`): render
   quantity + unit before the name, e.g. "2 cups · Flour". Handle nil gracefully
   (name only).
3. **Shopping list schema** (`DataManager`): write `Quantity`/`Unit` on
   `/Users/{uid}/ShoppingList/{id}` docs.
   - Update `addMissingIngredientsToShoppingList` to copy each recipe
     ingredient's quantity/unit into the batch write.
   - Update the single-add path (`addIngredientToShoppingList`) if we want manual
     adds to support quantities too.
   - `ShoppingListView` row: show quantity/unit.
4. **Units**: decide source of truth (see open questions). Start with a small
   curated list + free-text fallback; store the raw string in `Unit`.

## Open questions / decisions to make first
- **Aggregation**: if the same ingredient is added from two recipes (or manually
  twice), do we sum quantities? Only when units match? Or keep separate rows?
  Current shopping list dedupes by ingredient ref/name — summing needs a merge
  step. Recommend: sum when unit matches, otherwise keep the existing entry and
  ignore/append (define explicitly).
- **Pantry quantities**: pantry is currently presence-based ("in stock or not").
  Decide whether pantry items get quantities at all, or stay boolean. Recommend
  leaving pantry boolean for v1 to limit scope.
- **Unit model**: free-text vs enum vs curated-list + free text. Recommend
  curated list (g, kg, ml, l, tsp, tbsp, cup, piece) + free text.
- **Migration**: existing docs have no Quantity/Unit → treat as nil, display name
  only. No migration write needed.

## Files likely touched
- `FoodPlanner/ViewModels/RecipeListViewModel.swift`
- `FoodPlanner/Views/AddRecipeView.swift`
- `FoodPlanner/Views/RecipeDetailView.swift`
- `FoodPlanner/Views/ShoppingListView.swift`
- `FoodPlanner/Models/DataManager.swift`

## Tests
- Extend `RecipeListViewModelTests` for quantity/unit capture + dedupe.
- Add pure-helper coverage if an aggregation/merge function is introduced
  (keep it a `static` Firebase-free helper on `DataManager`, per project style).
