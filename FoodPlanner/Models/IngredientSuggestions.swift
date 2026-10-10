import Foundation

/// Autocomplete for the quick-add rows: suggests ingredient names the user has already used. Foundation-only.
enum IngredientSuggestions {
    static let maxSuggestions = 5

    /// Names from `known` that start with what is being typed, one per ingredient (de-duplicated by key, keeping the
    /// first spelling seen), sorted A to Z and capped at `limit`. Only the name part of the text is matched, so
    /// "2 cups mi" suggests "Milk". Nothing is suggested for an empty name or an exact match.
    static func suggestions(for text: String, known: [String], limit: Int = maxSuggestions) -> [String] {
        let typed = IngredientKey.normalized(IngredientParser.parse(text).name)
        guard !typed.isEmpty else { return [] }

        var seen = Set<String>()
        var matches: [String] = []
        for name in known {
            let key = IngredientKey.normalized(name)
            guard !key.isEmpty, key != typed, key.hasPrefix(typed), seen.insert(key).inserted else { continue }
            matches.append(name)
        }
        matches.sort { $0.localizedStandardCompare($1) == .orderedAscending }
        return Array(matches.prefix(limit))
    }

    /// The text to put in the field after the user picks `suggestion`: any amount they already typed is kept
    /// ("2 cups mi" + "Milk" → "2 cups Milk").
    static func completing(_ text: String, with suggestion: String) -> String {
        let parsed = IngredientParser.parse(text)
        return IngredientFormatter.format(quantity: parsed.quantity, unit: parsed.unit, name: suggestion)
    }
}
