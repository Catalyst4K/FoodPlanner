import SwiftUI

/// The ingredient list on the recipe detail screen: pantry and shopping-list toggles per row, "Add All", and the
/// servings stepper that rescales the amounts.
struct RecipeIngredientsSection: View {
    @EnvironmentObject private var dataManager: DataManager
    /// The recipe as written.
    let recipe: Recipe
    /// The servings the page is scaled to (nil: as written).
    @Binding var displayedServings: Int?
    @State private var didPressAddAll = false

    /// The recipe as displayed: scaled to `displayedServings` when the user has changed it.
    private var shownRecipe: Recipe {
        guard let displayedServings else { return recipe }
        return recipe.scaled(toServings: displayedServings)
    }

    /// A displayable ingredient row with a stable identity for `ForEach` (the document ID of its name, so a
    /// row keeps its identity when the listener republishes with different casing).
    private struct Row: Identifiable {
        let id: String
        let ingredient: IngredientItem
        let isInPantry: Bool
        let isInShoppingList: Bool
    }

    private var rows: [Row] {
        dataManager.ingredientsWithStatus(for: shownRecipe).map { status in
            Row(
                id: IngredientKey.documentID(for: status.ingredient.name),
                ingredient: status.ingredient,
                isInPantry: status.isInPantry,
                isInShoppingList: status.isInShoppingList
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            header

            if let servings = recipe.servings {
                Stepper(
                    "Servings: \(displayedServings ?? servings)",
                    value: Binding(get: { displayedServings ?? servings }, set: { displayedServings = $0 }),
                    in: 1...100
                )
                .accessibilityIdentifier("detail.servings")
            }

            ForEach(rows) { row(for: $0) }
        }
    }

    private var header: some View {
        HStack {
            Text("Ingredients")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top, 10)

            Spacer()

            if dataManager.hasMissingIngredients(for: recipe) {
                Button {
                    Task { await dataManager.addMissingIngredientsToShoppingList(from: shownRecipe) }
                    withAnimation(.easeInOut(duration: 0.2)) { didPressAddAll = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.easeInOut(duration: 0.2)) { didPressAddAll = false }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "cart.fill")
                        Text("Add All").font(.body)
                    }
                    .foregroundColor(.blue)
                    .padding(5)
                    .opacity(didPressAddAll ? 0.4 : 1.0)
                }
                .accessibilityIdentifier("detail.addAll")
            }
        }
    }

    private func row(for status: Row) -> some View {
        HStack {
            Button {
                Task { await dataManager.togglePantry(ingredient: status.ingredient) }
            } label: {
                Image(systemName: status.isInPantry ? "refrigerator.fill" : "refrigerator")
                    .foregroundColor(status.isInPantry ? .green : .gray)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("detail.pantry.\(status.ingredient.name)")
            .accessibilityLabel(status.isInPantry ? "In pantry" : "Not in pantry")

            Text(IngredientFormatter.format(status.ingredient))
                .font(.body)
                .padding(.bottom, 2)

            Spacer()

            if !status.isInPantry {
                Button {
                    Task { await dataManager.toggleShoppingList(ingredient: status.ingredient) }
                } label: {
                    Image(systemName: status.isInShoppingList ? "cart.fill" : "cart")
                        .foregroundColor(status.isInShoppingList ? .blue : .gray)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("detail.cart.\(status.ingredient.name)")
                .accessibilityLabel(status.isInShoppingList ? "On shopping list" : "Not on shopping list")
            }
        }
    }
}
