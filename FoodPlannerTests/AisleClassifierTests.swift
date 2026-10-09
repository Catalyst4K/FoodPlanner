import Testing

@testable import FoodPlanner

@Suite("AisleClassifier")
struct AisleClassifierTests {
    struct Case: CustomTestStringConvertible {
        let name: String
        let aisle: Aisle
        var testDescription: String { name }
    }

    private static func c(_ name: String, _ aisle: Aisle) -> Case { Case(name: name, aisle: aisle) }

    static let cases: [Case] = [
        // Produce
        c("Carrots", .produce), c("tomatoes", .produce), c("Potatoes", .produce), c("red onion", .produce),
        c("fresh basil", .produce), c("bell pepper", .produce), c("Red Pepper", .produce), c("strawberries", .produce),
        c("lemon", .produce), c("garlic", .produce), c("jalapeño", .other),
        // Meat & fish
        c("chicken breast", .meatFish), c("Minced beef", .meatFish), c("bacon", .meatFish),
        c("salmon fillets", .meatFish),
        c("prawns", .meatFish), c("pork sausages", .meatFish),
        // Dairy & eggs
        c("Milk", .dairyEggs), c("eggs", .dairyEggs), c("cheddar cheese", .dairyEggs), c("Butter", .dairyEggs),
        c("greek yoghurt", .dairyEggs), c("sour cream", .dairyEggs), c("cream cheese", .dairyEggs),
        // Bakery
        c("bread", .bakery), c("tortilla wraps", .bakery), c("bagels", .bakery), c("naan", .bakery),
        // Tins & jars
        c("chopped tomatoes", .tinsJars), c("tinned tomatoes", .tinsJars),
        c("canned tuna", .tinsJars),
        c("coconut milk", .tinsJars), c("peanut butter", .tinsJars), c("kidney beans", .tinsJars),
        c("passata", .tinsJars),
        c("honey", .tinsJars), c("tomato puree", .tinsJars),
        // Dry goods
        c("plain flour", .dryGoods), c("sugar", .dryGoods), c("basmati rice", .dryGoods), c("spaghetti", .dryGoods),
        c("rolled oats", .dryGoods), c("baking powder", .dryGoods), c("red lentils", .dryGoods),
        c("almonds", .dryGoods),
        // Spices & condiments
        c("salt", .spicesCondiments), c("black pepper", .spicesCondiments), c("pepper", .spicesCondiments),
        c("ground cumin", .spicesCondiments), c("soy sauce", .spicesCondiments), c("olive oil", .spicesCondiments),
        c("white wine vinegar", .spicesCondiments), c("chicken stock cube", .spicesCondiments),
        c("paprika", .spicesCondiments),
        // Frozen
        c("frozen peas", .frozen), c("ice cream", .frozen), c("Frozen Berries", .frozen),
        // Drinks
        c("orange juice", .drinks), c("sparkling water", .drinks), c("coffee", .drinks),
        // Household
        c("kitchen roll", .household), c("baking paper", .household), c("tin foil", .household),
        // Unknown and empty
        c("dragon scales", .other), c("", .other), c("   ", .other),
    ]

    @Test("classifies", arguments: cases)
    func classifies(_ testCase: Case) {
        #expect(AisleClassifier.aisle(for: testCase.name) == testCase.aisle)
    }

    @Test func aislesAreInWalkingOrderWithOtherLast() {
        #expect(Aisle.allCases.first == .produce)
        #expect(Aisle.allCases.last == .other)
        #expect(Aisle.allCases.allSatisfy { !$0.title.isEmpty && $0.id == $0.rawValue })
        #expect(Set(Aisle.allCases.map(\.title)).count == Aisle.allCases.count)
    }

    @Test func accentsAndCaseDoNotMatter() {
        #expect(AisleClassifier.aisle(for: "CRÈME FRAÎCHE") == .dairyEggs)
        #expect(AisleClassifier.aisle(for: "  Tomatoes ") == .produce)
    }
}

@Suite("ShoppingSection.sectionsByAisle")
struct AisleSectionTests {
    private func item(_ name: String) -> IngredientItem { IngredientItem(id: name, name: name) }

    @Test func groupsInWalkingOrderAndSkipsEmptyAisles() {
        let sections = ShoppingSection.sectionsByAisle(items: [
            item("flour"), item("milk"), item("carrots"), item("dragon scales"), item("eggs"),
        ])
        #expect(sections.map(\.title) == ["Produce", "Dairy & Eggs", "Dry Goods", "Other"])
        #expect(sections.allSatisfy { $0.kind == .aisle })
        #expect(sections[1].items.map(\.name) == ["milk", "eggs"])  // item order kept within an aisle
        #expect(sections.map(\.id) == ["Produce", "Dairy & Eggs", "Dry Goods", "Other"])
    }

    @Test func noItemsGiveNoSections() {
        #expect(ShoppingSection.sectionsByAisle(items: []).isEmpty)
    }
}
