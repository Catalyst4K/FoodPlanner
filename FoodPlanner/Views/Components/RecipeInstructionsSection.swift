import SwiftUI

/// The read-only instructions block on the recipe detail screen. User content: plain `Text`.
struct RecipeInstructionsSection: View {
    let instructions: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Divider().padding(.vertical, 10)

            Text("Instructions")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top, 10)

            Text(instructions)
                .font(.body)
                .padding(.top, 10)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
