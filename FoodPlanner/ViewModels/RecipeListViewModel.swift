import SwiftUI

/// Owns the transient form state for AddRecipeView. Reads/writes recipes via DataManager.
class RecipeListViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var ingredients: [IngredientItem] = []
    @Published var instructions: String = ""

    init() {}

    /// Prefill the form with an existing recipe for editing.
    init(editing recipe: Recipe) {
        load(from: recipe)
    }

    /// Repopulate the form from an existing recipe. Lets a single long-lived view model
    /// (e.g. a `@StateObject` on RecipeDetailView) be reused across successive edits,
    /// since a `@StateObject` is only constructed once and can't be re-`init`ed.
    func load(from recipe: Recipe) {
        self.title = recipe.title
        self.instructions = recipe.instructions
        self.ingredients = recipe.ingredients.map {
            IngredientItem(id: UUID().uuidString, name: $0.name, quantity: $0.quantity, unit: $0.unit)
        }
    }

    /// Appends a committed ingredient to the local list.
    func addIngredient(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // Skip duplicates (case-insensitive) so the user can't add "Milk" twice.
        let key = trimmed.lowercased()
        guard !ingredients.contains(where: { $0.name.lowercased() == key }) else { return }
        ingredients.append(IngredientItem(id: UUID().uuidString, name: trimmed))
    }

    func removeIngredient(id: String) {
        ingredients.removeAll { $0.id == id }
    }

    func resetForm() {
        title = ""
        instructions = ""
        ingredients = []
    }

    func isFormValid() -> Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && !ingredients.isEmpty
    }

    /// Build the current form into a Recipe. Returns nil if invalid.
    func buildRecipe() -> Recipe? {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedInstructions = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty, !ingredients.isEmpty else { return nil }

        return Recipe(
            id: UUID().uuidString,
            title: cleanedTitle,
            ingredients: ingredients,
            instructions: cleanedInstructions
        )
    }
}
