import Testing

@testable import FoodPlanner

@Suite("IngredientFormatter")
struct IngredientFormatterTests {
    @Test func formatsAmountUnitAndName() {
        #expect(IngredientFormatter.format(quantity: 200, unit: "g", name: "plain flour") == "200 g plain flour")
        #expect(IngredientFormatter.format(quantity: 1.5, unit: "tbsp", name: "sugar") == "1½ tbsp sugar")
        #expect(IngredientFormatter.format(quantity: 3, unit: nil, name: "eggs") == "3 eggs")
        #expect(IngredientFormatter.format(quantity: 2, unit: "cup", name: "milk") == "2 cups milk")
        #expect(IngredientFormatter.format(quantity: 1, unit: "cup", name: "milk") == "1 cup milk")
    }

    @Test func fallsBackToTheNameWhenThereIsNoUsableAmount() {
        #expect(IngredientFormatter.format(quantity: nil, unit: "g", name: "salt") == "salt")
        #expect(IngredientFormatter.format(quantity: 0, unit: "g", name: "salt") == "salt")
        #expect(IngredientFormatter.format(quantity: -2, unit: nil, name: "salt") == "salt")
        #expect(IngredientFormatter.format(quantity: .infinity, unit: nil, name: "salt") == "salt")
        #expect(IngredientFormatter.format(quantity: 2, unit: "", name: "eggs") == "2 eggs")
    }

    @Test func snapsToCommonFractions() {
        let expected: [(Double, String)] = [
            (0.5, "½"), (0.25, "¼"), (0.75, "¾"), (1.0 / 3, "⅓"), (2.0 / 3, "⅔"), (0.125, "⅛"), (1.5, "1½"),
            (2.25, "2¼"), (2.333, "2⅓"), (0.33, "⅓"),
        ]
        for (value, text) in expected { #expect(IngredientFormatter.formatQuantity(value) == text, "\(value)") }
    }

    @Test func wholeNumbersAndLargeAmountsHaveNoDecimals() {
        #expect(IngredientFormatter.formatQuantity(3) == "3")
        #expect(IngredientFormatter.formatQuantity(3.001) == "3")
        #expect(IngredientFormatter.formatQuantity(2.995) == "3")
        #expect(IngredientFormatter.formatQuantity(250.4) == "250")
        #expect(IngredientFormatter.formatQuantity(1000) == "1000")
    }

    @Test func otherAmountsKeepASensibleNumberOfDecimals() {
        #expect(IngredientFormatter.formatQuantity(2.4) == "2.4")
        #expect(IngredientFormatter.formatQuantity(0.15) == "0.15")
        #expect(IngredientFormatter.formatQuantity(12.46) == "12.5")
        #expect(IngredientFormatter.formatQuantity(10.04) == "10")
    }

    @Test func nonPositiveAmountsFormatAsEmpty() {
        #expect(IngredientFormatter.formatQuantity(0) == "")
        #expect(IngredientFormatter.formatQuantity(-1) == "")
    }

    @Test func formatsAnIngredientItem() {
        let item = IngredientItem(id: "flour", name: "plain flour", quantity: 200, unit: "g")
        #expect(IngredientFormatter.format(item) == "200 g plain flour")
    }

    @Test func parsingTheFormattedTextGivesBackTheSameIngredient() {
        let originals: [(Double?, String?, String)] = [
            (200, "g", "plain flour"), (1.5, "tbsp", "sugar"), (3, nil, "eggs"), (0.25, "tsp", "pepper"),
            (2, "cup", "milk"), (nil, nil, "salt"),
        ]
        for (quantity, unit, name) in originals {
            let text = IngredientFormatter.format(quantity: quantity, unit: unit, name: name)
            let parsed = IngredientParser.parse(text)
            #expect(parsed.name == name, "\(text)")
            #expect(parsed.unit == unit, "\(text)")
            #expect(parsed.quantity == quantity, "\(text)")
        }
    }
}
