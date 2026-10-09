import FirebaseAuth
import SwiftUI

@MainActor
class AuthViewModel: ObservableObject {
    @Published var user: User?  // Holds the current Firebase user
    @Published var isLoading = true

    init() {
        setupAuthStateListener()
    }

    private func setupAuthStateListener() {
        _ = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
            self?.isLoading = false
        }
    }

    // Log the user out
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.user = nil
        } catch let error {
            print("Logout error: \(error.localizedDescription)")
        }
    }

    // Log in with email and password
    func login(email: String, password: String, completion: @escaping (Bool) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                print("Login error: \(error.localizedDescription)")
                completion(false)
                return
            }
            self.user = result?.user
            completion(true)
        }
    }

    // Sign up with email and password
    func signUp(email: String, password: String, completion: @escaping (Bool) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                print("SignUp error: \(error.localizedDescription)")
                completion(false)
                return
            }
            self.user = result?.user
            completion(true)
        }
    }

    /// Maps a Firebase Auth error to a user-facing failure. Wrong password and unknown user both surface as
    /// `.invalidCredentials`, so the app never reveals whether an account exists.
    nonisolated static func failure(from error: Error) -> AuthFailure {
        let nsError = error as NSError
        guard nsError.domain == AuthErrorDomain, let code = AuthErrorCode(rawValue: nsError.code) else {
            return .unknown
        }
        switch code {
        case .invalidCredential, .wrongPassword, .userNotFound: return .invalidCredentials
        case .invalidEmail: return .invalidEmail
        case .emailAlreadyInUse: return .emailInUse
        case .weakPassword: return .weakPassword
        case .networkError: return .network
        case .tooManyRequests: return .tooManyRequests
        case .requiresRecentLogin: return .requiresRecentLogin
        case .userDisabled: return .userDisabled
        default: return .unknown
        }
    }
}
