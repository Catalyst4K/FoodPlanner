import Foundation

/// Works out what to buy for a meal plan. Foundation-only.
enum PlanShopping {
    /// The ingredients the planned meals need that are neither in the pantry nor already on the shopping list.
    ///
    /// - Each meal's recipe is scaled to the planned servings (when both the meal and the recipe have servings).
    /// - The same ingredient across meals is combined with the shopping-list merge rules (units convert, unlike
    ///   units go to the note).
    /// - Meals whose recipe no longer exists are skipped.
    /// - Order is the order of first appearance, so the confirmation sheet follows the plan.
    static func missingIngredients(
        forPlan meals: [PlannedMeal], recipes: [Recipe], pantry: [IngredientItem], shopping: [IngredientItem]
    ) -> [IngredientItem] {
        let have = Set(pantry.map(\.id)).union(shopping.map(\.id))
        let recipesByID = Dictionary(recipes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        var order: [String] = []
        var needed: [String: IngredientItem] = [:]
        for meal in meals {
            guard let recipe = recipesByID[meal.recipeId] else { continue }
            let scaled = meal.servings.map { recipe.scaled(toServings: $0) } ?? recipe
            for ingredient in scaled.ingredients {
                let id = IngredientKey.documentID(for: ingredient.name)
                guard !id.isEmpty, !have.contains(id) else { continue }
                var item = ingredient
                item.id = id
                if let existing = needed[id] {
                    let merged = ShoppingQuantity.merge(existing: existing, adding: item)
                    needed[id] = IngredientItem(
                        id: id, name: existing.name, quantity: merged.quantity, unit: merged.unit, note: merged.note)
                } else {
                    order.append(id)
                    needed[id] = item
                }
            }
        }
        return order.compactMap { needed[$0] }
    }

    /// All meals of the visible week in plan order: by day, then slot.
    static func meals(inWeekOf plan: [String: [PlannedMeal]]) -> [PlannedMeal] {
        plan.keys.sorted().flatMap { plan[$0] ?? [] }
    }
}
