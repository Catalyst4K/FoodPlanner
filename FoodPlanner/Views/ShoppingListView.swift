import SwiftUI

struct ShoppingListView: View {
    @EnvironmentObject private var dataManager: DataManager
    @AppStorage("shoppingSort") private var sort: ShoppingSort = .newest
    @State private var newItemText: String = ""
    @State private var hiddenIds: Set<String> = []
    @FocusState private var isAddFieldFocused: Bool

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
                    if visibleIngredients.isEmpty {
                        ContentUnavailableView(
                            "Nothing to buy", systemImage: "cart",
                            description: Text("Add items here, or add a recipe's missing ingredients from its page.")
                        )
                        .padding(.top, 24)
                        .accessibilityIdentifier("shopping.empty")
                    }
                    listContent
                    addRow
                    tapToAddSpacer
                }
            }
        }
        .padding(.horizontal)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    Picker("Sort", selection: $sort) {
                        ForEach(ShoppingSort.allCases) { Text($0.title).tag($0) }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .accessibilityLabel("Sort")
                .accessibilityIdentifier("shopping.sort")
            }
        }
        .onChange(of: dataManager.shoppingListIngredients.map(\.id)) { _, newIds in
            hiddenIds = hiddenIds.intersection(Set(newIds))
        }
    }

    // MARK: - List content

    @ViewBuilder
    private var listContent: some View {
        if sort == .byRecipe {
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

    private var groupedSections: [ShoppingSection] {
        ShoppingSection.sections(items: visibleIngredients, recipes: dataManager.userRecipes)
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
                .accessibilityIdentifier("shopping.tick.\(ingredient.name)")
                .accessibilityLabel("Mark \(ingredient.name) as bought")

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
                .accessibilityIdentifier("shopping.delete.\(ingredient.name)")
                .accessibilityLabel("Remove \(ingredient.name)")
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
                .accessibilityIdentifier("shopping.addField")
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
        Task { await dataManager.addToShoppingList(name: trimmed) }
    }

    private func check(_ ingredient: IngredientItem) {
        // Fade + collapse immediately; move-to-pantry runs concurrently.
        withAnimation(.easeOut(duration: 0.35)) {
            _ = hiddenIds.insert(ingredient.id)
        }
        Task {
            if await !dataManager.moveShoppingItemToPantry(ingredient) { unhide(ingredient) }
        }
    }

    private func remove(_ ingredient: IngredientItem) {
        withAnimation(.easeOut(duration: 0.35)) {
            _ = hiddenIds.insert(ingredient.id)
        }
        Task {
            if await !dataManager.removeFromShoppingList(id: ingredient.id) { unhide(ingredient) }
        }
    }

    /// The write failed (the banner explains why), so bring the optimistically hidden row back.
    private func unhide(_ ingredient: IngredientItem) {
        withAnimation(.easeIn(duration: 0.25)) {
            _ = hiddenIds.remove(ingredient.id)
        }
    }
}
