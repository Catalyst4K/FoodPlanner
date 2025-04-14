import Foundation

class ShoppingListUtils {

    // Generates the shopping list from recipes and pantry
    static func generateShoppingList(from recipes: [Recipe], pantry: [PantryItem]) -> [ShoppingListItem] {
        var shoppingList: [ShoppingListItem] = []

        // Iterate through recipes and add ingredients
        for recipe in recipes {
            for ingredient in recipe.ingredients {
                // Only add items that aren't already in the pantry
                if !pantry.contains(where: { $0.ingredient.text.lowercased() == ingredient.text.lowercased() }) {
                    shoppingList.append(ShoppingListItem(
                        id: UUID(),
                        ingredient: ingredient, // Ingredient from the recipe
                        isChecked: false
                    ))
                }
            }
        }
        return shoppingList
    }
}
