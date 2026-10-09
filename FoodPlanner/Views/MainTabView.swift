import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var dataManager: DataManager
    @ObservedObject var authViewModel: AuthViewModel

    @State private var showAccount = false
    @State private var showSortMenu = false
    @State private var selectedRecipeSort: String = "Sort by Pantry Match"
    @State private var selectedShoppingSort: String = ShoppingListView.sortNewest
    @State private var selectedTab: AppTab = .recipes

    private let recipeSortOptions = ["Sort by Pantry Match", "Sort by Recipe Name"]

    private var currentSortSelection: String {
        selectedTab == .recipes ? selectedRecipeSort : selectedShoppingSort
    }

    private var currentSortOptions: [String] {
        selectedTab == .recipes ? recipeSortOptions : ShoppingListView.sortOptions
    }

    private enum AppTab: Hashable { case recipes, pantry, shopping }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                Tab("Recipes", systemImage: "list.bullet", value: AppTab.recipes) {
                    NavigationStack {
                        RecipeListScreen(selectedSortOption: $selectedRecipeSort)
                            .toolbar { appToolbar(sortable: true) }
                    }
                }

                Tab("Pantry", systemImage: "refrigerator", value: AppTab.pantry) {
                    NavigationStack {
                        PantryView()
                            .toolbar { appToolbar(sortable: false) }
                    }
                }

                Tab("Shopping", systemImage: "cart", value: AppTab.shopping) {
                    NavigationStack {
                        ShoppingListView(sortOption: $selectedShoppingSort)
                            .toolbar { appToolbar(sortable: true) }
                    }
                }
            }
            .sheet(isPresented: $showAccount) {
                NavigationStack {
                    AccountView(authViewModel: authViewModel)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showAccount = false }
                                    .accessibilityIdentifier("account.done")
                            }
                        }
                }
            }

            if showSortMenu {
                sortMenuOverlay
            }

            errorBanner
        }
    }

    /// The gear (opens Account in a sheet) and, on the tabs that sort, the sort button. Each tab's own
    /// navigation stack shows these, so there is exactly one navigation bar per screen.
    @ToolbarContentBuilder
    private func appToolbar(sortable: Bool) -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                showAccount = true
            } label: {
                Image(systemName: "gearshape").imageScale(.large)
            }
            .accessibilityLabel("Account")
            .accessibilityIdentifier("tabs.account")
        }

        if sortable {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    withAnimation { showSortMenu.toggle() }
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle.fill")
                        .foregroundColor(.blue)
                }
                .accessibilityLabel("Sort")
            }
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
        switch selectedTab {
        case .recipes: selectedRecipeSort = option
        case .shopping: selectedShoppingSort = option
        case .pantry: break
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
