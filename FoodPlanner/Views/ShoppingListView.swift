import SwiftUI

struct ShoppingListView: View {
    @ObservedObject var shoppingListViewModel: ShoppingListViewModel
    @ObservedObject var pantryViewModel: PantryViewModel
    
    var body: some View {
        VStack {
            // Title placed outside of ScrollView for static positioning
            Text("Shopping List")
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 16) // Padding from top
                .padding(.bottom, 8) // Padding below the title
            
            // Scrollable shopping list content
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {

                    // List of shopping list items
                    LazyVStack(spacing: 0) {
                        ForEach(shoppingListViewModel.shoppingList) { item in
                            VStack {
                                HStack {
                                    // Checkbox to toggle the purchase status of the item
                                    Button(action: {
                                        // Only toggle if the ingredient is not empty
                                        if !item.ingredient.text.isEmpty {
                                            shoppingListViewModel.toggleItemChecked(id: item.id, pantryViewModel: pantryViewModel)  // Toggle checked state and move to pantry
                                        }
                                    }) {
                                        Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(item.isChecked ? .green : .gray)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .disabled(item.ingredient.text.isEmpty) // Disable checkbox for empty fields

                                    // Ingredient text field - No border, clean appearance
                                    TextField("Enter ingredient", text: Binding(
                                        get: { item.ingredient.text },
                                        set: { newText in
                                            shoppingListViewModel.handleIngredientChange(id: item.id, newValue: newText)
                                        }
                                    ))
                                    .padding(.vertical, 10)  // Vertical padding for better spacing
                                    .padding(.horizontal)  // Horizontal padding for better alignment
                                    .background(Color.clear) // No background for clean look
                                    .foregroundColor(.primary)  // Text color for ingredient
                                    .cornerRadius(8)  // Rounded corners for a clean, modern look

                                    // Delete button to remove ingredient from the list
                                    // Hide the delete button for the last empty item
                                    if !item.ingredient.text.isEmpty {
                                        Button(action: {
                                            shoppingListViewModel.removeItem(id: item.id)  // Remove item
                                        }) {
                                            Image(systemName: "trash")
                                                .foregroundColor(.red)
                                                .padding(5)
                                        }
                                        .buttonStyle(PlainButtonStyle())  // To remove any default button styling
                                    }
                                }
                                .padding(.horizontal) // Padding to ensure dividers don't touch the sides
                                .background(Color(UIColor.systemBackground)) // Background color for each item
                                
                                // Divider (with the appropriate padding for spacing)
                                Divider()
                                    .padding(.horizontal)
                            }
                            
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onTapGesture {
            UIApplication.shared.endEditing()
        }
    }
    
}
