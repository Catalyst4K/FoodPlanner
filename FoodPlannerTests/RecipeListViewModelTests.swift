//
//  RecipeListViewModelTests.swift
//  FoodPlannerTests
//

import Testing
import Foundation
@testable import FoodPlanner

@Suite("RecipeListViewModel")
struct RecipeListViewModelTests {

    @Test("Fresh view model has no ingredients and is invalid")
    func initialState() {
        let vm = RecipeListViewModel()
        #expect(vm.title == "")
        #expect(vm.instructions == "")
        #expect(vm.ingredients.isEmpty)
        #expect(vm.isFormValid() == false)
        #expect(vm.buildRecipe() == nil)
    }

    @Test("addIngredient appends trimmed, non-empty values")
    func addIngredientAppends() {
        let vm = RecipeListViewModel()
        vm.addIngredient(name: "  Milk  ")
        #expect(vm.ingredients.count == 1)
        #expect(vm.ingredients.first?.name == "Milk")
    }

    @Test("addIngredient ignores empty or whitespace-only names")
    func addIngredientIgnoresEmpty() {
        let vm = RecipeListViewModel()
        vm.addIngredient(name: "")
        vm.addIngredient(name: "   ")
        vm.addIngredient(name: "\n\t")
        #expect(vm.ingredients.isEmpty)
    }

    @Test("addIngredient skips case-insensitive duplicates")
    func addIngredientSkipsDuplicates() {
        let vm = RecipeListViewModel()
        vm.addIngredient(name: "Milk")
        vm.addIngredient(name: "milk")
        vm.addIngredient(name: "MILK")
        #expect(vm.ingredients.count == 1)
        #expect(vm.ingredients.first?.name == "Milk")
    }

    @Test("removeIngredient removes by id")
    func removeIngredient() {
        let vm = RecipeListViewModel()
        vm.addIngredient(name: "Milk")
        vm.addIngredient(name: "Eggs")
        let milkId = vm.ingredients[0].id
        vm.removeIngredient(id: milkId)
        #expect(vm.ingredients.count == 1)
        #expect(vm.ingredients.first?.name == "Eggs")
    }

    @Test("removeIngredient with unknown id is a no-op")
    func removeIngredientUnknown() {
        let vm = RecipeListViewModel()
        vm.addIngredient(name: "Milk")
        vm.removeIngredient(id: "does-not-exist")
        #expect(vm.ingredients.count == 1)
    }

    @Test("isFormValid requires both a title and at least one ingredient")
    func isFormValid() {
        let vm = RecipeListViewModel()
        #expect(vm.isFormValid() == false)

        vm.title = "Pancakes"
        #expect(vm.isFormValid() == false, "still no ingredients")

        vm.addIngredient(name: "Flour")
        #expect(vm.isFormValid() == true)

        vm.title = "   "
        #expect(vm.isFormValid() == false, "whitespace-only title is invalid")
    }

    @Test("buildRecipe returns nil when form is invalid")
    func buildRecipeInvalid() {
        let vm = RecipeListViewModel()
        vm.title = "Only Title"
        #expect(vm.buildRecipe() == nil)

        vm.title = ""
        vm.addIngredient(name: "Flour")
        #expect(vm.buildRecipe() == nil)
    }

    @Test("buildRecipe trims whitespace on title and instructions")
    func buildRecipeTrims() throws {
        let vm = RecipeListViewModel()
        vm.title = "  Pancakes  "
        vm.instructions = "\nMix well.\n"
        vm.addIngredient(name: "Flour")

        let recipe = try #require(vm.buildRecipe())
        #expect(recipe.title == "Pancakes")
        #expect(recipe.instructions == "Mix well.")
        #expect(recipe.ingredients.map(\.name) == ["Flour"])
    }

    @Test("resetForm clears title, instructions, and ingredients")
    func resetForm() {
        let vm = RecipeListViewModel()
        vm.title = "Pancakes"
        vm.instructions = "Mix"
        vm.addIngredient(name: "Flour")

        vm.resetForm()
        #expect(vm.title == "")
        #expect(vm.instructions == "")
        #expect(vm.ingredients.isEmpty)
    }

    @Test("Editing init pre-fills state from an existing recipe")
    func editingInit() {
        let original = Recipe(
            id: "original-id",
            title: "Original",
            ingredients: [
                IngredientItem(id: "fs-1", name: "Flour"),
                IngredientItem(id: "fs-2", name: "Sugar", quantity: 2.5, unit: "cups")
            ],
            instructions: "Mix and bake."
        )

        let vm = RecipeListViewModel(editing: original)
        #expect(vm.title == "Original")
        #expect(vm.instructions == "Mix and bake.")
        #expect(vm.ingredients.count == 2)
        #expect(vm.ingredients.map(\.name) == ["Flour", "Sugar"])
        #expect(vm.ingredients[1].quantity == 2.5)
        #expect(vm.ingredients[1].unit == "cups")
        // IDs should be freshly generated, not the Firestore ingredient IDs
        #expect(vm.ingredients.allSatisfy { $0.id != "fs-1" && $0.id != "fs-2" })
    }
}
