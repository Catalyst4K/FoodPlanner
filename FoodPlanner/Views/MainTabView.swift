import SwiftUI

struct MainTabView: View {
    @StateObject private var recipeListViewModel = RecipeListViewModel()
    @StateObject private var shoppingListViewModel = ShoppingListViewModel()
    @StateObject private var pantryViewModel = PantryViewModel()
    @ObservedObject var authViewModel: AuthViewModel

    @State private var showAccount = false
    @State private var showSortMenu = false
    @State private var selectedSortOption: String = "Sort by Pantry Match"
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            NavigationStack {
                TabView(selection: $selectedTab) {
                    // Recipes Tab
                    RecipeListScreen(
                        recipeListViewModel: recipeListViewModel,
                        pantryViewModel: pantryViewModel,
                        shoppingListViewModel: shoppingListViewModel,
                        selectedSortOption: $selectedSortOption
                    )
                    .tag(0)
                    .tabItem {
                        Label("Recipes", systemImage: "list.bullet")
                    }

                    // Pantry Tab
                    NavigationView {
                        PantryView(pantryViewModel: pantryViewModel)
                    }
                    .tag(1)
                    .tabItem {
                        Label("Pantry", systemImage: "refrigerator")
                    }

                    // Shopping List Tab
                    NavigationView {
                        ShoppingListView(
                            shoppingListViewModel: shoppingListViewModel,
                            pantryViewModel: pantryViewModel
                        )
                    }
                    .tag(2)
                    .tabItem {
                        Label("Shopping", systemImage: "cart")
                    }
                }
                .toolbar {
                    // Settings cog (always visible)
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showAccount = true
                        } label: {
                            Image(systemName: "gearshape")
                                .imageScale(.large)
                        }
                    }

                    // Sort button (only visible on Recipes tab for now)
                    ToolbarItem(placement: .navigationBarLeading) {
                        if selectedTab == 0 {
                            Button {
                                withAnimation {
                                    showSortMenu.toggle()
                                }
                            } label: {
                                Image(systemName: "arrow.up.arrow.down.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                .navigationDestination(isPresented: $showAccount) {
                    AccountView(authViewModel: authViewModel)
                }
            }

            // Overlay sort menu
            if showSortMenu {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            showSortMenu = false
                        }
                    }

                VStack(spacing: 0) {
                    if selectedTab == 0 {
                        // Sort options for Recipe tab
                        ForEach(["Sort by Pantry Match", "Sort by Recipe Name"], id: \.self) { option in
                            Button(action: {
                                selectedSortOption = option
                                withAnimation {
                                    showSortMenu = false
                                }
                            }) {
                                Text(option)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(selectedSortOption == option ? Color.blue.opacity(0.2) : Color.white)
                            }
                            .foregroundColor(.primary)
                        }
                    }
                    // Extend with else-if for Pantry or Shopping tab sort options if needed
                }
                .background(Color.white)
                .cornerRadius(12)
                .shadow(radius: 10)
                .padding(.horizontal, 40)
            }
        }
    }
}

#Preview {
    MainTabView(authViewModel: AuthViewModel())
}
