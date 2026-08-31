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
            // Commit on focus loss so tapping away also saves.
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
        Task { await dataManager.addIngredientToPantry(name: trimmed) }
    }

    private func remove(_ ingredient: IngredientItem) {
        // Fade + collapse immediately; Firestore write runs concurrently.
        withAnimation(.easeOut(duration: 0.35)) {
            _ = hiddenIds.insert(ingredient.id)
        }
        Task { await dataManager.removeIngredientFromPantry(ingredientId: ingredient.id) }
    }
}
