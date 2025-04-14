import SwiftUI

struct MainTabView: View {
    @StateObject private var recipeListViewModel = RecipeListViewModel()
    @StateObject private var shoppingListViewModel = ShoppingListViewModel()
    @StateObject private var pantryViewModel = PantryViewModel()  // Initialize here

    var body: some View {
        TabView {
            // Recipes Tab
            RecipeListScreen(recipeListViewModel: recipeListViewModel, pantryViewModel: pantryViewModel, shoppingListViewModel: shoppingListViewModel )
                .tabItem {
                    Label("Recipes", systemImage: "list.bullet")
                }

            // Pantry Tab, passing pantryManager correctly
            NavigationView {
                PantryView(pantryViewModel: pantryViewModel)
            }
            .tabItem {
                Label("Pantry", systemImage: "cart.fill")
            }

            // Shopping List Tab
            NavigationView {
                ShoppingListView(shoppingListViewModel: shoppingListViewModel, pantryViewModel: pantryViewModel)
            }
            .tabItem {
                Label("Shopping", systemImage: "cart")
            }
        }
    }
}
