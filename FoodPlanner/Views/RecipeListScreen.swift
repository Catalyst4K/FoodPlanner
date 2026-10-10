import SwiftUI

struct RecipeListScreen: View {
    @EnvironmentObject private var dataManager: DataManager
    @AppStorage("recipeSort") private var sort: RecipeSort = .pantryMatch
    @State private var scope: Scope = .mine
    @State private var searchText = ""

    private enum Scope: String, CaseIterable, Identifiable {
        case mine = "My Recipes"
        case canCook = "Can Cook"
        case shared = "Shared"
        var id: String { rawValue }
    }

    private var showingShared: Bool { scope == .shared }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerView
                scopePicker
                emptyStateView
                if scope == .canCook { canCookView } else { recipeListView }
                if scope == .mine { addRecipeButton }
            }
            .padding(.horizontal)
        }
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search recipes or ingredients")
        .toolbar {
            if scope == .mine {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Picker("Sort", selection: $sort) {
                            ForEach(RecipeSort.allCases) { Text($0.title).tag($0) }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    .accessibilityLabel("Sort")
                    .accessibilityIdentifier("recipes.sort")
                }
            }
        }
        .navigationDestination(for: RecipeRoute.self) { route in
            switch route {
            case .detail(let id):
                if let recipe = recipe(withID: id) {
                    RecipeDetailView(recipe: recipe)
                }
            case .add:
                AddRecipeView(viewModel: RecipeFormViewModel())
            }
        }
    }

    /// Where the Recipes stack can go. Detail pages are identified by recipe ID.
    enum RecipeRoute: Hashable {
        case detail(String)
        case add
    }

    private func recipe(withID id: String) -> Recipe? {
        dataManager.userRecipes.first { $0.id == id } ?? dataManager.sharedRecipes.first { $0.id == id }
    }

    private var headerView: some View {
        Text("Recipes")
            .font(.largeTitle)
            .fontWeight(.bold)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 16)
            .padding(.bottom, 8)
    }

    private var scopePicker: some View {
        Picker("", selection: $scope) {
            ForEach(Scope.allCases) { Text($0.rawValue).tag($0) }
        }
        .accessibilityIdentifier("recipes.scope")
        .pickerStyle(.segmented)
        .padding(.bottom, 12)
    }

    private var emptyStateMessage: String {
        if !searchText.isEmpty { return "No recipes match “\(searchText)”." }
        switch scope {
        case .shared: return "No shared recipes yet.\nWhen someone shares a recipe, it'll appear here."
        case .canCook:
            return "Nothing is within two ingredients of your pantry yet.\nAdd what you have on the Pantry tab."
        case .mine: return "Looks like you don't have any recipes yet.\nTry adding one!"
        }
    }

    private var emptyStateView: some View {
        Group {
            if scope == .canCook ? canCookGroups.isEmpty : visibleRecipes.isEmpty {
                Text(emptyStateMessage)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            }
        }
    }

    private var canCookGroups: [CookableRecipes.Group] {
        CookableRecipes.groups(
            RecipeSearch.filter(dataManager.userRecipes, query: searchText), pantry: dataManager.pantryIngredients)
    }

    private var canCookView: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(canCookGroups, id: \.missing) { group in
                Text(group.title)
                    .font(.headline)
                    .foregroundStyle(group.missing == 0 ? Color.green : .secondary)
                    .padding(.top, 16)
                    .padding(.bottom, 4)
                    .accessibilityIdentifier("recipes.canCook.\(group.missing)")
                ForEach(group.recipes) { recipe in
                    NavigationLink(value: RecipeRoute.detail(recipe.id)) {
                        row(for: recipe)
                    }
                    Divider()
                }
            }
        }
    }

    private var recipeListView: some View {
        LazyVStack(spacing: 0) {
            ForEach(visibleRecipes) { recipe in
                NavigationLink(value: RecipeRoute.detail(recipe.id)) {
                    row(for: recipe)
                }
                Divider()
            }
        }
    }

    private func row(for recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(recipe.title)
                    .foregroundColor(.primary)
                    .padding(.vertical, 12)

                if !showingShared && recipe.isShared {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }

            if showingShared, let name = recipe.ownerName {
                Text("Shared by \(name)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            let match = dataManager.matchedIngredientCount(for: recipe)
            let total = recipe.ingredients.count
            HStack(spacing: 4) {
                Image(systemName: "refrigerator")
                    .foregroundColor(match == total ? .green : .blue)
                Text("\(match)/\(total)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 4)
        }
        .padding(.horizontal)
        .background(Color(UIColor.systemBackground))
    }

    private var addRecipeButton: some View {
        HStack {
            Spacer()
            NavigationLink(value: RecipeRoute.add) {
                Text("Add Recipe")
                    .font(.headline)
                    .padding()
                    .frame(minWidth: 150)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .accessibilityIdentifier("recipes.add")
            Spacer()
        }
        .padding(.vertical, 24)
    }

    private var visibleRecipes: [Recipe] {
        let matching = RecipeSearch.filter(
            showingShared ? dataManager.sharedRecipes : dataManager.userRecipes, query: searchText)
        if showingShared {
            return RecipeSort.sorted(matching, by: .name, pantry: dataManager.pantryIngredients)
        }
        return RecipeSort.sorted(matching, by: sort, pantry: dataManager.pantryIngredients)
    }
}
