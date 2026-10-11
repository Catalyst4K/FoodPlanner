import SwiftUI

/// Owns the transient form state for AddRecipeView. Reads/writes recipes via DataManager.
class RecipeFormViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var ingredients: [IngredientItem] = []
    @Published var instructions: String = ""
    /// Optional; nil means "not set".
    @Published var servings: Int?
    /// Text typed in the "add ingredient" row but not yet committed to `ingredients`.
    @Published var pendingIngredient: String = ""

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
        self.servings = recipe.servings
        self.pendingIngredient = ""
        self.ingredients = recipe.ingredients.map {
            IngredientItem(id: UUID().uuidString, name: $0.name, quantity: $0.quantity, unit: $0.unit)
        }
    }

    /// Parses free text such as "200g plain flour" or "3 eggs" and appends it (duplicates by name are skipped).
    func addIngredient(text: String) {
        let parsed = IngredientParser.parse(text)
        guard !parsed.name.isEmpty else { return }
        let key = IngredientKey.normalized(parsed.name)
        guard !ingredients.contains(where: { IngredientKey.normalized($0.name) == key }) else { return }
        ingredients.append(
            IngredientItem(id: UUID().uuidString, name: parsed.name, quantity: parsed.quantity, unit: parsed.unit))
    }

    /// Appends a committed ingredient to the local list.
    func addIngredient(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // Skip duplicates (case-insensitive) so the user can't add "Milk" twice.
        let key = IngredientKey.normalized(trimmed)
        guard !ingredients.contains(where: { IngredientKey.normalized($0.name) == key }) else { return }
        ingredients.append(IngredientItem(id: UUID().uuidString, name: trimmed))
    }

    /// Commits whatever is in the add row (parsed like `addIngredient(text:)`) and clears it.
    func commitPendingIngredient() {
        let trimmed = pendingIngredient.trimmingCharacters(in: .whitespaces)
        pendingIngredient = ""
        guard !trimmed.isEmpty else { return }
        addIngredient(text: trimmed)
    }

    /// Moves an ingredient back into the add row as text so it can be edited and re-parsed on commit.
    /// Anything already typed in the row is committed first.
    func editIngredientAsText(id: String) {
        commitPendingIngredient()
        guard let ingredient = ingredients.first(where: { $0.id == id }) else { return }
        removeIngredient(id: id)
        pendingIngredient = IngredientFormatter.format(ingredient)
    }

    func removeIngredient(id: String) {
        ingredients.removeAll { $0.id == id }
    }

    func resetForm() {
        title = ""
        instructions = ""
        servings = nil
        pendingIngredient = ""
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
            instructions: cleanedInstructions,
            servings: servings
        )
    }
}
