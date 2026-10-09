import XCTest

/// Captures the screenshots used in the README and App Store listing.
///
/// Not part of normal UI test runs: it only executes when `SCREENSHOTS=1` is in the test runner's
/// environment, against the Firebase emulators seeded by `firebase/seed.mjs`. Use `make screenshots`.
final class ScreenshotTests: XCTestCase {
    private let email = "demo@example.com"
    private let password = "demo-password-123"

    override func setUpWithError() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["SCREENSHOTS"] == "1",
            "Screenshots only run via `make screenshots`"
        )
        continueAfterFailure = false
    }

    /// Captures one appearance, chosen by `SCREENSHOT_MODE` (`light` or `dark`). The script sets the
    /// simulator's system appearance to match before each run.
    @MainActor
    func test_captureScreenshots() throws {
        let name = ProcessInfo.processInfo.environment["SCREENSHOT_MODE"] ?? "light"
        let app = XCUIApplication()
        app.launchArguments += ["-use-firebase-emulator", "-uitest-signed-out", "-screenshots"]
        app.launch()
        signIn(app)

        XCTAssertTrue(app.tabBars.buttons["Recipes"].waitForExistence(timeout: 20), "Signed-in tab bar missing")
        dismissPasswordPrompt(in: app)
        // Give the snapshot listeners a moment to deliver the seeded data.
        let recipe = app.staticTexts["Tomato Basil Spaghetti"]
        XCTAssertTrue(recipe.waitForExistence(timeout: 20), "Seed data missing")
        for _ in 0..<5 where !recipe.isHittable {
            dismissPasswordPrompt(in: app)
            sleep(1)
        }
        capture("recipes-\(name)", app)

        recipe.tap()
        sleep(2)
        capture("recipe-detail-portrait-\(name)", app)

        // Landscape captures are left out: XCTest screenshots of a rotated simulator come back
        // sideways and cropped (see docs/IMPLEMENTATION_PLAN.md, R.15).

        goBack(app)
        app.tabBars.buttons["Pantry"].tap()
        sleep(2)
        capture("pantry-\(name)", app)

        app.tabBars.buttons["Shopping"].tap()
        sleep(2)
        capture("shopping-\(name)", app)
    }

    @MainActor
    private func signIn(_ app: XCUIApplication) {
        let emailField = app.textFields["login.email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 15), "Login screen missing")
        type(email, into: emailField, in: app)
        type(password, into: app.secureTextFields["login.password"], in: app)
        app.buttons["login.submit"].tap()
    }

    /// Pops the recipe detail: try the nav bar's back button, then the interactive edge swipe.
    @MainActor
    private func goBack(_ app: XCUIApplication) {
        let tabs = app.tabBars.buttons["Pantry"]
        let back = app.navigationBars.buttons.firstMatch
        if back.exists { back.tap() }
        if tabs.waitForExistence(timeout: 3) { return }
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.0, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: end)
        XCTAssertTrue(tabs.waitForExistence(timeout: 5), "Could not leave the recipe detail")
    }

    /// Taps a field until the keyboard is up (the first tap can be lost while the screen settles), then types.
    @MainActor
    private func type(_ text: String, into field: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<5 {
            field.tap()
            if app.keyboards.firstMatch.waitForExistence(timeout: 3) { break }
        }
        field.typeText(text)
    }

    /// iOS offers to save the demo password after sign-in; that sheet would end up in the screenshots.
    /// Depending on the OS version it belongs to the app or to Springboard, so look in both.
    @MainActor
    private func dismissPasswordPrompt(in app: XCUIApplication) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            for candidate in [app.buttons["Not Now"], springboard.buttons["Not Now"]] where candidate.exists {
                candidate.tap()
                return
            }
            usleep(300_000)
        }
    }

    @MainActor
    private func capture(_ name: String, _ app: XCUIApplication) {
        // App-level screenshot: includes the status bar and is not affected by system overlays.
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
