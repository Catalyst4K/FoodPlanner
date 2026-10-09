import Foundation

struct Recipe: Identifiable {
    var id: String
    var title: String
    var ingredients: [IngredientItem]
    var instructions: String
    var ownerId: String = ""  // Set by DataManager on write
    var isShared: Bool = false
    var servings: Int?

    /// The recipe scaled to `target` servings: every amount is multiplied by target ÷ servings. A recipe with no
    /// servings (or an invalid target) is returned unchanged.
    func scaled(toServings target: Int) -> Recipe {
        guard let servings, servings > 0, target > 0, target != servings else { return self }
        let factor = Double(target) / Double(servings)
        var copy = self
        copy.ingredients = ingredients.map { $0.scaled(by: factor) }
        copy.servings = target
        return copy
    }
}
