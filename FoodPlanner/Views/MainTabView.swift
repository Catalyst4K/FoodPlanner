import SwiftUI

struct MainTabView: View {
    @StateObject private var recipeListViewModel = RecipeListViewModel()
    @StateObject private var shoppingListViewModel = ShoppingListViewModel()
    @StateObject private var pantryViewModel = PantryViewModel()  // Initialize here
    @ObservedObject var authViewModel: AuthViewModel
    @State private var showAccount = false

    var body: some View {
        NavigationStack {
            TabView {
                // Recipes Tab
                RecipeListScreen(recipeListViewModel: recipeListViewModel, pantryViewModel: pantryViewModel, shoppingListViewModel: shoppingListViewModel )
                    .tabItem {
                        Label("Recipes", systemImage: "list.bullet")
                    }

                // Pantry Tab
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAccount = true
                    } label: {
                        Image(systemName: "person.circle")
                            .imageScale(.large)
                    }
                }
            }
            .navigationDestination(isPresented: $showAccount) {
                AccountView(authViewModel: authViewModel)
            }
        }
    }
}
