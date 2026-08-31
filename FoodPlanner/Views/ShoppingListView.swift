import SwiftUI

struct ShoppingListView: View {
    @EnvironmentObject private var dataManager: DataManager
    @Binding var sortOption: String
    @State private var newItemText: String = ""
    @State private var hiddenIds: Set<String> = []
    @FocusState private var isAddFieldFocused: Bool

    static let sortNewest = "Newest"
    static let sortByRecipe = "Group by Recipe"
    static let sortOptions = [sortNewest, sortByRecipe]

    /// Ingredients minus anything the user has just checked/deleted.
    private var visibleIngredients: [IngredientItem] {
        dataManager.shoppingListIngredients.filter { !hiddenIds.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Shopping List")
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
                .padding(.bottom, 8)

            ScrollView {
                LazyVStack(spacing: 0) {
                    listContent
                    addRow
                    tapToAddSpacer
                }
            }
        }
        .padding(.horizontal)
        .navigationBarHidden(true)
        .onChange(of: dataManager.shoppingListIngredients.map(\.id)) { _, newIds in
            hiddenIds = hiddenIds.intersection(Set(newIds))
        }
    }

    // MARK: - List content

    @ViewBuilder
    private var listContent: some View {
        if sortOption == Self.sortByRecipe {
            ForEach(groupedSections) { section in
                sectionHeader(section)
                ForEach(section.items) { ingredient in
                    row(for: ingredient)
                        .transition(.opacity)
                }
            }
        } else {
            ForEach(visibleIngredients) { ingredient in
                row(for: ingredient)
                    .transition(.opacity)
            }
        }
    }

    private func sectionHeader(_ section: ShoppingSection) -> some View {
        HStack(spacing: 6) {
            if section.kind == .multiRecipe {
                Image(systemName: "star.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
            }
            Text(section.title)
                .font(.headline)
                .foregroundColor(section.kind == .multiRecipe ? .orange : .primary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    // MARK: - Grouping

    private struct ShoppingSection: Identifiable {
        enum Kind { case multiRecipe, singleRecipe, other }
        let id: String
        let title: String
        let items: [IngredientItem]
        let kind: Kind
    }

    private var groupedSections: [ShoppingSection] {
        var multi: [IngredientItem] = []
        var perRecipe: [(title: String, items: [IngredientItem])] = []
        var perRecipeIndex: [String: Int] = [:]
        var other: [IngredientItem] = []

        for ingredient in visibleIngredients {
            let recipes = dataManager.recipesContaining(ingredient)
            if recipes.count >= 2 {
                multi.append(ingredient)
            } else if let recipe = recipes.first {
                if let i = perRecipeIndex[recipe.title] {
                    perRecipe[i].items.append(ingredient)
                } else {
                    perRecipeIndex[recipe.title] = perRecipe.count
                    perRecipe.append((recipe.title, [ingredient]))
                }
            } else {
                other.append(ingredient)
            }
        }

        var sections: [ShoppingSection] = []
        if !multi.isEmpty {
            sections.append(.init(id: "__multi", title: "Used in multiple recipes", items: multi, kind: .multiRecipe))
        }
        for entry in perRecipe.sorted(by: { $0.title < $1.title }) {
            sections.append(.init(id: entry.title, title: entry.title, items: entry.items, kind: .singleRecipe))
        }
        if !other.isEmpty {
            sections.append(.init(id: "__other", title: "Other", items: other, kind: .other))
        }
        return sections
    }

    // MARK: - Rows

    private func row(for ingredient: IngredientItem) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    check(ingredient)
                } label: {
                    Image(systemName: "circle")
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)

                Text(ingredient.name)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    remove(ingredient)
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .padding(5)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            Divider().padding(.horizontal)
        }
    }

    private var addRow: some View {
        HStack(spacing: 8) {
            Button {
                commit()
                isAddFieldFocused = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)

            TextField("Add ingredient", text: $newItemText)
                .focused($isAddFieldFocused)
                .submitLabel(.return)
                .onSubmit(commit)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .onChange(of: isAddFieldFocused) { was, _ in
            if was { commit() }
        }
    }

    // Fills the empty area below the add row. Tap toggles: focuses the add field when
    // idle, dismisses the keyboard when already typing.
    private var tapToAddSpacer: some View {
        Color.clear
            .contentShape(Rectangle())
            .frame(minHeight: 300)
            .onTapGesture {
                if isAddFieldFocused {
                    isAddFieldFocused = false
                } else {
                    isAddFieldFocused = true
                }
            }
    }

    // MARK: - Actions

    private func commit() {
        let trimmed = newItemText.trimmingCharacters(in: .whitespaces)
        newItemText = ""
        guard !trimmed.isEmpty else { return }
        Task { await dataManager.addIngredientToShoppingList(name: trimmed) }
    }

    private func check(_ ingredient: IngredientItem) {
        // Fade + collapse immediately; move-to-pantry runs concurrently.
        withAnimation(.easeOut(duration: 0.35)) {
            _ = hiddenIds.insert(ingredient.id)
        }
        Task { await dataManager.moveShoppingItemToPantry(ingredient) }
    }

    private func remove(_ ingredient: IngredientItem) {
        withAnimation(.easeOut(duration: 0.35)) {
            _ = hiddenIds.insert(ingredient.id)
        }
        Task { await dataManager.removeIngredientFromShoppingList(ingredientId: ingredient.id) }
    }
}
