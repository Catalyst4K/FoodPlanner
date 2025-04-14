import SwiftUI

struct RecipeDetailView: View {
    var recipe: Recipe
    @ObservedObject var viewModel: RecipeListViewModel
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var pantryViewModel: PantryViewModel
    @ObservedObject var shoppingListViewModel: ShoppingListViewModel

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
                    Button(action: {
                        // Call the view model method to add unchecked ingredients to the shopping list
                        viewModel.addUncheckedIngredientsToShoppingList(from: recipe, shoppingListViewModel: shoppingListViewModel, pantryViewModel: pantryViewModel)
                    }) {
                        Image(systemName: "cart.fill")
                            .foregroundColor(.blue)
                            .padding(5)
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    ForEach(recipe.ingredients) { ingredient in
                        HStack {
                            let isInPantry = pantryViewModel.pantryItems.contains { $0.ingredient.text.lowercased() == ingredient.text.lowercased() }
                            Button(action: {
                                if let matching = pantryViewModel.pantryItems.first(where: { $0.ingredient.text.lowercased() == ingredient.text.lowercased() }) {
                                    pantryViewModel.removeItem(id: matching.id)
                                }
                            }) {
                                Image(systemName: isInPantry ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(isInPantry ? .green : .gray)
                            }
                            .buttonStyle(PlainButtonStyle())
                            Text(ingredient.text)
                                .font(.body)
                                .padding(.bottom, 2)
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
                    .lineLimit(nil) // Allows multi-line wrapping if needed
                    .fixedSize(horizontal: false, vertical: true) // Allows the text to expand vertically

                // Simplified Delete Button to remove the recipe
                Button(action: {
                    viewModel.deleteRecipe(id: recipe.id)
                    presentationMode.wrappedValue.dismiss() // Go back after deletion
                }) {
                    Text("Delete Recipe")
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                        .padding()
                        .frame(maxWidth: .infinity) // Ensure the button stretches across the width
                        .background(Color.red) // Set background to red
                        .cornerRadius(8)
                }
                .padding(.top, 20) // Add padding to the top of the button
                .buttonStyle(PlainButtonStyle()) // Remove default button style
            }
            .padding()
        }
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
