import Foundation

/// A supermarket section, in the order a shopper usually walks the shop.
enum Aisle: String, CaseIterable, Identifiable {
    case produce = "Produce"
    case meatFish = "Meat & Fish"
    case dairyEggs = "Dairy & Eggs"
    case bakery = "Bakery"
    case tinsJars = "Tins & Jars"
    case dryGoods = "Dry Goods"
    case spicesCondiments = "Spices & Condiments"
    case frozen = "Frozen"
    case drinks = "Drinks"
    case household = "Household"
    case other = "Other"

    var id: String { rawValue }
    var title: String { rawValue }
}

/// Guesses the aisle for an ingredient from its name. A small keyword table, not a database: anything it
/// doesn't recognise lands in `.other`. Foundation-only.
enum AisleClassifier {
    static func aisle(for name: String) -> Aisle {
        let normalized = IngredientKey.normalized(name)
        guard !normalized.isEmpty else { return .other }
        let tokens = normalized.split(separator: " ").map(String.init)

        // Modifiers that decide the aisle whatever the food is ("frozen peas", "tinned tomatoes").
        if tokens.contains("frozen") { return .frozen }
        if !Set(tokens).isDisjoint(with: ["tinned", "canned", "jarred"]) { return .tinsJars }

        // Multi-word names whose last word would mislead ("coconut milk", "black pepper").
        for (phrase, aisle) in phrases where normalized.contains(phrase) { return aisle }

        // Otherwise the last word is usually the thing itself ("plain flour", "chicken breast" → breast? no:
        // try it, then fall back through the earlier words).
        for token in tokens.reversed() {
            for candidate in [token, singular(token)] {
                if let aisle = words[candidate] { return aisle }
            }
        }
        return .other
    }

    private static func singular(_ word: String) -> String {
        if word.hasSuffix("ies"), word.count > 4 { return String(word.dropLast(3)) + "y" }
        if word.hasSuffix("oes") { return String(word.dropLast(2)) }
        for ending in ["ches", "shes", "sses", "xes"] where word.hasSuffix(ending) { return String(word.dropLast(2)) }
        if word.hasSuffix("s"), !word.hasSuffix("ss"), word.count > 2 { return String(word.dropLast()) }
        return word
    }

    // MARK: - Tables

    private static let phrases: [(String, Aisle)] = [
        ("coconut milk", .tinsJars), ("coconut cream", .tinsJars), ("peanut butter", .tinsJars),
        ("tomato puree", .tinsJars), ("tomato paste", .tinsJars), ("chopped tomato", .tinsJars),
        ("baked bean", .tinsJars), ("kidney bean", .tinsJars), ("black bean", .tinsJars),
        ("black pepper", .spicesCondiments), ("bell pepper", .produce), ("red pepper", .produce),
        ("green pepper", .produce), ("yellow pepper", .produce), ("chilli pepper", .produce),
        ("chilli powder", .spicesCondiments), ("curry powder", .spicesCondiments),
        ("curry paste", .tinsJars), ("soy sauce", .spicesCondiments), ("tomato ketchup", .spicesCondiments),
        ("stock cube", .spicesCondiments), ("vanilla extract", .spicesCondiments), ("olive oil", .spicesCondiments),
        ("baking powder", .dryGoods), ("baking soda", .dryGoods), ("baking paper", .household),
        ("ice cream", .frozen), ("fish finger", .frozen), ("orange juice", .drinks), ("apple juice", .drinks),
        ("sour cream", .dairyEggs), ("creme fraiche", .dairyEggs), ("cream cheese", .dairyEggs),
        ("kitchen roll", .household), ("cling film", .household), ("bin bag", .household),
        ("toilet paper", .household), ("washing up liquid", .household), ("tin foil", .household),
    ]

    private static let words: [String: Aisle] = {
        let groups: [(Aisle, [String])] = [
            (
                .produce,
                [
                    "apple", "banana", "orange", "lemon", "lime", "tomato", "potato", "onion", "garlic", "carrot",
                    "broccoli", "spinach", "lettuce", "cucumber", "mushroom", "courgette", "zucchini",
                    "aubergine", "eggplant", "celery", "leek", "cabbage", "cauliflower", "avocado", "ginger",
                    "basil", "parsley", "coriander", "mint", "rosemary", "thyme", "dill", "chive", "strawberry",
                    "blueberry", "raspberry", "berry", "grape", "mango", "pineapple", "melon", "pear", "peach",
                    "plum", "cherry", "kale", "beetroot", "pumpkin", "squash", "radish", "asparagus", "shallot",
                    "salad", "rocket", "sweetcorn", "chilli", "fruit", "veg", "vegetable", "herb",
                ]
            ),
            (
                .meatFish,
                [
                    "chicken", "beef", "pork", "lamb", "bacon", "sausage", "ham", "turkey", "mince", "steak",
                    "salmon", "tuna", "cod", "prawn", "shrimp", "fish", "duck", "chorizo", "salami", "breast",
                    "thigh", "fillet", "haddock", "mackerel", "sardine", "meat", "burger",
                ]
            ),
            (
                .dairyEggs,
                [
                    "milk", "cheese", "butter", "cream", "yoghurt", "yogurt", "egg", "parmesan", "mozzarella",
                    "cheddar", "feta", "margarine", "halloumi", "ricotta", "custard", "cottage",
                ]
            ),
            (
                .bakery,
                [
                    "bread", "bun", "roll", "bagel", "tortilla", "wrap", "pitta", "pita", "naan", "croissant",
                    "baguette", "sourdough", "muffin", "crumpet", "brioche",
                ]
            ),
            (
                .tinsJars,
                [
                    "passata", "jam", "honey", "olive", "pickle", "chutney", "marmalade", "tahini", "pesto",
                    "tin", "can", "jar", "bean", "chickpea",
                ]
            ),
            (
                .dryGoods,
                [
                    "flour", "sugar", "rice", "pasta", "spaghetti", "penne", "noodle", "oat", "cereal", "lentil",
                    "couscous", "quinoa", "yeast", "cocoa", "nut", "almond", "walnut", "cashew", "raisin",
                    "breadcrumb", "cornflour", "semolina", "muesli", "granola", "polenta", "bulgur", "biscuit",
                    "cracker", "chocolate", "seed",
                ]
            ),
            (
                .spicesCondiments,
                [
                    "salt", "pepper", "cumin", "paprika", "turmeric", "cinnamon", "oregano", "nutmeg", "spice",
                    "seasoning",
                    "ketchup", "mayonnaise", "mayo", "mustard", "vinegar", "oil", "sauce", "stock", "syrup",
                    "cardamom", "clove", "cayenne", "saffron", "garam", "masala", "bouillon", "marinade",
                ]
            ),
            (.frozen, ["ice"]),
            (
                .drinks,
                ["water", "juice", "wine", "beer", "cola", "coffee", "tea", "lemonade", "soda", "cider", "squash"]
            ),
            (.household, ["foil", "napkin", "detergent", "sponge", "tissue", "bleach", "soap"]),
        ]
        var table: [String: Aisle] = [:]
        // Earlier groups win on the rare word listed twice (e.g. "squash" is produce).
        for (aisle, list) in groups.reversed() {
            for word in list { table[word] = aisle }
        }
        return table
    }()
}
