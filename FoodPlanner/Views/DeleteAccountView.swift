import SwiftUI

/// Asks for the password, then deletes the account. Order matters: re-authenticate first, so a
/// `requiresRecentLogin` failure can never strand an account whose data is already gone. Deleting
/// the data is idempotent, so if the final step fails the user can simply try again.
struct DeleteAccountView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isDeleting = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Enter your password to permanently delete your account and all of its data.")
                    .multilineTextAlignment(.center)

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .accessibilityIdentifier("account.deletePassword")

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("account.deleteError")
                }

                Button(role: .destructive, action: submit) {
                    if isDeleting {
                        ProgressView().tint(.white)
                    } else {
                        Text("Delete Account")
                    }
                }
                .frame(minWidth: 140)
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(isDeleting || password.isEmpty)
                .accessibilityIdentifier("account.deleteConfirm")

                Spacer()
            }
            .padding()
            .navigationTitle("Delete account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isDeleting)
                        .accessibilityIdentifier("account.deleteCancel")
                }
            }
            .interactiveDismissDisabled(isDeleting)
        }
    }

    private func submit() {
        errorMessage = ""
        isDeleting = true
        Task {
            defer { isDeleting = false }
            if let failure = await authViewModel.reauthenticate(password: password) {
                password = ""
                errorMessage = failure.message
                return
            }
            guard await dataManager.deleteAllUserData() else {
                errorMessage = "We couldn't delete your data. Nothing else was changed; please try again."
                return
            }
            if let failure = await authViewModel.deleteAuthUser() {
                errorMessage = failure.message + " Your data has been deleted; try again to finish."
            }
            // On success the auth listener signs the user out and the app returns to the login screen.
        }
    }
}
