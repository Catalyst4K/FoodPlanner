import SwiftUI

struct RecipeListScreen: View {
    @EnvironmentObject private var dataManager: DataManager
    @Binding var selectedSortOption: String
    @State private var showingShared: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerView
                scopePicker
                emptyStateView
                recipeListView
                if !showingShared { addRecipeButton }
            }
            .padding(.horizontal)
        }
        .navigationBarTitleDisplayMode(.inline)
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
        Picker("", selection: $showingShared) {
            Text("My Recipes").tag(false)
            Text("Shared").tag(true)
        }
        .pickerStyle(.segmented)
        .padding(.bottom, 12)
    }

    private var emptyStateView: some View {
        Group {
            if visibleRecipes.isEmpty {
                Text(
                    showingShared
                        ? "No shared recipes yet.\nWhen someone shares a recipe, it'll appear here."
                        : "Looks like you don't have any recipes yet.\nTry adding one!"
                )
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
        if showingShared {
            return dataManager.sharedRecipes.sorted { $0.title < $1.title }
        }
        switch selectedSortOption {
        case "Sort by Pantry Match":
            return dataManager.recipesSortedByPantryMatch()
        case "Sort by Recipe Name":
            return dataManager.userRecipes.sorted { $0.title < $1.title }
        default:
            return dataManager.userRecipes
        }
    }
}
