import SwiftUI

struct AddRecipeView: View {
    @StateObject var viewModel: RecipeFormViewModel
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        RecipeFormView(
            viewModel: viewModel, idPrefix: "addRecipe", knownNames: dataManager.knownIngredientNames,
            footer: AnyView(submitButton)
        )
        .navigationTitle("Add Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel", action: cancelAction)
                    .accessibilityIdentifier("addRecipe.cancel")
            }
        }
        .navigationBarBackButtonHidden(true)
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

    private func submit() {
        // Ensure any in-progress input is committed before building the recipe.
        viewModel.commitPendingIngredient()
        guard let built = viewModel.buildRecipe() else { return }
        Task { await dataManager.addRecipe(recipe: built) }
        viewModel.resetForm()
        dismiss()
    }

    private func cancelAction() {
        viewModel.resetForm()
        dismiss()
    }
}
