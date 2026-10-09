import Testing

@testable import FoodPlanner

@Suite("IngredientParser")
struct IngredientParserTests {
    struct Case: CustomTestStringConvertible {
        let input: String
        let quantity: Double?
        let unit: String?
        let name: String
        var testDescription: String { "\"\(input)\"" }
    }

    private static func c(_ input: String, _ quantity: Double?, _ unit: String?, _ name: String) -> Case {
        Case(input: input, quantity: quantity, unit: unit, name: name)
    }

    static let cases: [Case] = [
        // Plain amounts and units
        c("200g plain flour", 200, "g", "plain flour"),
        c("200 g plain flour", 200, "g", "plain flour"),
        c("200 grams flour", 200, "g", "flour"),
        c("1.5 kg potatoes", 1.5, "kg", "potatoes"),
        c("1,5 kg potatoes", 1.5, "kg", "potatoes"),
        c("1,000 g flour", 1000, "g", "flour"),
        c("500ml milk", 500, "ml", "milk"),
        c("2 litres water", 2, "l", "water"),
        c("1 tsp salt", 1, "tsp", "salt"),
        c("2 teaspoons salt", 2, "tsp", "salt"),
        c("1 tbsp olive oil", 1, "tbsp", "olive oil"),
        c("3 Tablespoons sugar", 3, "tbsp", "sugar"),
        c("2 cups rice", 2, "cup", "rice"),
        c("8 oz cream cheese", 8, "oz", "cream cheese"),
        c("2 lbs beef", 2, "lb", "beef"),
        c("1 pinch nutmeg", 1, "pinch", "nutmeg"),
        c("2 cloves garlic", 2, "clove", "garlic"),
        c("1 tin chopped tomatoes", 1, "can", "chopped tomatoes"),
        c("2 cans beans", 2, "can", "beans"),
        c("1 packet yeast", 1, "pack", "yeast"),
        c("4 slices bread", 4, "slice", "bread"),
        c("1 bunch parsley", 1, "bunch", "parsley"),
        c("1 tsp. salt", 1, "tsp", "salt"),
        // Fractions
        c("1/2 cup milk", 0.5, "cup", "milk"),
        c("1 1/2 cups flour", 1.5, "cup", "flour"),
        c("1/4 tsp pepper", 0.25, "tsp", "pepper"),
        c("½ cup milk", 0.5, "cup", "milk"),
        c("1½ tbsp sugar", 1.5, "tbsp", "sugar"),
        c("1 ½ tbsp sugar", 1.5, "tbsp", "sugar"),
        c("¾ cup oats", 0.75, "cup", "oats"),
        c("⅓ cup honey", 1.0 / 3, "cup", "honey"),
        c("⅔ cup honey", 2.0 / 3, "cup", "honey"),
        c("¼ tsp cinnamon", 0.25, "tsp", "cinnamon"),
        // Counts (no unit)
        c("3 eggs", 3, nil, "eggs"),
        c("2 large eggs", 2, nil, "large eggs"),
        c("1 onion", 1, nil, "onion"),
        c("12 cherry tomatoes", 12, nil, "cherry tomatoes"),
        // "of" after a unit
        c("2 cups of milk", 2, "cup", "milk"),
        c("1 can of coconut milk", 1, "can", "coconut milk"),
        // Ranges take the upper bound
        c("2-3 cloves garlic", 3, "clove", "garlic"),
        c("2 - 3 cloves garlic", 3, "clove", "garlic"),
        c("2–3 tbsp oil", 3, "tbsp", "oil"),
        c("1 to 2 tsp salt", 2, "tsp", "salt"),
        // No amount at all
        c("salt", nil, nil, "salt"),
        c("salt to taste", nil, nil, "salt to taste"),
        c("fresh basil", nil, nil, "fresh basil"),
        c("Olive oil", nil, nil, "Olive oil"),
        // Whitespace and case
        c("  200g   plain   flour  ", 200, "g", "plain flour"),
        c("200G Flour", 200, "g", "Flour"),
        c("2\tcups\nrice", 2, "cup", "rice"),
        // Things that only look like amounts
        c("7up", nil, nil, "7up"),
        c("3rd generation yeast", nil, nil, "3rd generation yeast"),
        c("5", nil, nil, "5"),
        c("200 g", nil, nil, "200 g"),
        c("1/0 cup mystery", nil, nil, "1/0 cup mystery"),
        c("", nil, nil, ""),
        c("   ", nil, nil, ""),
        // Single-letter units are ambiguous and not accepted
        c("2 t sugar", 2, nil, "t sugar"),
        c("2 T sugar", 2, nil, "T sugar"),
        // Non-latin names survive
        c("2 jalapeños", 2, nil, "jalapeños"),
        c("100 g crème fraîche", 100, "g", "crème fraîche"),
    ]

    @Test("parses", arguments: cases)
    func parses(_ testCase: Case) {
        let parsed = IngredientParser.parse(testCase.input)
        #expect(parsed.name == testCase.name)
        #expect(parsed.unit == testCase.unit)
        switch (parsed.quantity, testCase.quantity) {
        case let (actual?, expected?): #expect(abs(actual - expected) < 0.0001)
        case (nil, nil): break
        default:
            Issue.record("quantity \(String(describing: parsed.quantity)) != \(String(describing: testCase.quantity))")
        }
    }

    @Test func neverCrashesOnOddInput() {
        for input in ["/", "1/", "/2", "1//2", "..", "1..2", "-", "2-", "- 3", "½½", "1 1/", "٣ eggs", "💥", "1e5 g"] {
            _ = IngredientParser.parse(input)
        }
    }
}

@Suite("IngredientUnit")
struct IngredientUnitTests {
    @Test func normalisesSpellingsCaseAndTrailingDots() {
        #expect(IngredientUnit.normalized("Tablespoons") == "tbsp")
        #expect(IngredientUnit.normalized("TSP.") == "tsp")
        #expect(IngredientUnit.normalized("  litres ") == "l")
        #expect(IngredientUnit.normalized("tins") == "can")
        #expect(IngredientUnit.normalized("eggs") == nil)
        #expect(IngredientUnit.normalized("t") == nil)
        #expect(IngredientUnit.normalized("T") == nil)
    }

    @Test func convertsOnlyWithinPairs() {
        #expect(IngredientUnit.convert(1500, from: "g", to: "kg") == 1.5)
        #expect(IngredientUnit.convert(2, from: "kg", to: "g") == 2000)
        #expect(IngredientUnit.convert(250, from: "ml", to: "l") == 0.25)
        #expect(IngredientUnit.convert(1, from: "l", to: "ml") == 1000)
        #expect(IngredientUnit.convert(3, from: "cup", to: "cup") == 3)
        #expect(IngredientUnit.convert(1, from: "g", to: "ml") == nil)
        #expect(IngredientUnit.convert(1, from: "cup", to: "tbsp") == nil)
    }

    @Test func pluralisesWordUnitsOnlyWhenTheAmountIsNotOne() {
        #expect(IngredientUnit.displayName("cup", for: 1) == "cup")
        #expect(IngredientUnit.displayName("cup", for: 2) == "cups")
        #expect(IngredientUnit.displayName("clove", for: 0.5) == "cloves")
        #expect(IngredientUnit.displayName("bunch", for: 2) == "bunches")
        #expect(IngredientUnit.displayName("pinch", for: 3) == "pinches")
        #expect(IngredientUnit.displayName("g", for: 200) == "g")
        #expect(IngredientUnit.displayName("tbsp", for: 2) == "tbsp")
    }
}
