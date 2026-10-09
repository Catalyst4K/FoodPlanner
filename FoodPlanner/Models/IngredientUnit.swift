import Foundation

/// Known units and their accepted spellings (docs/IMPLEMENTATION_PLAN.md, Appendix E). Foundation-only.
/// The single-letter `t` and `T` are deliberately not accepted: they are ambiguous.
enum IngredientUnit {
    /// Normalised unit → accepted spellings (lower case, without a trailing dot).
    private static let spellings: [String: [String]] = [
        "g": ["g", "gram", "grams", "gr"],
        "kg": ["kg", "kilo", "kilos", "kilogram", "kilograms"],
        "ml": ["ml", "millilitre", "millilitres", "milliliter", "milliliters"],
        "l": ["l", "litre", "litres", "liter", "liters"],
        "tsp": ["tsp", "teaspoon", "teaspoons"],
        "tbsp": ["tbsp", "tbs", "tablespoon", "tablespoons"],
        "cup": ["cup", "cups"],
        "oz": ["oz", "ounce", "ounces"],
        "lb": ["lb", "lbs", "pound", "pounds"],
        "pinch": ["pinch", "pinches"],
        "clove": ["clove", "cloves"],
        "can": ["can", "cans", "tin", "tins"],
        "pack": ["pack", "packs", "packet", "packets"],
        "slice": ["slice", "slices"],
        "bunch": ["bunch", "bunches"],
    ]

    private static let lookup: [String: String] = {
        var table: [String: String] = [:]
        for (unit, words) in spellings {
            for word in words { table[word] = unit }
        }
        return table
    }()

    /// The normalised unit for a spelling such as "Tablespoons" or "tsp.", or nil if it isn't a unit.
    static func normalized(_ word: String) -> String? {
        var key = word.trimmingCharacters(in: .whitespaces).lowercased()
        if key.hasSuffix(".") { key.removeLast() }
        return lookup[key]
    }

    /// Units that can be converted into each other when merging: (smaller, larger, factor).
    private static let conversions: [(small: String, large: String, factor: Double)] = [
        ("g", "kg", 1000), ("ml", "l", 1000),
    ]

    /// Converts `quantity` between two units if they are a convertible pair (g↔kg, ml↔l), else nil.
    static func convert(_ quantity: Double, from: String, to: String) -> Double? {
        if from == to { return quantity }
        for pair in conversions {
            if from == pair.small && to == pair.large { return quantity / pair.factor }
            if from == pair.large && to == pair.small { return quantity * pair.factor }
        }
        return nil
    }

    /// Display form of a normalised unit for the given quantity ("cup" → "cups" unless the amount is 1).
    static func displayName(_ unit: String, for quantity: Double) -> String {
        guard quantity != 1 else { return unit }
        switch unit {
        case "cup", "clove", "can", "pack", "slice": return unit + "s"
        case "bunch", "pinch": return unit + "es"
        default: return unit
        }
    }
}
