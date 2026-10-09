import SwiftUI

struct LoginView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var path = NavigationPath()
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var showingReset = false
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    var body: some View {
        NavigationStack(path: $path) {
            VStack {
                Text("Login")
                    .font(.largeTitle)
                    .padding()
                    .accessibilityIdentifier("login.title")

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
                    .accessibilityIdentifier("login.email")

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit(submit)
                    .padding()
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .accessibilityIdentifier("login.password")

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("login.error")
                }

                Button(action: submit) {
                    if authViewModel.isWorking {
                        ProgressView().tint(.white)
                    } else {
                        Text("Log In")
                    }
                }
                .frame(minWidth: 80)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(authViewModel.isWorking)
                .accessibilityIdentifier("login.submit")

                Button("Forgot password?") {
                    showingReset = true
                }
                .padding(.top, 8)
                .accessibilityIdentifier("login.forgotPassword")

                Button("Don't have an account? Sign up") {
                    path.append("signup")
                }
                .padding()
                .foregroundColor(.blue)
                .accessibilityIdentifier("login.signupLink")

                Spacer()
            }
            .padding()
            .navigationDestination(for: String.self) { value in
                if value == "signup" {
                    SignUpView(authViewModel: authViewModel)
                }
            }
            .sheet(isPresented: $showingReset) {
                PasswordResetView(authViewModel: authViewModel, initialEmail: email)
            }
        }
    }

    private func submit() {
        if let problem = AuthValidation.loginProblem(email: email, password: password) {
            errorMessage = problem
            return
        }
        errorMessage = ""
        focusedField = nil
        Task {
            if let failure = await authViewModel.signIn(email: email, password: password) {
                password = ""
                errorMessage = failure.message
            }
        }
    }
}
