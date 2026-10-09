import SwiftUI

struct AddRecipeView: View {
    @StateObject var viewModel: RecipeFormViewModel
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.presentationMode) var presentationMode

    @State private var newIngredientText: String = ""
    @FocusState private var isAddIngredientFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                titleField
                ingredientsSection
                instructionsSection
                submitButton
            }
            .padding(.bottom, 100)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Add Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(leading: Button("Cancel", action: cancelAction))
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Sections

    private var titleField: some View {
        TextField("Recipe Title", text: $viewModel.title)
            .accessibilityIdentifier("addRecipe.title")
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

            addIngredientRow
            tapToAddSpacer
        }
    }

    private func ingredientRow(_ ingredient: IngredientItem) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(ingredient.name)
                    .padding(.vertical, 10)
                    .padding(.horizontal)
                    .foregroundColor(.primary)

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

    private var addIngredientRow: some View {
        HStack {
            Button {
                commitIngredient()
                isAddIngredientFocused = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.gray)
                    .padding(.leading)
            }
            .buttonStyle(.plain)

            TextField("Add ingredient", text: $newIngredientText)
                .accessibilityIdentifier("addRecipe.ingredientField")
                .focused($isAddIngredientFocused)
                .padding(.vertical, 10)
                .padding(.horizontal, 4)
                .submitLabel(.return)
                .onSubmit(commitIngredient)
        }
        .padding(.horizontal)
        .onChange(of: isAddIngredientFocused) { was, _ in
            if was { commitIngredient() }
        }
    }

    // Fills the empty area under the ingredient list. Tap toggles: focuses the add field
    // when idle, dismisses the keyboard when already typing.
    private var tapToAddSpacer: some View {
        Color.clear
            .contentShape(Rectangle())
            .frame(minHeight: 120)
            .onTapGesture {
                if isAddIngredientFocused {
                    isAddIngredientFocused = false
                } else {
                    isAddIngredientFocused = true
                }
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
                .accessibilityIdentifier("addRecipe.instructions")
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

    private var submitButton: some View {
        HStack {
            Spacer()
            Button(action: submit) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Recipe")
                        .foregroundColor(viewModel.isFormValid() ? .blue : .gray)
                        .opacity(viewModel.isFormValid() ? 1 : 0.5)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
            }
            .disabled(!viewModel.isFormValid())
            .accessibilityIdentifier("addRecipe.submit")
            .padding(.bottom, 20)
            Spacer()
        }
    }

    // MARK: - Actions

    private func commitIngredient() {
        let trimmed = newIngredientText.trimmingCharacters(in: .whitespaces)
        newIngredientText = ""
        guard !trimmed.isEmpty else { return }
        withAnimation(.easeOut(duration: 0.25)) {
            viewModel.addIngredient(name: trimmed)
        }
    }

    private func submit() {
        // Ensure any in-progress input is committed before building the recipe.
        commitIngredient()
        guard let built = viewModel.buildRecipe() else { return }
        Task { await dataManager.addRecipe(recipe: built) }
        viewModel.resetForm()
        presentationMode.wrappedValue.dismiss()
    }

    private func cancelAction() {
        viewModel.resetForm()
        presentationMode.wrappedValue.dismiss()
    }
}
