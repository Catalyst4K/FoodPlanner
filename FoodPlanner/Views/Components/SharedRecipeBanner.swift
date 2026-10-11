import SwiftUI

/// "Shared by …" strip shown on recipes that belong to someone else. The name is user content: plain `Text`.
struct SharedRecipeBanner: View {
    let ownerName: String?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.2.fill")
                .foregroundColor(.blue)
            Text(ownerName.map { "Shared by \($0)" } ?? "Shared by another user")
                .accessibilityIdentifier("detail.sharedBy")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}
