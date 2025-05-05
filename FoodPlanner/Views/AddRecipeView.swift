import SwiftUI

struct AddRecipeView: View {
    @ObservedObject var viewModel: RecipeListViewModel
    @Environment(\.presentationMode) var presentationMode

    // Track the focus state of each TextField
    @FocusState private var focusedField: UUID?

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Recipe title field with padding to prevent the border from touching the edge
                    TextField("Recipe Title", text: $viewModel.title)
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.top, 40)
                        .multilineTextAlignment(.center)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.horizontal) // Add horizontal padding to the TextField
                        .overlay(Divider().background(Color.gray), alignment: .bottom)
                        .padding(.horizontal) // Add padding to the divider to prevent it from touching edges

                    // Ingredients list
                    VStack(spacing: 10) {
                        ForEach(viewModel.ingredients) { ingredient in
                            HStack {
                                // Custom Binding for ingredient field
                                let binding = Binding<String>(
                                    get: {
                                        ingredient.text
                                    },
                                    set: { newValue in
                                        viewModel.handleIngredientChange(id: ingredient.id, newValue: newValue)
                                    }
                                )

                                // Ingredient TextField with FocusState
                                TextField("Ingredient", text: binding)
                                    .focused($focusedField, equals: ingredient.id)  // Bind to the specific field
                                    .padding(.vertical, 8)
                                    .padding(.horizontal)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .lineLimit(nil)

                                // Delete button for non-empty fields
                                if !ingredient.text.isEmpty {
                                    Button(action: {
                                        viewModel.removeIngredient(id: ingredient.id)
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                            .padding(5)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal)
                            .background(Color.white)
                            .cornerRadius(8)
                            .overlay(Divider().background(Color.gray), alignment: .bottom)
                            .padding(.horizontal)
                        }
                    }

                    // Instructions section
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Instructions")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 20)

                        TextEditor(text: $viewModel.instructions)
                            .frame(minHeight: 150)
                            .padding(10)
                            .background(Color.white)
                            .cornerRadius(20)
                            .font(.body)
                            .padding(.horizontal)
                            .overlay(content: {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(.gray, lineWidth: 0.5)
                                    .padding(10)
                            })
                    }

                    // Add Recipe Button
                    HStack {
                        Spacer() // Push the button to the bottom
                        Button(action: addRecipe) {
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
                        .padding(.bottom, 20)
                        Spacer()
                    }
                }
                .padding(.bottom, 100) // Ensure enough space for the Add Recipe Button
            }
        }
        .navigationTitle("Add Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(leading: Button("Cancel", action: cancelAction))
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // Ensure the first ingredient field is available when the view appears
            if viewModel.ingredients.isEmpty {
                viewModel.ingredients = [IngredientItem(text: "")]
            }
        }
        .onTapGesture {
            UIApplication.shared.endEditing()
        }
    }

    private func addRecipe() {
        viewModel.submitRecipe()
        presentationMode.wrappedValue.dismiss()
    }

    private func cancelAction() {
        viewModel.resetForm()
        presentationMode.wrappedValue.dismiss()
    }
}
