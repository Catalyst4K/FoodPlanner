import SwiftUI

struct RecipeDetailView: View {
    var recipe: Recipe
    @ObservedObject var viewModel: RecipeListViewModel
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var pantryViewModel: PantryViewModel
    @ObservedObject var shoppingListViewModel: ShoppingListViewModel
    @State private var didPressAddAll = false
    
    // Computed property to get pantry & shopping list status
    var ingredientsWithStatus: [(ingredient: IngredientItem, isInPantry: Bool, isInShoppingList: Bool)] {
        viewModel.getIngredientsWithStatus(
            for: recipe,
            pantryViewModel: pantryViewModel,
            shoppingListViewModel: shoppingListViewModel
        )
    }
    
    // Computed property to check if "Add All" button should be shown
    var shouldShowAddAllButton: Bool {
        viewModel.shouldShowAddAllButton(for: recipe, pantryViewModel: pantryViewModel)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(recipe.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 20)
                
                HStack {
                    Text("Ingredients")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.top, 10)
                    
                    Spacer()
                    
                    // Only show "Add All" button if there's at least one ingredient not in the pantry
                    if shouldShowAddAllButton {
                        Button(action: {
                            // 1. Run your logic
                            viewModel.addUncheckedIngredientsToShoppingList(
                                from: recipe,
                                shoppingListViewModel: shoppingListViewModel,
                                pantryViewModel: pantryViewModel
                            )

                            // 2. Trigger visual feedback
                            withAnimation(.easeInOut(duration: 0.2)) {
                                didPressAddAll = true
                            }

                            // 3. Reset it after a short delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    didPressAddAll = false
                                }
                            }

                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "cart.fill")
                                Text("Add All")
                                    .font(.body)
                            }
                            .foregroundColor(.blue)
                            .padding(5)
                            .opacity(didPressAddAll ? 0.4 : 1.0) // 👈 fading effect
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(ingredientsWithStatus, id: \.ingredient.id) { ingredientStatus in
                        HStack {
                            // Pantry icon on the left
                            Button(action: {
                                viewModel.togglePantryStatus(
                                        ingredient: ingredientStatus.ingredient,
                                        isInPantry: ingredientStatus.isInPantry,
                                        pantryViewModel: pantryViewModel
                                    )
                            }) {
                                Image(systemName: ingredientStatus.isInPantry ? "refrigerator.fill" : "refrigerator")
                                    .foregroundColor(ingredientStatus.isInPantry ? .green : .gray)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Text(ingredientStatus.ingredient.text)
                                .font(.body)
                                .padding(.bottom, 2)
                            
                            Spacer()
                            
                            // Only show cart if not in pantry
                            if !ingredientStatus.isInPantry {
                                Button(action: {
                                    viewModel.toggleShoppingListStatus(
                                            ingredient: ingredientStatus.ingredient,
                                            isInShoppingList: ingredientStatus.isInShoppingList,
                                            shoppingListViewModel: shoppingListViewModel
                                        )
                                }) {
                                    Image(systemName: ingredientStatus.isInShoppingList ? "cart.fill" : "cart")
                                        .foregroundColor(ingredientStatus.isInShoppingList ? .blue : .gray)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
                
                Divider()
                    .padding(.vertical, 10)
                
                Text("Instructions")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top, 10)
                
                Text(recipe.instructions)
                    .font(.body)
                    .padding(.top, 10)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                
                Button(action: {
                    viewModel.deleteRecipe(id: recipe.id)
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Delete Recipe")
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .cornerRadius(8)
                }
                .padding(.top, 20)
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
        }
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

