import FirebaseAuth
import SwiftUI

@MainActor
class AuthViewModel: ObservableObject {
    @Published var user: User?  // Holds the current Firebase user
    @Published var isLoading = true
    /// True while an auth request is in flight, so screens can disable their buttons and show progress.
    @Published var isWorking = false

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        setupAuthStateListener()
    }

    deinit {
        if let authStateHandle { Auth.auth().removeStateDidChangeListener(authStateHandle) }
    }

    private func setupAuthStateListener() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
            self?.isLoading = false
        }
    }

    // MARK: - Async API (returns nil on success, otherwise what went wrong)

    func signIn(email: String, password: String) async -> AuthFailure? {
        await perform {
            _ = try await Auth.auth().signIn(withEmail: AuthValidation.normalizedEmail(email), password: password)
        }
    }

    func signUp(email: String, password: String) async -> AuthFailure? {
        await perform {
            _ = try await Auth.auth().createUser(withEmail: AuthValidation.normalizedEmail(email), password: password)
        }
    }

    /// Sends a reset email. An unknown address is reported as success so the app never reveals which
    /// addresses have accounts; only genuine problems (network, malformed address) are surfaced.
    func sendPasswordReset(email: String) async -> AuthFailure? {
        let failure = await perform {
            try await Auth.auth().sendPasswordReset(withEmail: AuthValidation.normalizedEmail(email))
        }
        return failure == .invalidCredentials ? nil : failure
    }

    /// Re-authenticates the signed-in user with their password (needed before deleting the account).
    func reauthenticate(password: String) async -> AuthFailure? {
        guard let user, let email = user.email else { return .unknown }
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        return await perform { _ = try await user.reauthenticate(with: credential) }
    }

    /// Deletes the signed-in user's Firebase Auth account. Call `reauthenticate` first.
    func deleteAuthUser() async -> AuthFailure? {
        guard let user else { return .unknown }
        return await perform { try await user.delete() }
    }

    private func perform(_ work: () async throws -> Void) async -> AuthFailure? {
        isWorking = true
        defer { isWorking = false }
        do {
            try await work()
            return nil
        } catch {
            return AuthFailure(firebaseError: error)
        }
    }

    // MARK: - Completion-handler API (replaced by the async API in the login and sign-up screens, 3.3)

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
