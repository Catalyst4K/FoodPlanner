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
    
    func addUncheckedIngredientsToShoppingList(from recipe: Recipe, shoppingListViewModel: ShoppingListViewModel, pantryViewModel: PantryViewModel) {
        let uncheckedIngredients = recipe.ingredients.filter { ingredient in
            // Ensure the ingredient is not checked and not in the pantry
            !pantryViewModel.pantryItems.contains(where: { $0.ingredient.text.lowercased() == ingredient.text.lowercased() })
        }
        
        // Add each unchecked ingredient to the shopping list, checking if it's not already there
        for ingredient in uncheckedIngredients {
            // Check if the ingredient is already in the shopping list
            let ingredientExists = shoppingListViewModel.shoppingList.contains { $0.ingredient.text.lowercased() == ingredient.text.lowercased() }
            
            // Add the ingredient only if it's not already in the shopping list
            if !ingredientExists {
                shoppingListViewModel.addItem(ingredient: ingredient)
            }
        }
    }
    
    func getIngredientsWithStatus(for recipe: Recipe, pantryViewModel: PantryViewModel, shoppingListViewModel: ShoppingListViewModel) -> [(ingredient: IngredientItem, isInPantry: Bool, isInShoppingList: Bool)] {
            return recipe.ingredients.map { ingredient in
                let ingredientText = ingredient.text.lowercased()

                // Check if the ingredient is in the pantry
                let isInPantry = pantryViewModel.pantryItems.contains { $0.ingredient.text.lowercased() == ingredientText }

                // Check if the ingredient is in the shopping list
                let isInShoppingList = shoppingListViewModel.shoppingList.contains { $0.ingredient.text.lowercased() == ingredientText }

                return (ingredient, isInPantry, isInShoppingList)
            }
        }
    
    // Computed property to check if any ingredient is missing from the pantry
    func shouldShowAddAllButton(for recipe: Recipe, pantryViewModel: PantryViewModel) -> Bool {
        // Check if any ingredient in the recipe is not in the pantry
        return recipe.ingredients.contains { ingredient in
            !pantryViewModel.pantryItems.contains { $0.ingredient.text.lowercased() == ingredient.text.lowercased() }
        }
    }
    
    func togglePantryStatus(
        ingredient: IngredientItem,
        isInPantry: Bool,
        pantryViewModel: PantryViewModel
    ) {
        if isInPantry {
            if let matching = pantryViewModel.pantryItems.first(where: {
                $0.ingredient.text.lowercased() == ingredient.text.lowercased()
            }) {
                pantryViewModel.removeItem(id: matching.id)
            }
        } else {
            pantryViewModel.addItem(name: ingredient.text)
        }
    }
    
    func toggleShoppingListStatus(
        ingredient: IngredientItem,
        isInShoppingList: Bool,
        shoppingListViewModel: ShoppingListViewModel
    ) {
        if isInShoppingList {
            if let matching = shoppingListViewModel.shoppingList.first(where: {
                $0.ingredient.text.lowercased() == ingredient.text.lowercased()
            }) {
                shoppingListViewModel.removeItem(id: matching.id)
            }
        } else {
            shoppingListViewModel.addItem(ingredient: ingredient)
        }
    }
    
    func sortedRecipesByPantryMatch(pantryViewModel: PantryViewModel) -> [Recipe] {
        return recipes.sorted { r1, r2 in
            let match1 = matchedIngredientCount(for: r1, pantryViewModel: pantryViewModel)
            let match2 = matchedIngredientCount(for: r2, pantryViewModel: pantryViewModel)
            return match1 > match2 // highest match count comes first
        }
    }

    func matchedIngredientCount(for recipe: Recipe, pantryViewModel: PantryViewModel) -> Int {
        let pantryTexts = pantryViewModel.pantryItems.map { $0.ingredient.text.lowercased() }
        return recipe.ingredients.filter { pantryTexts.contains($0.text.lowercased()) }.count
    }

}
