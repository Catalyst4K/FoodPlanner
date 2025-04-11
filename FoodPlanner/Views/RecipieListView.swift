import SwiftUI

struct RecipeListScreen: View {
    @ObservedObject var recipeListViewModel: RecipeListViewModel

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    Text("Recipes")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 16)
                        .padding(.bottom, 8)

                    // If no recipes, show a friendly empty state message
                    if recipeListViewModel.recipes.isEmpty {
                        Text("Looks like you don't have any recipes yet.\nTry adding one!")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    }

                    // List of recipes
                    LazyVStack(spacing: 0) {
                        ForEach(recipeListViewModel.recipes) { recipe in
                            NavigationLink(destination: RecipeDetailView(recipe: recipe, viewModel: recipeListViewModel)) {
                                HStack {
                                    Text(recipe.title)
                                        .foregroundColor(.primary)
                                        .padding(.vertical, 12)

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding(.horizontal)
                                .background(Color(UIColor.systemBackground))
                            }
                            Divider()
                        }
                    }

                    // Add Recipe button
                    HStack {
                        Spacer()
                        NavigationLink(destination: AddRecipeView(viewModel: recipeListViewModel)) {
                            Text("Add Recipe")
                                .font(.headline)
                                .padding()
                                .frame(minWidth: 150)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 24)
                }
                .padding(.horizontal)
            }
            .navigationBarHidden(true)
        }
    }
}
