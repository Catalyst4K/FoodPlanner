import Foundation

/// What went wrong during an auth action, with a message that is safe to show the user.
/// Foundation-only; `AuthViewModel` maps Firebase errors to these. Messages: docs/IMPLEMENTATION_PLAN.md, Appendix D.
enum AuthFailure: Equatable {
    case invalidCredentials
    case invalidEmail
    case emailInUse
    case weakPassword
    case network
    case tooManyRequests
    case requiresRecentLogin
    case userDisabled
    case unknown

    var message: String {
        switch self {
        case .invalidCredentials: "That email and password don't match an account."
        case .invalidEmail: "That doesn't look like a valid email address."
        case .emailInUse: "An account already exists for that email. Try logging in."
        case .weakPassword: "Choose a password with at least 6 characters."
        case .network: "Can't reach the server. Check your connection and try again."
        case .tooManyRequests: "Too many attempts. Wait a moment and try again."
        case .requiresRecentLogin: "For your security, please enter your password again."
        case .userDisabled: "This account has been disabled."
        case .unknown: "Something went wrong. Please try again."
        }
    }
}
