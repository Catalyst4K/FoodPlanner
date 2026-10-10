import Testing

@testable import FoodPlanner

@Suite("ShoppingQuantity.merge")
struct ShoppingQuantityTests {
    private func item(_ name: String, _ quantity: Double? = nil, _ unit: String? = nil, note: String? = nil)
        -> IngredientItem
    {
        IngredientItem(id: name, name: name, quantity: quantity, unit: unit, note: note)
    }

    @Test func sameUnitIsSummed() {
        let merged = ShoppingQuantity.merge(existing: item("flour", 200, "g"), adding: item("flour", 150, "g"))
        #expect(merged == .init(quantity: 350, unit: "g", note: nil))
    }

    @Test func unitlessCountsAreSummed() {
        let merged = ShoppingQuantity.merge(existing: item("eggs", 2), adding: item("eggs", 3))
        #expect(merged == .init(quantity: 5, unit: nil, note: nil))
    }

    @Test func gramsAndKilogramsConvertIntoTheExistingUnit() {
        #expect(
            ShoppingQuantity.merge(existing: item("flour", 1, "kg"), adding: item("flour", 500, "g"))
                == .init(quantity: 1.5, unit: "kg", note: nil))
        #expect(
            ShoppingQuantity.merge(existing: item("flour", 500, "g"), adding: item("flour", 1, "kg"))
                == .init(quantity: 1500, unit: "g", note: nil))
    }

    @Test func millilitresAndLitresConvert() {
        #expect(
            ShoppingQuantity.merge(existing: item("milk", 1, "l"), adding: item("milk", 250, "ml"))
                == .init(quantity: 1.25, unit: "l", note: nil))
    }

    @Test func incompatibleUnitsKeepTheExistingAmountAndAppendANote() {
        let merged = ShoppingQuantity.merge(existing: item("sugar", 200, "g"), adding: item("sugar", 1, "cup"))
        #expect(merged == .init(quantity: 200, unit: "g", note: "+ 1 cup"))
    }

    @Test func aCountAndAWeightAreNotMixed() {
        let merged = ShoppingQuantity.merge(existing: item("onion", 2), adding: item("onion", 300, "g"))
        #expect(merged == .init(quantity: 2, unit: nil, note: "+ 300 g"))
    }

    @Test func noteAccumulates() {
        let first = ShoppingQuantity.merge(existing: item("sugar", 200, "g"), adding: item("sugar", 1, "cup"))
        let second = ShoppingQuantity.merge(
            existing: item("sugar", first.quantity, first.unit, note: first.note), adding: item("sugar", 2, "tbsp"))
        #expect(second == .init(quantity: 200, unit: "g", note: "+ 1 cup, + 2 tbsp"))
    }

    @Test func addingNothingLeavesTheLineAlone() {
        let existing = item("flour", 200, "g", note: "+ 1 cup")
        #expect(
            ShoppingQuantity.merge(existing: existing, adding: item("flour"))
                == .init(quantity: 200, unit: "g", note: "+ 1 cup"))
        #expect(
            ShoppingQuantity.merge(existing: existing, adding: item("flour", 0, "g"))
                == .init(quantity: 200, unit: "g", note: "+ 1 cup"))
    }

    @Test func aLineWithNoAmountTakesTheAddedAmount() {
        let merged = ShoppingQuantity.merge(existing: item("salt"), adding: item("salt", 2, "tsp"))
        #expect(merged == .init(quantity: 2, unit: "tsp", note: nil))
    }
}

@Suite("Recipe scaling")
struct RecipeScalingTests {
    private func recipe(servings: Int?) -> Recipe {
        Recipe(
            id: "r", title: "Pancakes",
            ingredients: [
                IngredientItem(id: "flour", name: "Flour", quantity: 200, unit: "g"),
                IngredientItem(id: "eggs", name: "Eggs", quantity: 2),
                IngredientItem(id: "salt", name: "Salt"),
            ], instructions: "Mix.", servings: servings)
    }

    @Test func doublesAndHalves() {
        let doubled = recipe(servings: 4).scaled(toServings: 8)
        #expect(doubled.servings == 8)
        #expect(doubled.ingredients.map(\.quantity) == [400, 4, nil])
        let halved = recipe(servings: 4).scaled(toServings: 2)
        #expect(halved.ingredients.map(\.quantity) == [100, 1, nil])
    }

    @Test func unitsAndNamesAreKept() {
        let scaled = recipe(servings: 4).scaled(toServings: 6)
        #expect(scaled.ingredients.map(\.unit) == ["g", nil, nil])
        #expect(scaled.ingredients.map(\.name) == ["Flour", "Eggs", "Salt"])
        #expect(scaled.ingredients[0].quantity == 300)
    }

    @Test func recipesWithoutServingsOrWithInvalidTargetsAreUnchanged() {
        #expect(recipe(servings: nil).scaled(toServings: 8).ingredients.map(\.quantity) == [200, 2, nil])
        #expect(recipe(servings: 0).scaled(toServings: 8).servings == 0)
        #expect(recipe(servings: 4).scaled(toServings: 0).servings == 4)
        #expect(recipe(servings: 4).scaled(toServings: 4).ingredients.map(\.quantity) == [200, 2, nil])
    }

    @Test func scaledByFactorKeepsMissingAmounts() {
        #expect(IngredientItem(id: "s", name: "Salt").scaled(by: 3).quantity == nil)
        #expect(IngredientItem(id: "e", name: "Eggs", quantity: 2).scaled(by: 1.5).quantity == 3)
    }
}
