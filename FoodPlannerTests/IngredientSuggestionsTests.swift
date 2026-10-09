import Testing

@testable import FoodPlanner

@Suite("IngredientSuggestions")
struct IngredientSuggestionsTests {
    private let known = [
        "Milk", "Mint", "minced beef", "Mushrooms", "Olive oil", "Onion", "olive oil", "Jalapeño", "Eggs",
    ]

    @Test func suggestsNamesThatStartWithWhatIsTyped() {
        #expect(IngredientSuggestions.suggestions(for: "mi", known: known) == ["Milk", "minced beef", "Mint"])
        #expect(IngredientSuggestions.suggestions(for: "o", known: known) == ["Olive oil", "Onion"])
    }

    @Test func matchingIgnoresCaseAccentsAndWhitespace() {
        #expect(IngredientSuggestions.suggestions(for: "  JALAP", known: known) == ["Jalapeño"])
        #expect(IngredientSuggestions.suggestions(for: "OLIVE   O", known: known) == ["Olive oil"])
    }

    @Test func duplicatesByKeyAreSuggestedOnceKeepingTheFirstSpelling() {
        #expect(IngredientSuggestions.suggestions(for: "olive", known: known) == ["Olive oil"])
    }

    @Test func anExactMatchOrEmptyInputSuggestsNothing() {
        #expect(IngredientSuggestions.suggestions(for: "milk", known: known).isEmpty)
        #expect(IngredientSuggestions.suggestions(for: "", known: known).isEmpty)
        #expect(IngredientSuggestions.suggestions(for: "   ", known: known).isEmpty)
        #expect(IngredientSuggestions.suggestions(for: "zzz", known: known).isEmpty)
    }

    @Test func onlyTheNamePartOfTheTextIsMatched() {
        #expect(IngredientSuggestions.suggestions(for: "2 cups mi", known: known) == ["Milk", "minced beef", "Mint"])
        #expect(IngredientSuggestions.suggestions(for: "200g mush", known: known) == ["Mushrooms"])
    }

    @Test func resultsAreCappedAtTheLimit() {
        let many = (1...20).map { "Apple \($0)" }
        #expect(IngredientSuggestions.suggestions(for: "app", known: many).count == 5)
        #expect(IngredientSuggestions.suggestions(for: "app", known: many, limit: 2) == ["Apple 1", "Apple 2"])
    }

    @Test func numbersAreSortedNaturally() {
        let names = ["Dish 10", "Dish 2", "Dish 1"]
        #expect(IngredientSuggestions.suggestions(for: "dis", known: names) == ["Dish 1", "Dish 2", "Dish 10"])
    }

    @Test func completingKeepsAnAmountTheUserAlreadyTyped() {
        #expect(IngredientSuggestions.completing("2 cups mi", with: "Milk") == "2 cups Milk")
        #expect(IngredientSuggestions.completing("200g mush", with: "Mushrooms") == "200 g Mushrooms")
        #expect(IngredientSuggestions.completing("mi", with: "Milk") == "Milk")
    }
}
