import Foundation

/// Filters recipes by a search query. Foundation-only.
enum RecipeSearch {
    /// Recipes whose title or any ingredient name contains every word of `query`, ignoring case, accents and
    /// extra spaces ("chicken rice" finds a recipe titled "Chicken curry" that lists rice). An empty query keeps
    /// everything. The order of `recipes` is preserved.
    static func filter(_ recipes: [Recipe], query: String) -> [Recipe] {
        let words = IngredientKey.normalized(query).split(separator: " ").map(String.init)
        guard !words.isEmpty else { return recipes }
        return recipes.filter { recipe in
            let haystacks =
                [IngredientKey.normalized(recipe.title)] + recipe.ingredients.map { IngredientKey.normalized($0.name) }
            return words.allSatisfy { word in haystacks.contains { $0.contains(word) } }
        }
    }
}
