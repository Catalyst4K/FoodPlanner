import FirebaseAuth
import FirebaseFirestore
import Foundation
import Testing

@testable import FoodPlanner

/// `DataManager` against the Auth and Firestore emulators, with the real `firestore.rules` enforced (so a write
/// the rules would refuse fails here too). Skipped unless `FIREBASE_EMULATOR=1`; run with
/// `make test-integration`, which starts the emulators. Never touches production: the emulators serve the
/// `demo-foodplanner` project.
@Suite(
    "DataManager (emulator)",
    .serialized,
    .enabled(if: ProcessInfo.processInfo.environment["FIREBASE_EMULATOR"] == "1")
)
@MainActor
struct DataManagerIntegrationTests {
    private static var emulatorConfigured = false

    /// Points Auth and Firestore at the emulators once, before the first Firestore use in this process.
    private static func configureEmulators() {
        guard !emulatorConfigured else { return }
        emulatorConfigured = true
        Auth.auth().useEmulator(withHost: "127.0.0.1", port: 9099)
        let settings = Firestore.firestore().settings
        settings.host = "127.0.0.1:8080"
        settings.isSSLEnabled = false
        settings.cacheSettings = MemoryCacheSettings()
        Firestore.firestore().settings = settings
    }

    private struct TestUser {
        let uid: String
        let email: String
        let password: String
    }

    /// Creates and signs in a brand-new user, so tests never see each other's data. There is one Auth session
    /// per process: creating (or signing in) another user signs the previous one out.
    private func makeUser() async throws -> TestUser {
        Self.configureEmulators()
        let email = "it-\(UUID().uuidString.prefix(8).lowercased())@example.com"
        let password = "Sup3r-secret-\(UUID().uuidString.prefix(6))"
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        return TestUser(uid: result.user.uid, email: email, password: password)
    }

    private func makeManager(name: String = "Tester") async throws -> DataManager {
        let user = try await makeUser()
        return DataManager(userId: user.uid, ownerDisplayName: { name })
    }

    /// Polls until `condition` holds (listeners deliver asynchronously) or fails after `timeout` seconds.
    private func eventually(
        _ what: String, timeout: Double = 10, sourceLocation: SourceLocation = #_sourceLocation,
        _ condition: () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline { try? await Task.sleep(for: .milliseconds(50)) }
        #expect(condition(), "Timed out waiting for \(what)", sourceLocation: sourceLocation)
    }

    private func ingredient(_ name: String, _ quantity: Double? = nil, _ unit: String? = nil) -> IngredientItem {
        IngredientItem(id: "", name: name, quantity: quantity, unit: unit)
    }

    private func recipe(_ title: String, _ ingredients: [IngredientItem], servings: Int? = nil) -> Recipe {
        Recipe(id: "", title: title, ingredients: ingredients, instructions: "Cook it.", servings: servings)
    }

    // MARK: - Recipes

    @Test func recipeRoundTripsThroughAddUpdateAndDelete() async throws {
        let manager = try await makeManager()
        let pasta = recipe("Creamy Rigatoni", [ingredient("Rigatoni", 400, "g"), ingredient("Cream")], servings: 4)
        #expect(await manager.addRecipe(recipe: pasta))
        await eventually("the recipe to arrive") { manager.userRecipes.count == 1 }

        let saved = try #require(manager.userRecipes.first)
        #expect(saved.title == "Creamy Rigatoni")
        #expect(saved.servings == 4)
        #expect(saved.ingredients.map(\.name) == ["Rigatoni", "Cream"])
        #expect(saved.ingredients.first?.quantity == 400)
        #expect(saved.ingredients.first?.unit == "g")
        #expect(saved.ownerId == manager.currentUserId)
        #expect(!saved.isShared)

        var edited = saved
        edited.title = "Creamy Courgette Rigatoni"
        edited.ingredients.append(ingredient("Courgette"))
        #expect(await manager.updateRecipe(recipeId: saved.id, recipe: edited))
        await eventually("the edit to arrive") { manager.userRecipes.first?.ingredients.count == 3 }
        #expect(manager.userRecipes.first?.title == "Creamy Courgette Rigatoni")

        #expect(await manager.deleteRecipe(recipeId: saved.id))
        await eventually("the recipe to disappear") { manager.userRecipes.isEmpty }
        #expect(manager.errorMessage == nil)
    }

    @Test func sharedRecipesReachOtherUsersWithTheOwnerNameUntilUnshared() async throws {
        let ownerUser = try await makeUser()
        let owner = DataManager(userId: ownerUser.uid, ownerDisplayName: { "  Sam  " })
        await owner.addRecipe(recipe: recipe("Shared Soup", [ingredient("Leek")]))
        await eventually("the recipe to arrive") { owner.userRecipes.count == 1 }
        let id = try #require(owner.userRecipes.first?.id)
        #expect(await owner.setShared(recipeId: id, isShared: true))
        await eventually("sharing to show") { owner.userRecipes.first?.isShared == true }
        #expect(owner.userRecipes.first?.ownerName == "Sam")
        #expect(!owner.sharedRecipes.contains { $0.id == id }, "Your own recipes aren't listed as shared")

        // Another user signs in and sees it, with the owner's name.
        let reader = try await makeManager(name: "Alex")
        await eventually("the other user to see it") { reader.sharedRecipes.contains { $0.id == id } }
        #expect(reader.sharedRecipes.first { $0.id == id }?.ownerName == "Sam")

        // The owner signs back in and unshares; the reader's live list drops it.
        try await Auth.auth().signIn(withEmail: ownerUser.email, password: ownerUser.password)
        let ownerAgain = DataManager(userId: ownerUser.uid, ownerDisplayName: { "Sam" })
        await eventually("the owner's recipe") { ownerAgain.userRecipes.count == 1 }
        #expect(await ownerAgain.setShared(recipeId: id, isShared: false))
        await eventually("unsharing to show") { ownerAgain.userRecipes.first?.isShared == false }
        #expect(ownerAgain.userRecipes.first?.ownerName == nil)
        await eventually("the other user to lose it") { !reader.sharedRecipes.contains { $0.id == id } }
        #expect(ownerAgain.errorMessage == nil)
    }

    // MARK: - Pantry and shopping list

    @Test func addingTheSameIngredientTwiceKeepsOneDocument() async throws {
        let manager = try await makeManager()
        #expect(await manager.addToPantry(name: "Olive Oil"))
        #expect(await manager.addToPantry(name: "olive  oil "))
        await eventually("the pantry item") { !manager.pantryIngredients.isEmpty }
        try? await Task.sleep(for: .milliseconds(300))
        #expect(manager.pantryIngredients.count == 1)
        #expect(manager.pantryIngredients.first?.id == IngredientKey.documentID(for: "Olive Oil"))
    }

    @Test func shoppingListMergesQuantities() async throws {
        let manager = try await makeManager()
        #expect(await manager.addToShoppingList(name: "Flour", quantity: 200, unit: "g"))
        await eventually("the first amount") { manager.shoppingListIngredients.first?.quantity == 200 }
        #expect(await manager.addToShoppingList(name: "flour", quantity: 300, unit: "g"))
        await eventually("the merged amount") { manager.shoppingListIngredients.first?.quantity == 500 }
        #expect(manager.shoppingListIngredients.count == 1)
        #expect(manager.shoppingListIngredients.first?.unit == "g")
    }

    @Test func movingAShoppingItemToThePantryIsOneStep() async throws {
        let manager = try await makeManager()
        await manager.addToShoppingList(name: "Eggs", quantity: 6)
        await eventually("the list item") { manager.shoppingListIngredients.count == 1 }
        let item = try #require(manager.shoppingListIngredients.first)

        #expect(await manager.moveShoppingItemToPantry(item))
        await eventually("the move") { manager.shoppingListIngredients.isEmpty && manager.pantryIngredients.count == 1 }
        #expect(manager.pantryIngredients.first?.name == "Eggs")
    }

    @Test func addMissingIngredientsSkipsWhatYouAlreadyHaveOrListed() async throws {
        let manager = try await makeManager()
        await manager.addToPantry(name: "Rigatoni")
        await manager.addToShoppingList(name: "Cream")
        await eventually("setup") { manager.pantryIngredients.count == 1 && manager.shoppingListIngredients.count == 1 }

        let dish = recipe("Creamy Rigatoni", [ingredient("Rigatoni"), ingredient("Cream"), ingredient("Courgette", 2)])
        #expect(await manager.addMissingIngredientsToShoppingList(from: dish))
        await eventually("the missing item") { manager.shoppingListIngredients.count == 2 }
        #expect(Set(manager.shoppingListIngredients.map(\.name)) == ["Cream", "Courgette"])
    }

    @Test func batchWritesAddEveryItemOrNone() async throws {
        let manager = try await makeManager()
        let items = [ingredient("Carrot", 3), ingredient("Onion", 1), ingredient("Stock", 500, "ml")]
        #expect(await manager.addToShoppingList(items: items))
        await eventually("the batch") { manager.shoppingListIngredients.count == 3 }
        #expect(manager.shoppingListIngredients.first { $0.name == "Stock" }?.unit == "ml")
    }

    // MARK: - Meal plan

    @Test func mealPlanAddMoveRemoveAndClear() async throws {
        let manager = try await makeManager()
        await manager.addRecipe(recipe: recipe("Planned Pie", [ingredient("Pastry")]))
        await eventually("the recipe") { manager.userRecipes.count == 1 }
        let pie = try #require(manager.userRecipes.first)

        let monday = manager.planWeekStart
        let tuesday = try #require(PlanDate.calendar.date(byAdding: .day, value: 1, to: monday))
        let mondayKey = PlanDate.key(for: monday)
        let tuesdayKey = PlanDate.key(for: tuesday)

        #expect(await manager.addMeal(recipe: pie, on: monday, slot: .dinner, servings: 2))
        await eventually("the meal") { manager.mealPlan[mondayKey]?.count == 1 }
        let meal = try #require(manager.mealPlan[mondayKey]?.first)
        #expect(meal.recipeName == "Planned Pie")
        #expect(meal.servings == 2)
        #expect(meal.slot == .dinner)

        #expect(await manager.moveMeal(meal, from: monday, to: tuesday, slot: .lunch))
        await eventually("the move") { manager.mealPlan[tuesdayKey]?.count == 1 && manager.mealPlan[mondayKey] == nil }
        #expect(manager.mealPlan[tuesdayKey]?.first?.slot == .lunch)

        let moved = try #require(manager.mealPlan[tuesdayKey]?.first)
        #expect(await manager.removeMeal(moved, on: tuesday))
        await eventually("the removal") { manager.mealPlan[tuesdayKey]?.isEmpty ?? true }

        await manager.addMeal(recipe: pie, on: monday, slot: .breakfast)
        await manager.addMeal(recipe: pie, on: tuesday, slot: .snack)
        await eventually("two meals") { manager.mealPlan.values.map(\.count).reduce(0, +) == 2 }
        #expect(await manager.clearPlanWeek())
        await eventually("an empty week") { manager.mealPlan.isEmpty }
        #expect(manager.errorMessage == nil)
    }

    @Test func browsingToAnotherWeekLoadsThatWeeksPlan() async throws {
        let manager = try await makeManager()
        await manager.addRecipe(recipe: recipe("Later Lasagne", [ingredient("Pasta")]))
        await eventually("the recipe") { manager.userRecipes.count == 1 }
        let lasagne = try #require(manager.userRecipes.first)

        let nextWeek = PlanDate.shifted(manager.planWeekStart, byWeeks: 1)
        await manager.addMeal(recipe: lasagne, on: nextWeek, slot: .dinner)
        try? await Task.sleep(for: .milliseconds(300))
        #expect(manager.mealPlan.isEmpty, "The visible week doesn't include next week's meal")

        manager.showPlanWeek(containing: nextWeek)
        await eventually("next week's meal") { manager.mealPlan[PlanDate.key(for: nextWeek)]?.count == 1 }
        #expect(manager.planWeekStart == PlanDate.startOfWeek(containing: nextWeek))
    }

    // MARK: - Account deletion

    @Test func deletingAllUserDataEmptiesEveryCollection() async throws {
        let manager = try await makeManager()
        await manager.addRecipe(recipe: recipe("Doomed Dish", [ingredient("Salt")]))
        await manager.addToPantry(name: "Pepper")
        await manager.addToShoppingList(name: "Butter")
        await eventually("setup") {
            manager.userRecipes.count == 1 && manager.pantryIngredients.count == 1
                && manager.shoppingListIngredients.count == 1
        }
        let dish = try #require(manager.userRecipes.first)
        await manager.addMeal(recipe: dish, on: manager.planWeekStart, slot: .dinner)
        await eventually("the meal") { !manager.mealPlan.isEmpty }

        #expect(await manager.deleteAllUserData())
        await eventually("everything gone") {
            manager.userRecipes.isEmpty && manager.pantryIngredients.isEmpty
                && manager.shoppingListIngredients.isEmpty && manager.mealPlan.isEmpty
        }
    }
}
