import SwiftUI

struct SignUpView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var displayName = ""
    @State private var errorMessage = ""
    @FocusState private var focusedField: Field?

    private enum Field { case email, password, confirmation }

    var body: some View {
        VStack {
            Text("Sign Up")
                .font(.largeTitle)
                .padding()
                .accessibilityIdentifier("signup.title")

            TextField("Name (optional, shown on recipes you share)", text: $displayName)
                .textContentType(.name)
                .padding()
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .accessibilityIdentifier("signup.displayName")

            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.username)
                .focused($focusedField, equals: .email)
                .submitLabel(.next)
                .onSubmit { focusedField = .password }
                .padding()
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .accessibilityIdentifier("signup.email")

            SecureField("Password", text: $password)
                .textContentType(.newPassword)
                .focused($focusedField, equals: .password)
                .submitLabel(.next)
                .onSubmit { focusedField = .confirmation }
                .padding()
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .accessibilityIdentifier("signup.password")

            SecureField("Confirm password", text: $confirmation)
                .textContentType(.newPassword)
                .focused($focusedField, equals: .confirmation)
                .submitLabel(.go)
                .onSubmit(submit)
                .padding()
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .accessibilityIdentifier("signup.confirmPassword")

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("signup.error")
            }

            Button(action: submit) {
                if authViewModel.isWorking {
                    ProgressView().tint(.white)
                } else {
                    Text("Sign Up")
                }
            }
            .frame(minWidth: 80)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .disabled(authViewModel.isWorking)
            .accessibilityIdentifier("signup.submit")

            Spacer()
        }
        .padding()
    }

    private func submit() {
        if let problem = AuthValidation.signUpProblem(email: email, password: password, confirmation: confirmation) {
            errorMessage = problem
            return
        }
        errorMessage = ""
        focusedField = nil
        Task {
            if let failure = await authViewModel.signUp(email: email, password: password, displayName: displayName) {
                errorMessage = failure.message
            }
        }
    }
}
