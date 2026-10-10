import Foundation

/// "What can I cook?": recipes grouped by how many ingredients the pantry is missing. Foundation-only.
enum CookableRecipes {
    struct Group {
        /// How many distinct ingredients are missing from the pantry (0 = cook it now).
        let missing: Int
        let recipes: [Recipe]

        var title: String {
            switch missing {
            case 0: "Ready to cook"
            case 1: "Missing 1 ingredient"
            default: "Missing \(missing) ingredients"
            }
        }
    }

    /// Distinct ingredients of `recipe` that aren't in the pantry (matched by normalised name).
    static func missingCount(for recipe: Recipe, pantry: [IngredientItem]) -> Int {
        let have = Set(pantry.map { IngredientKey.normalized($0.name) })
        let needed = Set(recipe.ingredients.map { IngredientKey.normalized($0.name) }.filter { !$0.isEmpty })
        return needed.subtracting(have).count
    }

    /// Recipes missing at most `limit` ingredients, grouped fewest-missing first and A to Z within a group.
    /// Recipes with no ingredients are left out: "ready to cook" says nothing about them.
    static func groups(_ recipes: [Recipe], pantry: [IngredientItem], limit: Int = 2) -> [Group] {
        let candidates = recipes.filter { recipe in
            recipe.ingredients.contains { !IngredientKey.normalized($0.name).isEmpty }
        }
        let byMissing = Dictionary(grouping: candidates) { missingCount(for: $0, pantry: pantry) }
        return (0...max(limit, 0)).compactMap { missing in
            guard let members = byMissing[missing] else { return nil }
            return Group(missing: missing, recipes: RecipeSort.sorted(members, by: .name, pantry: pantry))
        }
    }
}
