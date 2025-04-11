import SwiftUI

struct MainTabView: View {
    @StateObject private var recipeListViewModel = RecipeListViewModel()
    @StateObject private var shoppingListViewModel = ShoppingListViewModel()
    @StateObject private var pantryManager = PantryManager()

    var body: some View {
        TabView {
            // Recipes Tab
            NavigationView {
                VStack(spacing: 0) {
                    // Big centered title
                    Text("Recipes")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 16)
                        .padding(.bottom, 8)

                    // Recipe list with add button at the end
                    List {
                        ForEach(recipeListViewModel.recipes) { recipe in
                            NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                                Text(recipe.title)
                            }
                        }

                        // Add Recipe button as a proper, centered button at the bottom of the list
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
                        .padding(.vertical)
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .tabItem {
                Label("Recipes", systemImage: "list.bullet")
            }

            // Pantry Tab
            NavigationView {
                PantryView(pantryManager: pantryManager, shoppingListViewModel: shoppingListViewModel)
            }
            .tabItem {
                Label("Pantry", systemImage: "cart.fill")
            }

            // Shopping List Tab
            NavigationView {
                ShoppingListView(viewModel: shoppingListViewModel)
            }
            .tabItem {
                Label("Shopping", systemImage: "cart")
            }
        }
    }
}
