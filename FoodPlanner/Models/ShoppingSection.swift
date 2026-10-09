import Foundation

/// A group of shopping-list items shown under one heading when the list is grouped by recipe.
struct ShoppingSection: Identifiable {
    enum Kind { case multiRecipe, singleRecipe, other }

    /// A recipe's ID for single-recipe sections (so two recipes with the same title stay separate).
    let id: String
    let title: String
    let items: [IngredientItem]
    let kind: Kind

    static let multiRecipeID = "__multi"
    static let otherID = "__other"

    /// Groups `items` by the recipes that use them: items used by two or more recipes first, then one section
    /// per recipe (sorted by title, ties broken by recipe ID), then items no recipe uses. Item order within a
    /// section follows `items`. Ingredients are matched with `IngredientKey`.
    static func sections(items: [IngredientItem], recipes: [Recipe]) -> [ShoppingSection] {
        var multi: [IngredientItem] = []
        var perRecipe: [String: (title: String, items: [IngredientItem])] = [:]
        var other: [IngredientItem] = []

        for item in items {
            let key = IngredientKey.normalized(item.name)
            let using = recipes.filter { recipe in
                recipe.ingredients.contains { IngredientKey.normalized($0.name) == key }
            }
            if using.count >= 2 {
                multi.append(item)
            } else if let recipe = using.first {
                perRecipe[recipe.id, default: (recipe.title, [])].items.append(item)
            } else {
                other.append(item)
            }
        }

        var sections: [ShoppingSection] = []
        if !multi.isEmpty {
            sections.append(
                ShoppingSection(id: multiRecipeID, title: "Used in multiple recipes", items: multi, kind: .multiRecipe))
        }
        let ordered = perRecipe.sorted { a, b in
            let order = a.value.title.localizedStandardCompare(b.value.title)
            return order == .orderedSame ? a.key < b.key : order == .orderedAscending
        }
        for (id, entry) in ordered {
            sections.append(ShoppingSection(id: id, title: entry.title, items: entry.items, kind: .singleRecipe))
        }
        if !other.isEmpty {
            sections.append(ShoppingSection(id: otherID, title: "Other", items: other, kind: .other))
        }
        return sections
    }
}
