import FirebaseAuth
import Foundation

extension AuthFailure {
    /// Maps a Firebase Auth error to a user-facing failure. Wrong password and unknown user both become
    /// `.invalidCredentials`, so the app never reveals whether an account exists.
    init(firebaseError error: Error) {
        let nsError = error as NSError
        guard nsError.domain == AuthErrorDomain, let code = AuthErrorCode(rawValue: nsError.code) else {
            self = .unknown
            return
        }
        switch code {
        case .invalidCredential, .wrongPassword, .userNotFound: self = .invalidCredentials
        case .invalidEmail: self = .invalidEmail
        case .emailAlreadyInUse: self = .emailInUse
        case .weakPassword: self = .weakPassword
        case .networkError: self = .network
        case .tooManyRequests: self = .tooManyRequests
        case .requiresRecentLogin: self = .requiresRecentLogin
        case .userDisabled: self = .userDisabled
        default: self = .unknown
        }
    }
}
