import Testing

@testable import FoodPlanner

@Suite("AuthValidation")
struct AuthValidationTests {
    @Test func normalisesEmailByTrimmingAndLowercasing() {
        #expect(AuthValidation.normalizedEmail("  Callum@Example.COM \n") == "callum@example.com")
    }

    @Test func acceptsPlausibleEmails() {
        for email in ["a@b.co", "first.last@example.com", "  Tester@Example.org ", "x+tag@sub.domain.io"] {
            #expect(AuthValidation.isPlausibleEmail(email), "\(email)")
        }
    }

    @Test func rejectsImplausibleEmails() {
        for email in ["", "plain", "@example.com", "a@", "a@b", "a@@b.com", "a b@c.com", "a@.com", "a@b."] {
            #expect(!AuthValidation.isPlausibleEmail(email), "\(email)")
        }
    }

    @Test func signUpChecksEmailThenLengthThenMatch() {
        #expect(
            AuthValidation.signUpProblem(email: "nope", password: "123456", confirmation: "123456")
                == AuthFailure.invalidEmail.message)
        #expect(
            AuthValidation.signUpProblem(email: "a@b.co", password: "12345", confirmation: "12345")
                == AuthFailure.weakPassword.message)
        #expect(
            AuthValidation.signUpProblem(email: "a@b.co", password: "123456", confirmation: "654321")
                == "The passwords don't match.")
        #expect(AuthValidation.signUpProblem(email: "a@b.co", password: "123456", confirmation: "123456") == nil)
    }

    @Test func sixCharacterPasswordsAreAccepted() {
        #expect(AuthValidation.signUpProblem(email: "a@b.co", password: "abcdef", confirmation: "abcdef") == nil)
    }

    @Test func loginNeedsAPlausibleEmailAndAPassword() {
        #expect(AuthValidation.loginProblem(email: "a@b.co", password: "") == "Enter your password.")
        #expect(AuthValidation.loginProblem(email: "bad", password: "x") == AuthFailure.invalidEmail.message)
        #expect(AuthValidation.loginProblem(email: "a@b.co", password: "x") == nil)
    }
}
