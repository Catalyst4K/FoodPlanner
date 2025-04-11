import SwiftUI

class PantryViewModel: ObservableObject {
    @Published var pantryItems: [PantryItem] = [PantryItem(ingredient: IngredientItem(text: ""))]

    // Handles changes in the ingredient text field
    func handleIngredientChange(id: UUID, newValue: String) {
        guard let index = pantryItems.firstIndex(where: { $0.id == id }) else { return }

        pantryItems[index].ingredient.text = newValue
        
        // Add a new empty ingredient field only if the last one is filled
        if index == pantryItems.count - 1 && !newValue.isEmpty {
            pantryItems.append(PantryItem(ingredient: IngredientItem(text: "")))
        }
        
        if pantryItems[index].ingredient.text.isEmpty && index < pantryItems.count - 1 {
            removeItem(id: id)
        }

        // Ensure only one empty field remains at the end
        cleanEmptyIngredients()
    }

    // Remove an item by its ID
    func removeItem(id: UUID) {
        guard let index = pantryItems.firstIndex(where: { $0.id == id }) else { return }

        // Remove ingredient if it's not the last one
        if pantryItems.count > 1 {
            pantryItems.remove(at: index)
        }

        // If there are no ingredients left, add one empty field at the end
        if pantryItems.isEmpty {
            pantryItems.append(PantryItem(ingredient: IngredientItem(text: "")))
        }

        // Ensure only one empty field remains at the end
        cleanEmptyIngredients()
    }

    // Toggles whether an ingredient is used or not
    func toggleItemUsed(id: UUID) {
        if let index = pantryItems.firstIndex(where: { $0.id == id }) {
            pantryItems[index].isUsed.toggle()  // Toggle used state
        }
    }

    // Ensures that only one empty field remains at the end
    private func cleanEmptyIngredients() {
        while pantryItems.count > 1,
              pantryItems.last?.ingredient.text.isEmpty == true,
              pantryItems[pantryItems.count - 2].ingredient.text.isEmpty == true {
            pantryItems.removeLast()
        }
    }
}
