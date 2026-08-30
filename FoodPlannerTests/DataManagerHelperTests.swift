//
//  DataManagerHelperTests.swift
//  FoodPlannerTests
//
//  Tests for the pure static helpers on DataManager — no Firebase required.
//

import Testing
import Foundation
@testable import FoodPlanner

@Suite("DataManager helpers")
struct DataManagerHelperTests {

    private func recipe(_ title: String, _ ingredients: [String], id: String? = nil) -> Recipe {
        Recipe(
            id: id ?? UUID().uuidString,
            title: title,
            ingredients: ingredients.map { IngredientItem(id: UUID().uuidString, name: $0) },
            instructions: ""
        )
    }

    private func ingredient(_ name: String) -> IngredientItem {
        IngredientItem(id: UUID().uuidString, name: name)
    }

    // MARK: - ingredientsWithStatus

    @Test("ingredientsWithStatus tags pantry + shopping list membership case-insensitively")
    func ingredientsWithStatus_tags() {
        let r = recipe("Pancakes", ["Flour", "Sugar", "Milk"])
        let pantry = [ingredient("flour")]                 // lowercase to test case-insensitive
        let shopping = [ingredient("MILK")]                // uppercase

        let statuses = DataManager.ingredientsWithStatus(for: r, pantry: pantry, shopping: shopping)

        #expect(statuses.count == 3)
        #expect(statuses[0].ingredient.name == "Flour")
        #expect(statuses[0].isInPantry == true)
        #expect(statuses[0].isInShoppingList == false)

        #expect(statuses[1].ingredient.name == "Sugar")
        #expect(statuses[1].isInPantry == false)
        #expect(statuses[1].isInShoppingList == false)

        #expect(statuses[2].ingredient.name == "Milk")
        #expect(statuses[2].isInPantry == false)
        #expect(statuses[2].isInShoppingList == true)
    }

    // MARK: - hasMissingIngredients

    @Test("hasMissingIngredients returns false only when pantry covers everything")
    func hasMissingIngredients() {
        let r = recipe("Pancakes", ["Flour", "Sugar"])
        #expect(DataManager.hasMissingIngredients(for: r, pantry: []) == true)
        #expect(DataManager.hasMissingIngredients(for: r, pantry: [ingredient("flour")]) == true)
        #expect(DataManager.hasMissingIngredients(for: r, pantry: [ingredient("flour"), ingredient("SUGAR")]) == false)
    }

    // MARK: - matchedIngredientCount

    @Test("matchedIngredientCount counts pantry-covered ingredients")
    func matchedIngredientCount() {
        let r = recipe("Cake", ["Flour", "Sugar", "Eggs", "Butter"])
        let pantry = [ingredient("Flour"), ingredient("eggs"), ingredient("Milk")]  // "Milk" not in recipe
        #expect(DataManager.matchedIngredientCount(for: r, pantry: pantry) == 2)
    }

    // MARK: - recipesSortedByPantryMatch

    @Test("recipesSortedByPantryMatch orders by best match count first")
    func recipesSortedByPantryMatch() {
        let a = recipe("A", ["Flour", "Sugar"])                 // 2 matches
        let b = recipe("B", ["Flour", "Sugar", "Butter"])       // 2 matches (fewer proportionally, but same count)
        let c = recipe("C", ["Salt"])                           // 0 matches
        let pantry = [ingredient("Flour"), ingredient("Sugar")]

        let sorted = DataManager.recipesSortedByPantryMatch(recipes: [c, b, a], pantry: pantry)
        // A and B tie on match count (2 each); C has 0 and must be last
        #expect(sorted.last?.title == "C")
        #expect(sorted.prefix(2).map(\.title).sorted() == ["A", "B"])
    }

    // MARK: - recipesContaining

    @Test("recipesContaining finds all recipes referencing the ingredient (case-insensitive)")
    func recipesContaining() {
        let pancakes = recipe("Pancakes", ["Flour", "Milk", "Eggs"])
        let cake = recipe("Cake", ["Flour", "Sugar"])
        let salad = recipe("Salad", ["Lettuce", "Tomato"])

        let byFlour = DataManager.recipesContaining(ingredient("flour"), in: [pancakes, cake, salad])
        #expect(byFlour.map(\.title) == ["Pancakes", "Cake"])

        let byMilk = DataManager.recipesContaining(ingredient("MILK"), in: [pancakes, cake, salad])
        #expect(byMilk.map(\.title) == ["Pancakes"])

        let byOnion = DataManager.recipesContaining(ingredient("Onion"), in: [pancakes, cake, salad])
        #expect(byOnion.isEmpty)
    }
}
