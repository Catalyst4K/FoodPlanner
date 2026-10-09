import SwiftUI

/// "Forgot password?" sheet. The confirmation never says whether an account exists for the address.
struct PasswordResetView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var email: String
    @State private var message = ""
    @State private var isError = false

    init(authViewModel: AuthViewModel, initialEmail: String) {
        self.authViewModel = authViewModel
        _email = State(initialValue: initialEmail)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Enter your email and we'll send you a link to reset your password.")
                    .multilineTextAlignment(.center)

                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .accessibilityIdentifier("reset.email")

                if !message.isEmpty {
                    Text(message)
                        .foregroundColor(isError ? .red : .secondary)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("reset.message")
                }

                Button(action: submit) {
                    if authViewModel.isWorking {
                        ProgressView().tint(.white)
                    } else {
                        Text("Send reset link")
                    }
                }
                .frame(minWidth: 120)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(authViewModel.isWorking)
                .accessibilityIdentifier("reset.submit")

                Spacer()
            }
            .padding()
            .navigationTitle("Reset password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .accessibilityIdentifier("reset.close")
                }
            }
        }
    }

    private func submit() {
        guard AuthValidation.isPlausibleEmail(email) else {
            isError = true
            message = AuthFailure.invalidEmail.message
            return
        }
        Task {
            if let failure = await authViewModel.sendPasswordReset(email: email) {
                isError = true
                message = failure.message
            } else {
                isError = false
                message = "If an account exists for that email, we've sent a reset link."
            }
        }
    }
}
