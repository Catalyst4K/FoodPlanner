import SwiftUI

struct PantryView: View {
    @ObservedObject var pantryViewModel: PantryViewModel  // Observe pantry changes
    
    var body: some View {
        VStack {
            // Title placed outside of ScrollView for static positioning
            Text("Pantry")
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 16) // Padding from the top
                .padding(.bottom, 8) // Padding below title

            // Scrollable content for the pantry
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {  // Adjusted spacing between items
                    // List of pantry items
                    LazyVStack(spacing: 0) {
                        ForEach(pantryViewModel.pantryItems) { item in
                            HStack {
                                // Ingredient text field with no visible border or background
                                TextField("Enter ingredient", text: Binding(
                                    get: { item.ingredient.text },
                                    set: { newText in
                                        pantryViewModel.handleIngredientChange(id: item.id, newValue: newText)
                                    }
                                ))
                                .padding(.vertical, 10)  // Vertical padding for better spacing
                                .padding(.horizontal)  // Horizontal padding for better alignment
                                .background(Color.clear) // No background for clean look
                                .foregroundColor(.primary)  // Text color for ingredient
                                .cornerRadius(8)  // Rounded corners for a clean, modern look

                                // Delete button for non-empty items
                                if !item.ingredient.text.isEmpty {
                                    Button(action: {
                                        withAnimation(.easeOut(duration: 1.0)) {
                                            pantryViewModel.removeItem(id: item.id)  // Remove item from pantry
                                        }
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                            .padding(5)
                                    }
                                    .buttonStyle(PlainButtonStyle())  // To remove any default button styling
                                }
                            }
                            .padding(.horizontal)  // Added horizontal padding to align the text and checkboxes properly
                            .background(Color(UIColor.systemBackground)) // Background color for each item
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(.horizontal)  // Padding on the horizontal edges for the entire view
        .onAppear {
            // Clean up any empty fields when the pantry view appears
            pantryViewModel.cleanEmptyItems()
        }
        .onTapGesture {
            UIApplication.shared.endEditing()
        }
    }
    
}
