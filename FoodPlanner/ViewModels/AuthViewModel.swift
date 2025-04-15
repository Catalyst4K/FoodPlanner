import FirebaseAuth
import SwiftUI

class AuthViewModel: ObservableObject {
    @Published var user: User? // Holds the current Firebase user
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
}
