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

        // Remove empty fields when text is empty
        if pantryItems[index].ingredient.text.isEmpty && index < pantryItems.count - 1 {
            removeItem(id: id)
        }

        // Ensure there is only one empty field at the end
        cleanEmptyItems()
    }

    // Removes an item from the pantry by ID
    func removeItem(id: UUID) {
        guard let index = pantryItems.firstIndex(where: { $0.id == id }) else { return }

        // Remove ingredient if it's not the last one
        if pantryItems.count > 1 {
            pantryItems.remove(at: index)
        }

        // If there are no ingredients left, add one empty field at the end
        if pantryItems.isEmpty {
            pantryItems.append(PantryItem(ingredient: IngredientItem(text: ""))) // Add empty field
        }

        // Ensure only one empty field remains at the end
        cleanEmptyItems()
    }

    // Removes extra empty items, ensuring only one empty field remains at the end
    func cleanEmptyItems() {
        // Remove extra empty fields in the pantry (except for the last one)
        while pantryItems.count > 1,
              pantryItems.last?.ingredient.text.isEmpty == true,
              pantryItems[pantryItems.count - 2].ingredient.text.isEmpty == true {
            pantryItems.removeLast()
        }
    }

    // Add an ingredient to the pantry
    func addItem(name: String) {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        // Insert before the empty field (if it exists)
        if pantryItems.last?.ingredient.text.isEmpty == true {
            pantryItems.insert(PantryItem(ingredient: IngredientItem(text: name)), at: pantryItems.count - 1)
        } else {
            pantryItems.append(PantryItem(ingredient: IngredientItem(text: name)))
        }

        // Ensure only one empty field remains at the end
        cleanEmptyItems()
    }

    // Method to move an item from the shopping list to the pantry
    func moveItemToPantry(item: ShoppingListItem) {
        addItem(name: item.ingredient.text)  // Add to pantry
    }
}
