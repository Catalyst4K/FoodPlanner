import Testing

@testable import FoodPlanner

@Suite("RecipeSort")
struct SortOptionsTests {
    private func item(_ name: String) -> IngredientItem { IngredientItem(id: name.lowercased(), name: name) }

    private func recipe(_ title: String, _ ingredients: [String], id: String? = nil) -> Recipe {
        Recipe(id: id ?? title, title: title, ingredients: ingredients.map { item($0) }, instructions: "")
    }

    private func titles(_ sort: RecipeSort, _ recipes: [Recipe], pantry: [String] = []) -> [String] {
        RecipeSort.sorted(recipes, by: sort, pantry: pantry.map { item($0) }).map(\.title)
    }

    // MARK: - pantryMatch (DEC-5)

    @Test func fewestMissingIngredientsComesFirst() {
        // Cookable now (0 missing) beats a bigger recipe that has more matches in absolute terms.
        let small = recipe("Toast", ["Bread"])
        let big = recipe("Feast", ["Flour", "Sugar", "Butter", "Eggs", "Milk", "Vanilla"])
        #expect(
            titles(.pantryMatch, [big, small], pantry: ["Bread", "Flour", "Sugar", "Butter", "Eggs"]) == [
                "Toast", "Feast",
            ])
    }

    @Test func tiesOnMissingCountPreferTheHigherShare() {
        // Both miss exactly one ingredient; "Trio" has 2 of 3 in the pantry, "Pair" only 1 of 2.
        let pair = recipe("Pair", ["A", "Z"])
        let trio = recipe("Trio", ["A", "B", "Z"])
        #expect(titles(.pantryMatch, [pair, trio], pantry: ["A", "B"]) == ["Trio", "Pair"])
    }

    @Test func remainingTiesFallBackToName() {
        let b = recipe("banana bread", ["X"])
        let a = recipe("Apple pie", ["X"])
        #expect(titles(.pantryMatch, [b, a]) == ["Apple pie", "banana bread"])
    }

    @Test func pantryMatchIgnoresCaseAndAccents() {
        let salsa = recipe("Salsa", ["Jalapeño"])
        let toast = recipe("Toast", ["Bread"])
        #expect(titles(.pantryMatch, [toast, salsa], pantry: ["jalapeno"]) == ["Salsa", "Toast"])
    }

    @Test func recipesWithNoIngredientsDoNotBreakOrdering() {
        let empty = recipe("Empty", [])
        let one = recipe("One", ["A"])
        // Neither is missing anything; the empty recipe has no matches at all, so it ranks after.
        #expect(titles(.pantryMatch, [empty, one], pantry: ["A"]) == ["One", "Empty"])
    }

    // MARK: - name and newest

    @Test func nameSortIgnoresCaseAndOrdersNumbersNaturally() {
        let recipes = [
            recipe("zucchini bake", []), recipe("Apple pie", []), recipe("Dish 10", []), recipe("Dish 2", []),
        ]
        #expect(titles(.name, recipes) == ["Apple pie", "Dish 2", "Dish 10", "zucchini bake"])
    }

    @Test func sameTitlesAreOrderedByIDSoTheOrderIsStable() {
        let b = recipe("Soup", [], id: "b")
        let a = recipe("Soup", [], id: "a")
        #expect(RecipeSort.sorted([b, a], by: .name, pantry: []).map(\.id) == ["a", "b"])
    }

    @Test func newestKeepsTheListenersOrder() {
        let recipes = [recipe("Third", []), recipe("First", []), recipe("Second", [])]
        #expect(titles(.newest, recipes) == ["Third", "First", "Second"])
    }

    // MARK: - options

    @Test func everyOptionHasATitleAndStableRawValue() {
        #expect(RecipeSort.allCases.map(\.rawValue) == ["pantryMatch", "name", "newest"])
        #expect(ShoppingSort.allCases.map(\.rawValue) == ["newest", "byRecipe", "byAisle"])
        #expect(RecipeSort.allCases.allSatisfy { !$0.title.isEmpty && $0.id == $0.rawValue })
        #expect(ShoppingSort.allCases.allSatisfy { !$0.title.isEmpty && $0.id == $0.rawValue })
    }
}
