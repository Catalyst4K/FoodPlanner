import SwiftUI

struct PantryView: View {
    @EnvironmentObject private var dataManager: DataManager
    @State private var newItemText: String = ""
    @State private var hiddenIds: Set<String> = []
    @FocusState private var isAddFieldFocused: Bool

    private var visibleIngredients: [IngredientItem] {
        dataManager.pantryIngredients.filter { !hiddenIds.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Pantry")
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
                .padding(.bottom, 8)

            ScrollView {
                LazyVStack(spacing: 0) {
                    if visibleIngredients.isEmpty {
                        ContentUnavailableView(
                            "Your pantry is empty", systemImage: "refrigerator",
                            description: Text(
                                "Add what's in your cupboards and fridge, and recipes will show what you can cook.")
                        )
                        .padding(.top, 24)
                        .accessibilityIdentifier("pantry.empty")
                    }
                    ForEach(visibleIngredients) { ingredient in
                        row(for: ingredient)
                            .transition(.opacity)
                    }
                    addRow
                    tapToAddSpacer
                }
            }
        }
        .padding(.horizontal)
        .onChange(of: dataManager.pantryIngredients.map(\.id)) { _, newIds in
            hiddenIds = hiddenIds.intersection(Set(newIds))
        }
    }

    // MARK: - Rows

    private func row(for ingredient: IngredientItem) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
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
                .accessibilityIdentifier("pantry.delete.\(ingredient.name)")
                .accessibilityLabel("Remove \(ingredient.name)")
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            Divider().padding(.horizontal)
        }
    }

    private var addRow: some View {
        QuickAddRow(
            text: $newItemText, isFocused: $isAddFieldFocused, style: .list, fieldIdentifier: "pantry.addField",
            onCommit: commit)
    }

    // Fills the empty area below the add row. Tap toggles: focuses the add field when
    // idle, dismisses the keyboard when already typing.
    private var tapToAddSpacer: some View {
        TapToFocusSpacer(isFocused: $isAddFieldFocused, minHeight: 300)
    }

    // MARK: - Actions

    private func commit() {
        let trimmed = newItemText.trimmingCharacters(in: .whitespaces)
        newItemText = ""
        guard !trimmed.isEmpty else { return }
        Task { await dataManager.addToPantry(name: trimmed) }
    }

    private func remove(_ ingredient: IngredientItem) {
        // Fade + collapse immediately; Firestore write runs concurrently.
        withAnimation(.easeOut(duration: 0.35)) {
            _ = hiddenIds.insert(ingredient.id)
        }
        Task {
            if await !dataManager.removeFromPantry(id: ingredient.id) {
                // The write failed (the banner explains why): bring the row back.
                withAnimation(.easeIn(duration: 0.25)) {
                    _ = hiddenIds.remove(ingredient.id)
                }
            }
        }
    }
}
