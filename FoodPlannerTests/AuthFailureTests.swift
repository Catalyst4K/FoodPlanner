import FirebaseAuth
import Testing

@testable import FoodPlanner

@Suite("AuthFailure")
struct AuthFailureTests {
    private static let all: [AuthFailure] = [
        .invalidCredentials, .invalidEmail, .emailInUse, .weakPassword, .network,
        .tooManyRequests, .requiresRecentLogin, .userDisabled, .unknown,
    ]

    @Test func everyCaseHasAUserFacingMessage() {
        for failure in Self.all {
            #expect(!failure.message.isEmpty)
            #expect(failure.message.hasSuffix(".") || failure.message.hasSuffix("again."))
        }
    }

    @Test func messagesAreDistinct() {
        #expect(Set(Self.all.map(\.message)).count == Self.all.count)
    }

    @Test func invalidCredentialsDoesNotRevealWhetherTheAccountExists() {
        let message = AuthFailure.invalidCredentials.message.lowercased()
        #expect(!message.contains("no account"))
        #expect(!message.contains("not found"))
        #expect(!message.contains("wrong password"))
        #expect(!message.contains("incorrect password"))
    }

    @Test func messagesDoNotLeakTechnicalDetail() {
        for failure in Self.all {
            let message = failure.message.lowercased()
            #expect(!message.contains("firebase"))
            #expect(!message.contains("error code"))
        }
    }
}

@Suite("AuthViewModel.failure(from:)")
struct AuthFailureMappingTests {
    private func error(_ code: AuthErrorCode) -> Error {
        NSError(domain: AuthErrorDomain, code: code.rawValue)
    }

    @Test func mapsFirebaseCodesToFailures() {
        let expected: [(AuthErrorCode, AuthFailure)] = [
            (.invalidCredential, .invalidCredentials),
            (.wrongPassword, .invalidCredentials),
            (.userNotFound, .invalidCredentials),
            (.invalidEmail, .invalidEmail),
            (.emailAlreadyInUse, .emailInUse),
            (.weakPassword, .weakPassword),
            (.networkError, .network),
            (.tooManyRequests, .tooManyRequests),
            (.requiresRecentLogin, .requiresRecentLogin),
            (.userDisabled, .userDisabled),
        ]
        for (code, failure) in expected {
            #expect(AuthViewModel.failure(from: error(code)) == failure)
        }
    }

    @Test func unknownCodesAndForeignErrorsBecomeUnknown() {
        #expect(AuthViewModel.failure(from: error(.internalError)) == .unknown)
        #expect(AuthViewModel.failure(from: NSError(domain: "SomethingElse", code: 17)) == .unknown)
    }

    @Test func wrongPasswordAndUnknownUserAreIndistinguishable() {
        #expect(
            AuthViewModel.failure(from: error(.wrongPassword)) == AuthViewModel.failure(from: error(.userNotFound)))
    }
}
