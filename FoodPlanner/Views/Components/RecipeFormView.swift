import SwiftUI

/// The recipe form: title, servings, ingredient list with the quick-add row, and instructions. Shared by Add
/// Recipe (a pushed page) and the in-place edit on the recipe detail screen. The caller owns the toolbar and any
/// submit button; it should call `viewModel.commitPendingIngredient()` before building the recipe.
struct RecipeFormView: View {
    @ObservedObject var viewModel: RecipeFormViewModel
    /// Accessibility identifier prefix: "addRecipe" or "detail.edit" (`.title`, `.ingredientField`, `.instructions`).
    let idPrefix: String
    var knownNames: [String] = []
    /// Extra content under the instructions, e.g. Add Recipe's submit button.
    var footer: AnyView?

    @FocusState private var isAddIngredientFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                titleField
                ServingsStepper(servings: $viewModel.servings)
                ingredientsSection
                instructionsSection
                if let footer { footer }
            }
            .padding(.bottom, 100)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var titleField: some View {
        TextField("Recipe Title", text: $viewModel.title)
            .accessibilityIdentifier("\(idPrefix).title")
            .font(.title)
            .fontWeight(.bold)
            .padding(.top, 40)
            .multilineTextAlignment(.center)
            .textFieldStyle(.plain)
            .padding(.horizontal)
            .overlay(Divider().background(Color.gray), alignment: .bottom)
            .padding(.horizontal)
    }

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Ingredients")
                .font(.title2)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 4)

            ForEach(viewModel.ingredients) { ingredient in
                ingredientRow(ingredient)
                    .transition(.opacity)
            }

            QuickAddRow(
                text: $viewModel.pendingIngredient, isFocused: $isAddIngredientFocused,
                fieldIdentifier: "\(idPrefix).ingredientField", knownNames: knownNames,
                onCommit: {
                    withAnimation(.easeOut(duration: 0.25)) { viewModel.commitPendingIngredient() }
                })
            // Fills the empty area under the list. Tapping toggles the add field: focuses it when idle, or
            // dismisses the keyboard when typing (losing focus commits any in-progress text).
            TapToFocusSpacer(isFocused: $isAddIngredientFocused)
        }
    }

    private func ingredientRow(_ ingredient: IngredientItem) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(IngredientFormatter.format(ingredient))
                    .padding(.vertical, 10)
                    .padding(.horizontal)
                    .foregroundColor(.primary)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.editIngredientAsText(id: ingredient.id)
                        isAddIngredientFocused = true
                    }

                Spacer()

                Button {
                    withAnimation(.easeOut(duration: 0.25)) {
                        viewModel.removeIngredient(id: ingredient.id)
                    }
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .padding(5)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            Divider()
        }
    }

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Instructions")
                .font(.title2)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.top, 20)

            TextEditor(text: $viewModel.instructions)
                .accessibilityIdentifier("\(idPrefix).instructions")
                .frame(minHeight: 150)
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(20)
                .font(.body)
                .padding(.horizontal)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.gray, lineWidth: 0.5)
                        .padding(10)
                }
        }
    }
}
