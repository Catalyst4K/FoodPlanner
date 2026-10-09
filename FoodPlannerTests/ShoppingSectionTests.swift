import Testing

@testable import FoodPlanner

@Suite("ShoppingSection")
struct ShoppingSectionTests {
    private func item(_ name: String) -> IngredientItem { IngredientItem(id: name.lowercased(), name: name) }

    private func recipe(_ id: String, _ title: String, _ ingredients: [String]) -> Recipe {
        Recipe(id: id, title: title, ingredients: ingredients.map { item($0) }, instructions: "")
    }

    @Test func emptyInputsGiveNoSections() {
        #expect(ShoppingSection.sections(items: [], recipes: []).isEmpty)
    }

    @Test func itemsUsedByOneRecipeGroupUnderIt() {
        let sections = ShoppingSection.sections(
            items: [item("Flour"), item("Eggs")], recipes: [recipe("r1", "Pancakes", ["Flour", "Eggs", "Milk"])])
        #expect(sections.count == 1)
        #expect(sections[0].id == "r1")
        #expect(sections[0].title == "Pancakes")
        #expect(sections[0].kind == .singleRecipe)
        #expect(sections[0].items.map(\.name) == ["Flour", "Eggs"])
    }

    @Test func itemsUsedByTwoOrMoreRecipesGoInTheMultiSectionFirst() {
        let recipes = [recipe("r1", "Pancakes", ["Flour", "Eggs"]), recipe("r2", "Bread", ["Flour", "Yeast"])]
        let sections = ShoppingSection.sections(items: [item("Yeast"), item("Flour")], recipes: recipes)
        #expect(sections.map(\.id) == [ShoppingSection.multiRecipeID, "r2"])
        #expect(sections[0].kind == .multiRecipe)
        #expect(sections[0].items.map(\.name) == ["Flour"])
        #expect(sections[1].items.map(\.name) == ["Yeast"])
    }

    @Test func itemsNoRecipeUsesGoLastInOther() {
        let sections = ShoppingSection.sections(
            items: [item("Chocolate"), item("Flour")], recipes: [recipe("r1", "Pancakes", ["Flour"])])
        #expect(sections.map(\.id) == ["r1", ShoppingSection.otherID])
        #expect(sections.last?.kind == .other)
        #expect(sections.last?.title == "Other")
        #expect(sections.last?.items.map(\.name) == ["Chocolate"])
    }

    @Test func recipesWithTheSameTitleStaySeparate() {
        let recipes = [recipe("a", "Soup", ["Carrot"]), recipe("b", "Soup", ["Leek"])]
        let sections = ShoppingSection.sections(items: [item("Leek"), item("Carrot")], recipes: recipes)
        #expect(sections.map(\.id) == ["a", "b"])  // same title: ordered by recipe ID
        #expect(sections.map(\.title) == ["Soup", "Soup"])
        #expect(sections[0].items.map(\.name) == ["Carrot"])
        #expect(sections[1].items.map(\.name) == ["Leek"])
    }

    @Test func recipeSectionsAreSortedByTitleIgnoringCaseAndNumbers() {
        let recipes = [
            recipe("1", "zucchini bake", ["Zucchini"]), recipe("2", "Apple pie", ["Apple"]),
            recipe("3", "Dish 10", ["Ten"]), recipe("4", "Dish 2", ["Two"]),
        ]
        let items = ["Zucchini", "Apple", "Ten", "Two"].map { item($0) }
        let titles = ShoppingSection.sections(items: items, recipes: recipes).map(\.title)
        #expect(titles == ["Apple pie", "Dish 2", "Dish 10", "zucchini bake"])
    }

    @Test func matchingUsesTheNormalisedName() {
        let sections = ShoppingSection.sections(
            items: [item("  jalapeno ")], recipes: [recipe("r1", "Salsa", ["Jalapeño"])])
        #expect(sections.map(\.id) == ["r1"])
    }
}
