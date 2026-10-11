import SwiftUI

/// "Save to My Recipes" on someone else's shared recipe: copies it into the user's list, then closes the page.
struct SaveSharedRecipeButton: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    @State private var didPressSave = false

    var body: some View {
        Button {
            Task { await dataManager.saveSharedRecipeToMyList(recipe) }
            withAnimation(.easeInOut(duration: 0.2)) { didPressSave = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                dismiss()
            }
        } label: {
            HStack {
                Image(systemName: "square.and.arrow.down")
                Text(didPressSave ? "Saved!" : "Save to My Recipes")
            }
            .foregroundColor(.white)
            .fontWeight(.bold)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .padding(.top, 20)
        .disabled(didPressSave)
    }
}
