import XCTest

/// End-to-end flows against the Firebase emulators with a freshly signed-up user per test.
/// Opt-in: runs only when `FIREBASE_EMULATOR=1` is set (use `make test-ui-emulated`), because it needs the
/// Auth and Firestore emulators running with the fake CI Firebase config.
final class SignedInFlowTests: XCTestCase {
    private let password = "ui-test-password-1"

    override func setUpWithError() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["FIREBASE_EMULATOR"] == "1",
            "Needs the Firebase emulators; run `make test-ui-emulated`"
        )
        continueAfterFailure = false
    }

    // MARK: - Tests

    @MainActor
    func test_emptyPantryAndShoppingListShowHints() throws {
        let app = launch()
        _ = signUp(app)

        app.tabBars.buttons["Pantry"].tap()
        XCTAssertTrue(app.staticTexts["Your pantry is empty"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Shopping"].tap()
        XCTAssertTrue(app.staticTexts["Nothing to buy"].waitForExistence(timeout: 10))

        // The hint goes away as soon as there is something in the list.
        let field = app.textFields["shopping.addField"]
        type("Milk\n", into: field, in: app)
        XCTAssertTrue(app.buttons["shopping.tick.Milk"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Nothing to buy"].exists)
    }

    @MainActor
    func test_addRecipe_pantry_shoppingList_flow() throws {
        let app = launch()
        _ = signUp(app)

        addRecipe(app, title: "UITest Soup", ingredients: ["Carrot", "Onion"], instructions: "Chop and boil.")
        XCTAssertTrue(app.staticTexts["UITest Soup"].waitForExistence(timeout: 15), "New recipe should appear")

        app.staticTexts["UITest Soup"].tap()
        let carrotPantry = app.buttons["detail.pantry.Carrot"]
        XCTAssertTrue(carrotPantry.waitForExistence(timeout: 10))
        XCTAssertEqual(carrotPantry.label, "Not in pantry")

        // Pantry toggle from the recipe updates the badge.
        carrotPantry.tap()
        XCTAssertTrue(waitForLabel(carrotPantry, "In pantry"), "Tapping the fridge should put Carrot in the pantry")

        // "Add All" puts what's missing (Onion, not Carrot) on the shopping list.
        app.buttons["detail.addAll"].tap()
        XCTAssertTrue(waitForLabel(app.buttons["detail.cart.Onion"], "On shopping list"))

        goBack(app)
        app.tabBars.buttons["Shopping"].tap()
        let tick = app.buttons["shopping.tick.Onion"]
        XCTAssertTrue(tick.waitForExistence(timeout: 10), "Onion should be on the shopping list")
        XCTAssertFalse(app.buttons["shopping.tick.Carrot"].exists, "Carrot is already in the pantry")

        // Ticking an item moves it to the pantry.
        tick.tap()
        XCTAssertTrue(waitForDisappearance(of: tick), "Ticked item should leave the shopping list")
        app.tabBars.buttons["Pantry"].tap()
        XCTAssertTrue(app.staticTexts["Onion"].waitForExistence(timeout: 10), "Ticked item should be in the pantry")
        XCTAssertTrue(app.staticTexts["Carrot"].exists)
    }

    @MainActor
    func test_quantities_servings_and_shoppingListMerge() throws {
        let app = launch()
        _ = signUp(app)
        addRecipe(
            app, title: "Pancakes", ingredients: ["200g flour", "2 eggs"], instructions: "Whisk and fry.", servings: 4)
        XCTAssertTrue(app.staticTexts["Pancakes"].waitForExistence(timeout: 15))

        // Amounts are parsed on entry and shown formatted.
        app.staticTexts["Pancakes"].tap()
        XCTAssertTrue(app.staticTexts["200 g flour"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["2 eggs"].exists)

        // Scaling the servings (4 → 8) doubles every amount.
        XCTAssertTrue(app.steppers["detail.servings"].waitForExistence(timeout: 5))
        let increment = app.buttons["detail.servings-Increment"]
        for _ in 0..<4 { increment.tap() }
        XCTAssertTrue(app.staticTexts["400 g flour"].waitForExistence(timeout: 5), "Amounts should scale with servings")
        XCTAssertTrue(app.staticTexts["4 eggs"].exists)

        // The scaled amounts go onto the shopping list.
        app.buttons["detail.addAll"].tap()
        goBack(app)
        app.tabBars.buttons["Shopping"].tap()
        XCTAssertTrue(app.staticTexts["400 g flour"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["4 eggs"].exists)

        // Typing the same ingredient again merges the amounts (same unit: sum).
        let field = app.textFields["shopping.addField"]
        type("100g flour\n", into: field, in: app)
        XCTAssertTrue(
            app.staticTexts["500 g flour"].waitForExistence(timeout: 10), "Same-unit amounts should be summed")
        XCTAssertFalse(app.staticTexts["400 g flour"].exists)

        // A different, non-convertible unit is kept as a note instead.
        type("1 cup flour\n", into: field, in: app)
        XCTAssertTrue(app.staticTexts["+ 1 cup"].waitForExistence(timeout: 10), "Other units should append a note")
        XCTAssertTrue(app.staticTexts["500 g flour"].exists)
    }

    @MainActor
    func test_searchFindsRecipesByTitleOrIngredient() throws {
        let app = launch()
        _ = signUp(app)
        addRecipe(app, title: "Carrot Soup", ingredients: ["Carrot", "Onion"], instructions: "Boil.")
        XCTAssertTrue(app.staticTexts["Carrot Soup"].waitForExistence(timeout: 15))
        addRecipe(app, title: "Plain Rice", ingredients: ["Rice"], instructions: "Steam.")
        XCTAssertTrue(app.staticTexts["Plain Rice"].waitForExistence(timeout: 15))

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        type("onion", into: search, in: app)  // an ingredient of the soup only
        XCTAssertTrue(app.staticTexts["Carrot Soup"].waitForExistence(timeout: 5))
        XCTAssertTrue(waitForDisappearance(of: app.staticTexts["Plain Rice"]), "Non-matching recipes are hidden")

        let clear = search.buttons["Clear text"]
        if clear.exists { clear.tap() }
        type("zzz", into: search, in: app)
        XCTAssertTrue(app.staticTexts["No recipes match “zzz”."].waitForExistence(timeout: 5))
    }

    @MainActor
    func test_shoppingListCanBeGroupedByAisle() throws {
        let app = launch()
        _ = signUp(app)
        app.tabBars.buttons["Shopping"].tap()
        let field = app.textFields["shopping.addField"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        type("Milk\n", into: field, in: app)
        XCTAssertTrue(app.buttons["shopping.tick.Milk"].waitForExistence(timeout: 10))
        type("Carrots\n", into: field, in: app)
        XCTAssertTrue(app.buttons["shopping.tick.Carrots"].waitForExistence(timeout: 10))

        app.buttons["shopping.sort"].tap()
        app.buttons["Group by aisle"].tap()
        XCTAssertTrue(app.staticTexts["Produce"].waitForExistence(timeout: 5), "Carrots belong under Produce")
        XCTAssertTrue(app.staticTexts["Dairy & Eggs"].exists, "Milk belongs under Dairy & Eggs")
        XCTAssertLessThan(
            app.staticTexts["Produce"].frame.minY, app.staticTexts["Dairy & Eggs"].frame.minY,
            "Aisles are in walking order")
    }

    @MainActor
    func test_ingredientNamesAreSuggestedWhileTyping() throws {
        let app = launch()
        _ = signUp(app)
        addRecipe(app, title: "Carrot Soup", ingredients: ["Carrots"], instructions: "Boil.")
        XCTAssertTrue(app.staticTexts["Carrot Soup"].waitForExistence(timeout: 15))

        app.tabBars.buttons["Shopping"].tap()
        let field = app.textFields["shopping.addField"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        type("Car", into: field, in: app)
        let suggestion = app.buttons["suggestion.Carrots"]
        XCTAssertTrue(suggestion.waitForExistence(timeout: 5), "A known ingredient should be suggested")
        suggestion.tap()
        XCTAssertTrue(app.buttons["shopping.tick.Carrots"].waitForExistence(timeout: 10), "Picking it adds the item")
    }

    @MainActor
    func test_sortMenuReordersRecipes() throws {
        let app = launch()
        _ = signUp(app)
        addRecipe(app, title: "Zebra Cake", ingredients: ["Flour"], instructions: "Bake.")
        XCTAssertTrue(app.staticTexts["Zebra Cake"].waitForExistence(timeout: 15))
        addRecipe(app, title: "Apple Pie", ingredients: ["Apples"], instructions: "Bake.")
        XCTAssertTrue(app.staticTexts["Apple Pie"].waitForExistence(timeout: 15))

        func chooseSort(_ title: String) {
            app.buttons["recipes.sort"].tap()
            app.buttons[title].tap()
        }
        func isAbove(_ first: String, _ second: String) -> Bool {
            app.staticTexts[first].frame.minY < app.staticTexts[second].frame.minY
        }

        chooseSort("Name")
        XCTAssertTrue(isAbove("Apple Pie", "Zebra Cake"), "Name sort is A to Z")

        // Put Zebra Cake's only ingredient in the pantry: it becomes cookable now, so it should lead.
        app.tabBars.buttons["Pantry"].tap()
        type("Flour\n", into: app.textFields["pantry.addField"], in: app)
        XCTAssertTrue(app.buttons["pantry.delete.Flour"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Recipes"].tap()
        chooseSort("Pantry match")
        XCTAssertTrue(isAbove("Zebra Cake", "Apple Pie"), "Pantry match puts the cookable recipe first")
    }

    @MainActor
    func test_editAndDeleteRecipe() throws {
        let app = launch()
        _ = signUp(app)
        addRecipe(app, title: "Draft Pasta", ingredients: ["Pasta"], instructions: "Boil.")
        XCTAssertTrue(app.staticTexts["Draft Pasta"].waitForExistence(timeout: 15))

        app.staticTexts["Draft Pasta"].tap()
        app.buttons["Recipe options"].tap()
        app.buttons["Edit"].tap()
        let title = app.textFields["detail.edit.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        // Typing inserts at the caret, so don't depend on where it lands: just look for the marker.
        type("-edited", into: title, in: app)
        app.buttons["detail.edit.save"].tap()
        goBack(app)
        let edited = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '-edited'")).firstMatch
        if !edited.waitForExistence(timeout: 15) { add(XCTAttachment(string: app.debugDescription)) }
        XCTAssertTrue(edited.exists, "Edited title should show in the list")

        edited.tap()
        app.buttons["Recipe options"].tap()
        app.buttons["Delete Recipe"].tap()
        app.buttons["Delete Recipe"].tap()  // confirmation dialog
        XCTAssertTrue(app.tabBars.buttons["Recipes"].waitForExistence(timeout: 10))
        XCTAssertTrue(waitForDisappearance(of: edited), "Deleted recipe should leave the list")
    }

    @MainActor
    func test_sharedRecipeIsVisibleToAnotherUser() throws {
        let owner = launch()
        _ = signUp(owner, displayName: "Alice Baker")
        addRecipe(owner, title: "Shared Curry", ingredients: ["Rice"], instructions: "Simmer.")
        XCTAssertTrue(owner.staticTexts["Shared Curry"].waitForExistence(timeout: 15))
        owner.staticTexts["Shared Curry"].tap()
        owner.buttons["Recipe options"].tap()
        owner.buttons["Share"].tap()
        goBack(owner)

        logOut(owner)
        _ = signUp(owner)  // a second, different account
        owner.tabBars.buttons["Recipes"].tap()
        owner.buttons["Shared"].tap()
        XCTAssertTrue(
            owner.staticTexts["Shared Curry"].waitForExistence(timeout: 15), "Another user should see the shared recipe"
        )
    }

    @MainActor
    func test_deleteAccount_removesTheAccountAndItsData() throws {
        let app = launch()
        let credentials = signUp(app)
        addRecipe(app, title: "Doomed Stew", ingredients: ["Beef"], instructions: "Stew.")
        XCTAssertTrue(app.staticTexts["Doomed Stew"].waitForExistence(timeout: 15))
        app.staticTexts["Doomed Stew"].tap()
        app.buttons["Recipe options"].tap()
        app.buttons["Share"].tap()
        goBack(app)
        let sharedBefore = try sharedRecipeCountInEmulator()
        XCTAssertGreaterThanOrEqual(sharedBefore, 1, "The shared recipe should be in Firestore")

        app.buttons["tabs.account"].tap()
        app.buttons["account.delete"].tap()
        app.buttons["Continue"].tap()
        let passwordField = app.secureTextFields["account.deletePassword"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5))
        passwordField.tap()
        passwordField.typeText(credentials.password)
        app.buttons["account.deleteConfirm"].tap()

        XCTAssertTrue(app.staticTexts["login.title"].waitForExistence(timeout: 20), "Should return to the login screen")
        XCTAssertEqual(try sharedRecipeCountInEmulator(), sharedBefore - 1, "The account's recipes should be deleted")

        // The account is gone: logging in fails.
        let email = app.textFields["login.email"]
        type(credentials.email, into: email, in: app)
        type(credentials.password, into: app.secureTextFields["login.password"], in: app)
        app.buttons["login.submit"].tap()
        XCTAssertTrue(app.staticTexts["login.error"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.staticTexts["login.error"].label, AuthFailureText.invalidCredentials)
    }

    // MARK: - Flows

    private enum AuthFailureText {
        static let invalidCredentials = "That email and password don't match an account."
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-use-firebase-emulator", "-uitest-signed-out"]
        app.launch()
        return app
    }

    /// Signs up a brand-new random user from the login screen and waits for the signed-in tab bar.
    @MainActor
    private func signUp(_ app: XCUIApplication, displayName: String? = nil) -> (email: String, password: String) {
        let email = "ui-\(UUID().uuidString.prefix(8).lowercased())@example.com"
        XCTAssertTrue(app.staticTexts["login.title"].waitForExistence(timeout: 15))
        app.buttons["login.signupLink"].tap()
        XCTAssertTrue(app.staticTexts["signup.title"].waitForExistence(timeout: 5))
        if let displayName { type(displayName, into: app.textFields["signup.displayName"], in: app) }
        type(email, into: app.textFields["signup.email"], in: app)
        type(password, into: app.secureTextFields["signup.password"], in: app)
        type(password, into: app.secureTextFields["signup.confirmPassword"], in: app)
        app.buttons["signup.submit"].tap()
        dismissPasswordPrompt(in: app)
        XCTAssertTrue(app.tabBars.buttons["Recipes"].waitForExistence(timeout: 30), "Sign-up should sign the user in")
        dismissPasswordPrompt(in: app)
        return (email, password)
    }

    @MainActor
    private func logOut(_ app: XCUIApplication) {
        app.buttons["tabs.account"].tap()
        app.buttons["account.logout"].tap()
        // The confirmation dialog's button shares its label with the row that opened it.
        app.buttons.matching(NSPredicate(format: "label == 'Log Out' AND identifier != 'account.logout'")).firstMatch
            .tap()
        XCTAssertTrue(app.staticTexts["login.title"].waitForExistence(timeout: 15))
    }

    @MainActor
    private func addRecipe(
        _ app: XCUIApplication, title: String, ingredients: [String], instructions: String, servings: Int = 0
    ) {
        app.buttons["recipes.add"].tap()
        let titleField = app.textFields["addRecipe.title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 10))
        type(title, into: titleField, in: app)
        let ingredientField = app.textFields["addRecipe.ingredientField"]
        for name in ingredients {
            type(name + "\n", into: ingredientField, in: app)
        }
        if servings > 0 {
            let increment = app.steppers["Servings"].buttons["Increment"]
            for _ in 0..<servings { increment.tap() }
        }
        let instructionsField = app.textViews["addRecipe.instructions"]
        instructionsField.tap()
        instructionsField.typeText(instructions)
        app.buttons["addRecipe.submit"].tap()
    }

    // MARK: - Helpers

    @MainActor
    private func type(_ text: String, into field: XCUIElement, in app: XCUIApplication) {
        // iOS offers a strong password for new-password fields and swallows typing until it is dismissed.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let closers = [app.buttons["xmark"], springboard.buttons["xmark"]]
        let focused = NSPredicate(format: "hasKeyboardFocus == true")

        // Tap until the field itself reports keyboard focus (a tap can be lost while the screen settles).
        for _ in 0..<6 {
            field.tap()
            if let closer = closers.first(where: { $0.waitForExistence(timeout: 0.5) }) { closer.tap() }
            let expectation = XCTNSPredicateExpectation(predicate: focused, object: field)
            if XCTWaiter().wait(for: [expectation], timeout: 3) == .completed { break }
        }
        field.typeText(text)
        // Typing is occasionally lost while a system overlay is up; if the field still shows its placeholder, retry.
        // (Text ending in a return is submitted and the field clears itself, so it can't be checked this way.)
        if !text.hasSuffix("\n"), (field.value as? String) == field.placeholderValue {
            field.tap()
            field.typeText(text)
        }
    }

    @MainActor
    private func dismissPasswordPrompt(in app: XCUIApplication) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deadline = Date().addingTimeInterval(4)
        while Date() < deadline {
            for candidate in [app.buttons["Not Now"], springboard.buttons["Not Now"]] where candidate.exists {
                candidate.tap()
                return
            }
            usleep(300_000)
        }
    }

    /// Leaves the recipe detail: the nav bar's back button, or the interactive edge swipe.
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

    private func waitForLabel(_ element: XCUIElement, _ label: String, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate(format: "label == %@", label)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForDisappearance(of element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Counts shared recipes across all users straight from the Firestore emulator's REST API (admin bypass).
    private func sharedRecipeCountInEmulator() throws -> Int {
        let url = try XCTUnwrap(
            URL(string: "http://127.0.0.1:8080/v1/projects/demo-foodplanner/databases/(default)/documents:runQuery"))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer owner", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let query: [String: Any] = [
            "structuredQuery": [
                "from": [["collectionId": "Recipes", "allDescendants": true]],
                "where": [
                    "fieldFilter": [
                        "field": ["fieldPath": "IsShared"], "op": "EQUAL", "value": ["booleanValue": true],
                    ]
                ],
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: query)

        var count = 0
        var failure: Error?
        let done = expectation(description: "emulator query")
        URLSession.shared.dataTask(with: request) { data, _, error in
            defer { done.fulfill() }
            if let error { failure = error }
            guard let data, let rows = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else {
                return
            }
            count = rows.filter { $0["document"] != nil }.count
        }.resume()
        wait(for: [done], timeout: 10)
        if let failure { throw failure }
        return count
    }
}
