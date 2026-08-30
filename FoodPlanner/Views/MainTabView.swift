import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var dataManager: DataManager
    @ObservedObject var authViewModel: AuthViewModel

    @State private var showAccount = false
    @State private var showSortMenu = false
    @State private var selectedRecipeSort: String = "Sort by Pantry Match"
    @State private var selectedShoppingSort: String = ShoppingListView.sortNewest
    @State private var selectedTab = 0

    private let recipeSortOptions = ["Sort by Pantry Match", "Sort by Recipe Name"]

    private var isSortableTab: Bool {
        selectedTab == 0 || selectedTab == 2
    }

    private var currentSortSelection: String {
        selectedTab == 0 ? selectedRecipeSort : selectedShoppingSort
    }

    private var currentSortOptions: [String] {
        selectedTab == 0 ? recipeSortOptions : ShoppingListView.sortOptions
    }

    var body: some View {
        ZStack {
            NavigationStack {
                TabView(selection: $selectedTab) {
                    RecipeListScreen(selectedSortOption: $selectedRecipeSort)
                        .tag(0)
                        .tabItem { Label("Recipes", systemImage: "list.bullet") }

                    NavigationView { PantryView() }
                        .tag(1)
                        .tabItem { Label("Pantry", systemImage: "refrigerator") }

                    NavigationView { ShoppingListView(sortOption: $selectedShoppingSort) }
                        .tag(2)
                        .tabItem { Label("Shopping", systemImage: "cart") }
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showAccount = true
                        } label: {
                            Image(systemName: "gearshape").imageScale(.large)
                        }
                    }

                    ToolbarItem(placement: .navigationBarLeading) {
                        if isSortableTab {
                            Button {
                                withAnimation { showSortMenu.toggle() }
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

            if showSortMenu {
                sortMenuOverlay
            }

            errorBanner
        }
    }

    private var sortMenuOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation { showSortMenu = false }
                }

            VStack(spacing: 0) {
                ForEach(currentSortOptions, id: \.self) { option in
                    Button {
                        applySort(option)
                        withAnimation { showSortMenu = false }
                    } label: {
                        HStack {
                            Text(option)
                            Spacer()
                            if currentSortSelection == option {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .foregroundColor(.primary)
                }
            }
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
            .padding(.horizontal, 40)
        }
    }

    private func applySort(_ option: String) {
        if selectedTab == 0 {
            selectedRecipeSort = option
        } else if selectedTab == 2 {
            selectedShoppingSort = option
        }
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let message = dataManager.errorMessage {
            VStack {
                Spacer()
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.white)
                    Text(message)
                        .foregroundColor(.white)
                        .font(.footnote)
                    Spacer()
                    Button {
                        dataManager.clearError()
                    } label: {
                        Image(systemName: "xmark").foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .glassEffect(.regular.tint(.red), in: .rect(cornerRadius: 12))
                .padding(.horizontal)
                .padding(.bottom, 60)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.easeInOut, value: dataManager.errorMessage)
        }
    }
}
