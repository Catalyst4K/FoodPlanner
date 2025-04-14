import SwiftUI

class ShoppingListViewModel: ObservableObject {
    @Published var shoppingList: [ShoppingListItem] = [ShoppingListItem(id: UUID(), ingredient: IngredientItem(text: ""), isChecked: false)]

    // Handles changes in the ingredient text field
    func handleIngredientChange(id: UUID, newValue: String) {
        guard let index = shoppingList.firstIndex(where: { $0.id == id }) else { return }

        shoppingList[index].ingredient.text = newValue

        // Add a new empty ingredient field only if the last one is filled
        if index == shoppingList.count - 1 && !newValue.isEmpty {
            shoppingList.append(ShoppingListItem(id: UUID(), ingredient: IngredientItem(text: ""), isChecked: false))
        }

        // Remove empty fields when text is empty
        if shoppingList[index].ingredient.text.isEmpty && index < shoppingList.count - 1 {
            removeItem(id: id)
        }

        // Ensure there is only one empty field at the end
        cleanEmptyItems()
    }

    // Remove an item from the shopping list
    func removeItem(id: UUID) {
        shoppingList.removeAll { $0.id == id }
    }

    // Toggle item checked (mark as purchased) and move to pantry if checked
    func toggleItemChecked(id: UUID, pantryViewModel: PantryViewModel) {
        if let index = shoppingList.firstIndex(where: { $0.id == id }) {
            shoppingList[index].isChecked.toggle() // Toggle the checked state

            // If checked, move item to pantry with delay and fade effect
            if shoppingList[index].isChecked {
                // Fade out the item before removing it
                withAnimation(.easeOut(duration: 1.0)) {
                    // Removing the item with animation
                    let item = shoppingList[index] // Capture the item before removal
                    shoppingList.remove(at: index)
                    
                    // Delay moving the item to the pantry
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { // Wait for fade to complete
                        self.moveItemToPantry(item: item, pantryViewModel: pantryViewModel)
                    }
                }
            }
        }
    }

    // Move an item from the shopping list to the pantry
    private func moveItemToPantry(item: ShoppingListItem, pantryViewModel: PantryViewModel) {
        pantryViewModel.addItem(name: item.ingredient.text) // Add to pantry
    }

    // Removes extra empty items, ensuring only one empty field remains at the end
    private func cleanEmptyItems() {
        // Keep only one empty item at the end
        while shoppingList.count > 1,
              shoppingList.last?.ingredient.text.isEmpty == true,
              shoppingList[shoppingList.count - 2].ingredient.text.isEmpty == true {
            shoppingList.remove(at: shoppingList.count - 2)
        }
    }

    // Add a new item to the shopping list
    func addItem(ingredient: IngredientItem) {
        // Clean up any empty items before appending
        shoppingList.removeAll { $0.ingredient.text.trimmingCharacters(in: .whitespaces).isEmpty }

        // Add the new item
        let newItem = ShoppingListItem(id: UUID(), ingredient: ingredient, isChecked: false)
        shoppingList.append(newItem)

        // Ensure one empty field at the end
        shoppingList.append(ShoppingListItem(id: UUID(), ingredient: IngredientItem(text: ""), isChecked: false))
    }

    
}
