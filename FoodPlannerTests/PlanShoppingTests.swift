import Foundation
import Testing

@testable import FoodPlanner

@Suite("Plan shopping")
struct PlanShoppingTests {
    private func item(_ name: String, _ quantity: Double? = nil, _ unit: String? = nil) -> IngredientItem {
        IngredientItem(id: IngredientKey.documentID(for: name), name: name, quantity: quantity, unit: unit)
    }

    private func recipe(_ id: String, servings: Int? = nil, _ ingredients: [IngredientItem]) -> Recipe {
        Recipe(id: id, title: id, ingredients: ingredients, instructions: "", servings: servings)
    }

    private func meal(_ recipe: String, servings: Int? = nil, slot: MealSlot = .dinner) -> PlannedMeal {
        PlannedMeal(id: UUID().uuidString, recipeId: recipe, recipeName: recipe, slot: slot, servings: servings)
    }

    @Test func listsIngredientsMissingFromPantryAndList() {
        let pasta = recipe("pasta", [item("Spaghetti", 400, "g"), item("Garlic", 2), item("Olive oil")])
        let missing = PlanShopping.missingIngredients(
            forPlan: [meal("pasta")], recipes: [pasta], pantry: [item("olive  oil")], shopping: [item("GARLIC")])
        #expect(missing.map(\.name) == ["Spaghetti"])
        #expect(missing.first?.quantity == 400)
    }

    @Test func combinesTheSameIngredientAcrossMeals() {
        let a = recipe("a", [item("Flour", 500, "g")])
        let b = recipe("b", [item("flour", 1, "kg"), item("Eggs", 2)])
        let missing = PlanShopping.missingIngredients(
            forPlan: [meal("a"), meal("b")], recipes: [a, b], pantry: [], shopping: [])
        #expect(missing.map(\.name) == ["Flour", "Eggs"])
        #expect(missing.first?.quantity == 1500)
        #expect(missing.first?.unit == "g")
    }

    @Test func scalesToThePlannedServings() {
        let soup = recipe("soup", servings: 2, [item("Carrot", 4), item("Stock", 500, "ml")])
        let missing = PlanShopping.missingIngredients(
            forPlan: [meal("soup", servings: 6)], recipes: [soup], pantry: [], shopping: [])
        #expect(missing.map(\.quantity) == [12, 1500])
    }

    @Test func plannedServingsAreIgnoredWhenTheRecipeHasNone() {
        let toast = recipe("toast", [item("Bread", 2)])
        let missing = PlanShopping.missingIngredients(
            forPlan: [meal("toast", servings: 4)], recipes: [toast], pantry: [], shopping: [])
        #expect(missing.first?.quantity == 2)
    }

    @Test func unlikeUnitsGoToTheNote() {
        let a = recipe("a", [item("Milk", 1, "cup")])
        let b = recipe("b", [item("Milk", 200, "g")])
        let missing = PlanShopping.missingIngredients(
            forPlan: [meal("a"), meal("b")], recipes: [a, b], pantry: [], shopping: [])
        #expect(missing.count == 1)
        #expect(missing.first?.note?.hasPrefix("+") == true)
    }

    @Test func skipsMealsWithDeletedRecipesAndBlankNames() {
        let odd = recipe("odd", [item("   "), item("Salt")])
        let missing = PlanShopping.missingIngredients(
            forPlan: [meal("gone"), meal("odd")], recipes: [odd], pantry: [], shopping: [])
        #expect(missing.map(\.name) == ["Salt"])
    }

    @Test func nothingPlannedMeansNothingToBuy() {
        #expect(PlanShopping.missingIngredients(forPlan: [], recipes: [], pantry: [], shopping: []).isEmpty)
    }

    @Test func weekMealsAreOrderedByDay() {
        let plan = ["2026-10-07": [meal("c")], "2026-10-05": [meal("a"), meal("b")]]
        #expect(PlanShopping.meals(inWeekOf: plan).map(\.recipeId) == ["a", "b", "c"])
    }
}
