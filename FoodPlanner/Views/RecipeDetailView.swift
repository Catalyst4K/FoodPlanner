import SwiftUI

struct RecipeDetailView: View {
    var recipe: Recipe
    @ObservedObject var viewModel: RecipeListViewModel
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(recipe.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 20)

                Text("Ingredients")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top, 10)

                VStack(alignment: .leading, spacing: 5) {
                    ForEach(recipe.ingredients) { ingredient in
                        Text("• \(ingredient.text)")
                            .font(.body)
                            .padding(.bottom, 2)
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

                // Delete Button to remove the recipe
                Button(action: {
                    viewModel.deleteRecipe(id: recipe.id)
                    presentationMode.wrappedValue.dismiss() // Go back after deletion
                }) {
                    Text("Delete Recipe")
                        .foregroundColor(.red)
                        .fontWeight(.bold)
                        .padding()
                        .frame(maxWidth: .infinity) // Ensure the button stretches across the width
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.top, 20)
                }
                .frame(maxWidth: .infinity) // Ensure the button takes up full width
                .padding(.horizontal, 20) // Add horizontal padding for spacing
            }
            .padding()
        }
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(leading: Button("Back") {
            presentationMode.wrappedValue.dismiss()
        })
    }
}
