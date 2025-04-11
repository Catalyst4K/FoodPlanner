import SwiftUI

class RecipeListViewModel: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var title: String = ""
    @Published var ingredients: [IngredientItem] = [IngredientItem(text: "")]
    @Published var instructions: String = ""

    // Handles changes in the ingredient text field
    func handleIngredientChange(id: UUID, newValue: String) {
        guard let index = ingredients.firstIndex(where: { $0.id == id }) else { return }

        ingredients[index].text = newValue

        // Add a new empty ingredient field only if the last one is filled
        if index == ingredients.count - 1 && !newValue.isEmpty {
            ingredients.append(IngredientItem(text: ""))
        }
        
        if ingredients[index].text.isEmpty && index < ingredients.count - 1 {
            removeIngredient(id: id)
        }

        // Ensure there is only one empty field at the end
        cleanEmptyIngredients()
    }

    // Removes an ingredient from the list by ID
    func removeIngredient(id: UUID) {
        guard let index = ingredients.firstIndex(where: { $0.id == id }) else { return }

        // Remove ingredient if it's not the last one
        if ingredients.count > 1 {
            ingredients.remove(at: index)
        }

        // If there are no ingredients left, add one empty field at the end
        if ingredients.isEmpty {
            ingredients.append(IngredientItem(text: ""))
        }

        // Ensure only one empty field remains at the end
        cleanEmptyIngredients()
    }

    // Resets the form
    func resetForm() {
        title = ""
        instructions = ""
        ingredients = [IngredientItem(text: "")]
    }

    // Validates the form
    func isFormValid() -> Bool {
        !title.isEmpty && ingredients.contains(where: { !$0.text.isEmpty })
    }

    // Adds the recipe to the list
    func addRecipe(_ recipe: Recipe) {
        recipes.append(recipe)
    }

    // Removes a recipe from the list by ID
    func deleteRecipe(id: UUID) {
        if let index = recipes.firstIndex(where: { $0.id == id }) {
            recipes.remove(at: index)
        }
    }

    // Removes extra empty fields, ensuring only one remains at the end
    private func cleanEmptyIngredients() {
        while ingredients.count > 1,
              ingredients.last?.text.isEmpty == true,
              ingredients[ingredients.count - 2].text.isEmpty == true {
            ingredients.removeLast()
        }
    }

    func submitRecipe() {
        let cleanedIngredients = ingredients
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { IngredientItem(text: $0) } // ✅ wrap them back as IngredientItem

        let cleanedInstructions = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        let newRecipe = Recipe(
            title: cleanedTitle,
            ingredients: cleanedIngredients,
            instructions: cleanedInstructions
        )

        addRecipe(newRecipe)
        resetForm()
    }
}
