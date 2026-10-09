import Testing

@testable import FoodPlanner

@Suite("RecipeSearch")
struct RecipeSearchTests {
    private func recipe(_ title: String, _ ingredients: [String]) -> Recipe {
        Recipe(
            id: title, title: title, ingredients: ingredients.map { IngredientItem(id: $0, name: $0) }, instructions: ""
        )
    }

    private let soup = Recipe(
        id: "soup", title: "Carrot Soup",
        ingredients: [IngredientItem(id: "c", name: "Carrot"), IngredientItem(id: "o", name: "Onion")],
        instructions: "")
    private let salsa = Recipe(
        id: "salsa", title: "Salsa",
        ingredients: [IngredientItem(id: "j", name: "Jalapeño"), IngredientItem(id: "t", name: "Tomato")],
        instructions: "")
    private let curry = Recipe(
        id: "curry", title: "Chicken Curry",
        ingredients: [IngredientItem(id: "ch", name: "Chicken"), IngredientItem(id: "r", name: "Basmati rice")],
        instructions: "")

    private func ids(_ query: String) -> [String] {
        RecipeSearch.filter([soup, salsa, curry], query: query).map(\.id)
    }

    @Test func emptyOrBlankQueriesKeepEverythingInOrder() {
        #expect(ids("") == ["soup", "salsa", "curry"])
        #expect(ids("   ") == ["soup", "salsa", "curry"])
    }

    @Test func matchesTheTitle() {
        #expect(ids("soup") == ["soup"])
        #expect(ids("curry") == ["curry"])
    }

    @Test func matchesAnIngredientNameBySubstring() {
        #expect(ids("tomat") == ["salsa"])
        #expect(ids("rice") == ["curry"])
    }

    @Test func ignoresCaseAccentsAndExtraSpaces() {
        #expect(ids("JALAPENO") == ["salsa"])
        #expect(ids("  carrot  ") == ["soup"])
    }

    @Test func everyWordMustMatchSomewhere() {
        #expect(ids("chicken rice") == ["curry"])
        #expect(ids("carrot onion") == ["soup"])
        #expect(ids("carrot tomato") == [])
    }

    @Test func noMatchGivesNoResults() {
        #expect(ids("pizza") == [])
    }

    @Test func preservesTheInputOrder() {
        let result = RecipeSearch.filter([curry, soup], query: "r")
        #expect(result.map(\.id) == ["curry", "soup"])
    }
}
