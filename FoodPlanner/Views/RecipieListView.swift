import SwiftUI

struct RecipeListScreen: View {
    @ObservedObject var recipeListViewModel: RecipeListViewModel
    @ObservedObject var pantryViewModel: PantryViewModel
    @ObservedObject var shoppingListViewModel = ShoppingListViewModel()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    headerView
                    emptyStateView
                    recipeListView
                    addRecipeButton
                }
                .padding(.horizontal)
            }
            .navigationBarHidden(true)
        }
    }

    private var headerView: some View {
        Text("Recipes")
            .font(.largeTitle)
            .fontWeight(.bold)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 16)
            .padding(.bottom, 8)
    }

    private var emptyStateView: some View {
        Group {
            if recipeListViewModel.recipes.isEmpty {
                Text("Looks like you don't have any recipes yet.\nTry adding one!")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            }
        }
    }

    private var recipeListView: some View {
        LazyVStack(spacing: 0) {
            ForEach(recipeListViewModel.recipes) { recipe in
                NavigationLink(destination: RecipeDetailView(
                    recipe: recipe,
                    viewModel: recipeListViewModel,
                    pantryViewModel: pantryViewModel,
                    shoppingListViewModel: shoppingListViewModel) // Passing shoppingListViewModel
                ) {
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
    }

    private var addRecipeButton: some View {
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
}
