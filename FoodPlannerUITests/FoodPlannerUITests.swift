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

        // SignUpView doesn't have identifiers, but its navigation title / text should appear.
        // Look for a "Sign Up" static text within 3 seconds.
        let signUpText = app.staticTexts["Sign Up"]
        XCTAssertTrue(
            signUpText.waitForExistence(timeout: 3),
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

        // The view sets errorMessage = "Invalid credentials" on failure.
        let error = app.staticTexts["Invalid credentials"]
        XCTAssertTrue(
            error.waitForExistence(timeout: 8),
            "An invalid login should surface an 'Invalid credentials' error"
        )
    }
}
