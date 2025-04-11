import SwiftUI

struct RecipeDetailView: View {
    var recipe: Recipe

    @State private var selectedIngredients: Set<UUID> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Recipe Title
                Text(recipe.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 20)

                // Ingredients Section
                Text("Ingredients")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top, 10)

                VStack(alignment: .leading, spacing: 5) {
                    ForEach(recipe.ingredients) { ingredient in
                        HStack {
                            Button(action: {
                                toggleSelection(for: ingredient.id)
                            }) {
                                Image(systemName: selectedIngredients.contains(ingredient.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedIngredients.contains(ingredient.id) ? .green : .gray)
                            }
                            .buttonStyle(PlainButtonStyle())

                            Text(ingredient.text)
                                .strikethrough(selectedIngredients.contains(ingredient.id), color: .gray)
                                .foregroundColor(selectedIngredients.contains(ingredient.id) ? .gray : .primary)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Divider()
                    .padding(.vertical, 10)

                // Instructions Section
                Text("Instructions")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(recipe.instructions)
                    .font(.body)
                    .padding(.top, 10)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
            }
            .padding()
        }
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggleSelection(for id: UUID) {
        if selectedIngredients.contains(id) {
            selectedIngredients.remove(id)
        } else {
            selectedIngredients.insert(id)
        }
    }
}
