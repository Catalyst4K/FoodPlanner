import Foundation

/// Client-side checks for the login and sign-up forms. Foundation-only so they are unit-tested; Firebase
/// remains the authority (these just give instant, friendly feedback before a network call).
enum AuthValidation {
    static let minimumPasswordLength = 6

    /// Trimmed and lower-cased: what is sent to Firebase.
    static func normalizedEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// A deliberately loose "looks like an email" check: one `@`, something either side, a dot in the
    /// domain, no spaces. Anything stricter belongs to the server.
    static func isPlausibleEmail(_ email: String) -> Bool {
        let value = normalizedEmail(email)
        let parts = value.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !value.contains(" ") else { return false }
        let domain = parts[1]
        return domain.contains(".") && !domain.hasPrefix(".") && !domain.hasSuffix(".")
    }

    /// The first problem with a sign-up form, as an inline message, or nil if it can be submitted.
    static func signUpProblem(email: String, password: String, confirmation: String) -> String? {
        if !isPlausibleEmail(email) { return AuthFailure.invalidEmail.message }
        if password.count < minimumPasswordLength { return AuthFailure.weakPassword.message }
        if password != confirmation { return "The passwords don't match." }
        return nil
    }

    /// The first problem with a login form, or nil.
    static func loginProblem(email: String, password: String) -> String? {
        if !isPlausibleEmail(email) { return AuthFailure.invalidEmail.message }
        if password.isEmpty { return "Enter your password." }
        return nil
    }
}
