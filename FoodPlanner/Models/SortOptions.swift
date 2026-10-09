import Foundation

/// How the recipe list is ordered. Raw values are stored in `@AppStorage`, so don't rename them.
enum RecipeSort: String, CaseIterable, Identifiable {
    case pantryMatch, name, newest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pantryMatch: "Pantry match"
        case .name: "Name"
        case .newest: "Newest"
        }
    }

    /// Orders `recipes`, which arrive newest-first from the listener.
    /// - `pantryMatch`: fewest missing ingredients first, then the higher share already in the pantry, then name.
    /// - `name`: A to Z, ignoring case and treating numbers naturally ("Dish 2" before "Dish 10").
    /// - `newest`: unchanged.
    static func sorted(_ recipes: [Recipe], by sort: RecipeSort, pantry: [IngredientItem]) -> [Recipe] {
        switch sort {
        case .newest:
            return recipes
        case .name:
            return recipes.sorted { byName($0, $1) }
        case .pantryMatch:
            let pantryKeys = Set(pantry.map { IngredientKey.normalized($0.name) })
            func matched(_ recipe: Recipe) -> Int {
                recipe.ingredients.filter { pantryKeys.contains(IngredientKey.normalized($0.name)) }.count
            }
            func missing(_ recipe: Recipe) -> Int { recipe.ingredients.count - matched(recipe) }
            func ratio(_ recipe: Recipe) -> Double {
                recipe.ingredients.isEmpty ? 0 : Double(matched(recipe)) / Double(recipe.ingredients.count)
            }
            return recipes.sorted { a, b in
                if missing(a) != missing(b) { return missing(a) < missing(b) }
                if ratio(a) != ratio(b) { return ratio(a) > ratio(b) }
                return byName(a, b)
            }
        }
    }

    /// Title order, with the recipe ID as a stable tie-break.
    static func byName(_ a: Recipe, _ b: Recipe) -> Bool {
        let order = a.title.localizedStandardCompare(b.title)
        return order == .orderedSame ? a.id < b.id : order == .orderedAscending
    }
}

/// How the shopping list is arranged. Raw values are stored in `@AppStorage`.
enum ShoppingSort: String, CaseIterable, Identifiable {
    case newest, byRecipe

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newest: "Newest"
        case .byRecipe: "Group by recipe"
        }
    }
}
