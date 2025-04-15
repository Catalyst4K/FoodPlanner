import SwiftUI

struct AccountView: View {
    @ObservedObject var authViewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("Account")
                .font(.largeTitle)
                .bold()

            // Check if the user is logged in
            if let user = authViewModel.user {
                Text("Logged in as:")
                Text(user.email ?? "Unknown")
                    .font(.headline)

                Button("Log Out") {
                    authViewModel.signOut()
                }
                .foregroundColor(.red)
                .padding(.top)
            } else {
                Text("Not logged in")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}
