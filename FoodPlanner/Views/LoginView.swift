import SwiftUI

struct LoginView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var path = NavigationPath()
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack(path: $path) {
            VStack {
                Text("Login")
                    .font(.largeTitle)
                    .padding()

                TextField("Email", text: $email)
                    .padding()
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                SecureField("Password", text: $password)
                    .padding()
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }

                Button("Log In") {
                    authViewModel.login(email: email, password: password) { success in
                        if success {
                            // Navigate to MainTabView
                        } else {
                            password = ""
                            errorMessage = "Invalid credentials"
                        }
                    }
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)

                Button("Don't have an account? Sign up") {
                    path.append("signup")
                }
                .padding()
                .foregroundColor(.blue)

                Spacer()
            }
            .padding()
            .navigationDestination(for: String.self) { value in
                if value == "signup" {
                    SignUpView(authViewModel: authViewModel)
                }
            }
        }
    }
}
