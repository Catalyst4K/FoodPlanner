//
//  FoodPlannerUITests.swift
//  FoodPlannerUITests
//
//  Acceptance tests. These launch the real app and drive the UI via XCUIApplication.
//  Firebase is real, so login/signup submissions aren't asserted end-to-end — we only
//  verify the UI shape/flow (screens shown, controls present, navigation works).
//

import XCTest

final class FoodPlannerUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    /// Launch a fresh app instance in the signed-out state.
    @MainActor
    private func launchSignedOut() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest-signed-out"]
        app.launch()
        return app
    }

    /// Taps a field until the keyboard is up, then types. New-password fields can lose the first taps
    /// while iOS considers offering a strong password.
    @MainActor
    private func type(_ text: String, into field: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<5 {
            field.tap()
            if app.keyboards.firstMatch.waitForExistence(timeout: 3) { break }
        }
        // iOS offers a strong password for new-password fields and swallows typing until it is dismissed.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let closers = [
            app.buttons["Choose My Own Password"], app.buttons["xmark"], springboard.buttons["Choose My Own Password"],
            springboard.buttons["xmark"],
        ]
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline {
            if let closer = closers.first(where: { $0.exists }) {
                closer.tap()
                break
            }
            usleep(300_000)
        }
        if !app.keyboards.firstMatch.exists { field.tap() }
        field.typeText(text)
    }

    // MARK: - Tests

    @MainActor
    func test_appLaunches() throws {
        // Smoke: the app should launch and either the Login title or the Recipes tab exists.
        let app = XCUIApplication()
        app.launch()

        let login = app.staticTexts["login.title"]
        let recipesTab = app.tabBars.buttons["Recipes"]

        let visible = login.waitForExistence(timeout: 5) || recipesTab.waitForExistence(timeout: 5)
        XCTAssertTrue(visible, "Neither the Login screen nor the main tab bar became visible on launch")
    }

    @MainActor
    func test_signedOutUserSeesLoginScreen() throws {
        let app = launchSignedOut()

        XCTAssertTrue(
            app.staticTexts["login.title"].waitForExistence(timeout: 5),
            "Login title should be visible when signed out"
        )
        XCTAssertTrue(app.textFields["login.email"].exists, "Email field should be present")
        XCTAssertTrue(app.secureTextFields["login.password"].exists, "Password field should be present")
        XCTAssertTrue(app.buttons["login.submit"].exists, "Log In button should be present")
        XCTAssertTrue(app.buttons["login.signupLink"].exists, "Sign up link should be present")
    }

    @MainActor
    func test_loginToSignupNavigation() throws {
        let app = launchSignedOut()

        XCTAssertTrue(app.staticTexts["login.title"].waitForExistence(timeout: 5))

        app.buttons["login.signupLink"].tap()

        XCTAssertTrue(
            app.staticTexts["signup.title"].waitForExistence(timeout: 3),
            "Tapping the sign-up link should navigate to a Sign Up screen"
        )
    }

    @MainActor
    func test_invalidLoginShowsError() throws {
        let app = launchSignedOut()

        XCTAssertTrue(app.staticTexts["login.title"].waitForExistence(timeout: 5))

        let email = app.textFields["login.email"]
        email.tap()
        email.typeText("not-a-real-user@example.invalid")

        let password = app.secureTextFields["login.password"]
        password.tap()
        password.typeText("wrongpassword")

        app.buttons["login.submit"].tap()

        // Whatever Firebase answers (wrong credentials, no network, ...), the screen shows an error.
        XCTAssertTrue(
            app.staticTexts["login.error"].waitForExistence(timeout: 8),
            "An invalid login should surface an error"
        )
    }

    @MainActor
    func test_loginValidatesTheEmailBeforeCallingFirebase() throws {
        let app = launchSignedOut()
        XCTAssertTrue(app.staticTexts["login.title"].waitForExistence(timeout: 5))

        let email = app.textFields["login.email"]
        email.tap()
        email.typeText("not-an-email")
        app.buttons["login.submit"].tap()

        let error = app.staticTexts["login.error"]
        XCTAssertTrue(error.waitForExistence(timeout: 3))
        XCTAssertEqual(error.label, "That doesn't look like a valid email address.")
    }

    @MainActor
    func test_signupChecksThatPasswordsMatch() throws {
        let app = launchSignedOut()
        XCTAssertTrue(app.staticTexts["login.title"].waitForExistence(timeout: 5))
        app.buttons["login.signupLink"].tap()
        XCTAssertTrue(app.staticTexts["signup.title"].waitForExistence(timeout: 3))

        type("new.user@example.com", into: app.textFields["signup.email"], in: app)
        type("abcdef", into: app.secureTextFields["signup.password"], in: app)
        type("abcdeg", into: app.secureTextFields["signup.confirmPassword"], in: app)
        app.buttons["signup.submit"].tap()

        let error = app.staticTexts["signup.error"]
        XCTAssertTrue(error.waitForExistence(timeout: 3))
        XCTAssertEqual(error.label, "The passwords don't match.")
    }

    @MainActor
    func test_forgotPasswordSheetOpens() throws {
        let app = launchSignedOut()
        XCTAssertTrue(app.staticTexts["login.title"].waitForExistence(timeout: 5))
        app.buttons["login.forgotPassword"].tap()
        XCTAssertTrue(app.textFields["reset.email"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["reset.submit"].exists)
    }
}
