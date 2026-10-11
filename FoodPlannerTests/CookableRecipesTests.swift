import Testing

@testable import FoodPlanner

@Suite("CookableRecipes")
struct CookableRecipesTests {
    private func item(_ name: String) -> IngredientItem {
        IngredientItem(id: IngredientKey.documentID(for: name), name: name)
    }

    private func recipe(_ title: String, _ names: [String]) -> Recipe {
        Recipe(id: title, title: title, ingredients: names.map(item), instructions: "")
    }

    private let pantry = ["Rigatoni", "Cream", "Courgette", "Garlic"].map { IngredientItem(id: $0, name: $0) }

    @Test func groupsByMissingCountFewestFirst() {
        let ready = recipe("Creamy Rigatoni", ["rigatoni", "Cream", "courgette"])
        let one = recipe("Garlic Pasta", ["Rigatoni", "garlic", "Parmesan"])
        let two = recipe("Carbonara", ["Rigatoni", "Egg", "Guanciale"])
        let three = recipe("Beef Wellington", ["Beef", "Pastry", "Mushrooms"])
        let groups = CookableRecipes.groups([three, two, one, ready], pantry: pantry)
        #expect(groups.map(\.missing) == [0, 1, 2])
        #expect(groups.map { $0.recipes.map(\.title) } == [["Creamy Rigatoni"], ["Garlic Pasta"], ["Carbonara"]])
    }

    @Test func titlesDescribeTheGap() {
        #expect(CookableRecipes.Group(missing: 0, recipes: []).title == "Ready to cook")
        #expect(CookableRecipes.Group(missing: 1, recipes: []).title == "Missing 1 ingredient")
        #expect(CookableRecipes.Group(missing: 2, recipes: []).title == "Missing 2 ingredients")
    }

    @Test func emptyGroupsAreOmittedAndRecipesAreSortedWithinAGroup() {
        let b = recipe("Banana toast", ["Rigatoni"])
        let a = recipe("Apple toast", ["Cream"])
        let groups = CookableRecipes.groups([b, a], pantry: pantry)
        #expect(groups.count == 1)
        #expect(groups[0].recipes.map(\.title) == ["Apple toast", "Banana toast"])
    }

    @Test func duplicateAndBlankIngredientsAreNotCountedTwice() {
        let r = recipe("Double", ["Egg", "egg ", "   ", "Cream"])
        #expect(CookableRecipes.missingCount(for: r, pantry: pantry) == 1)
    }

    @Test func recipesWithoutIngredientsAreLeftOut() {
        let empty = recipe("Nothing", [])
        let blank = recipe("Blank", ["  "])
        #expect(CookableRecipes.groups([empty, blank], pantry: pantry).isEmpty)
    }

    @Test func aCustomLimitWidensTheList() {
        let three = recipe("Beef Wellington", ["Beef", "Pastry", "Mushrooms"])
        #expect(CookableRecipes.groups([three], pantry: pantry).isEmpty)
        #expect(CookableRecipes.groups([three], pantry: pantry, limit: 3).map(\.missing) == [3])
    }
}
