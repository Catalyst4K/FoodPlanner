import Testing

@testable import FoodPlanner

@Suite("FirestoreMapping")
struct FirestoreMappingTests {
    private func ingredient(_ name: String, _ quantity: Double? = nil, _ unit: String? = nil) -> IngredientItem {
        IngredientItem(id: IngredientKey.documentID(for: name), name: name, quantity: quantity, unit: unit)
    }

    private func recipe(_ ingredients: [IngredientItem]) -> Recipe {
        Recipe(id: "r1", title: "Pancakes", ingredients: ingredients, instructions: "Mix and fry.", ownerId: "u1")
    }

    // MARK: - Recipes

    @Test func recipeRoundTripsWithAndWithoutQuantityAndUnit() throws {
        let original = recipe([ingredient("Flour", 150, "g"), ingredient("Eggs", 2), ingredient("Salt")])
        let data = FirestoreMapping.recipeFields(original)
        let parsed = try #require(FirestoreMapping.recipe(from: data, id: "r1", fallbackOwnerId: "u1"))

        #expect(parsed.title == "Pancakes")
        #expect(parsed.instructions == "Mix and fry.")
        #expect(parsed.ingredients.map(\.name) == ["Flour", "Eggs", "Salt"])
        #expect(parsed.ingredients.map(\.quantity) == [150, 2, nil])
        #expect(parsed.ingredients.map(\.unit) == ["g", nil, nil])
    }

    @Test func ingredientOrderIsPreserved() throws {
        let names = ["Zucchini", "Apple", "Milk", "Butter", "Cheese"]
        let data = FirestoreMapping.recipeFields(recipe(names.map { ingredient($0) }))
        let parsed = try #require(FirestoreMapping.recipe(from: data, id: "r1", fallbackOwnerId: "u1"))
        #expect(parsed.ingredients.map(\.name) == names)
    }

    @Test func recipeIngredientIDsAreNormalisedKeys() throws {
        let data = FirestoreMapping.recipeFields(recipe([ingredient("Jalapeño")]))
        let parsed = try #require(FirestoreMapping.recipe(from: data, id: "r1", fallbackOwnerId: "u1"))
        #expect(parsed.ingredients[0].id == "jalapeno")
    }

    @Test func recipeFieldsExcludeOwnershipSharingAndTimestamps() {
        let fields = FirestoreMapping.recipeFields(recipe([ingredient("Flour")]))
        #expect(Set(fields.keys) == ["Name", "Instructions", "Ingredients"])
    }

    @Test func emptyUnitIsOmittedWhenWriting() throws {
        let fields = FirestoreMapping.recipeFields(recipe([ingredient("Flour", 1, "")]))
        let entries = try #require(fields["Ingredients"] as? [[String: Any]])
        #expect(entries[0]["Unit"] == nil)
        #expect(entries[0]["Quantity"] as? Double == 1)
    }

    @Test func servingsRoundTrip() throws {
        var r = recipe([ingredient("Flour")])
        r.servings = 4
        let data = FirestoreMapping.recipeFields(r)
        #expect(data["Servings"] as? Int == 4)
        let parsed = try #require(FirestoreMapping.recipe(from: data, id: "r1", fallbackOwnerId: "u1"))
        #expect(parsed.servings == 4)
    }

    @Test func wholeNumberQuantitiesStoredAsIntegersAreAccepted() throws {
        let data: [String: Any] = [
            "Name": "Soup", "Instructions": "",
            "Ingredients": [["Name": "Carrot", "Quantity": 3, "Unit": "pcs"]],
        ]
        let parsed = try #require(FirestoreMapping.recipe(from: data, id: "r", fallbackOwnerId: "u"))
        #expect(parsed.ingredients[0].quantity == 3)
    }

    @Test func ownerIdFallsBackWhenAbsent() throws {
        let data: [String: Any] = ["Name": "A", "Instructions": "x", "Ingredients": [[String: Any]]()]
        let parsed = try #require(FirestoreMapping.recipe(from: data, id: "r", fallbackOwnerId: "from-path"))
        #expect(parsed.ownerId == "from-path")
        #expect(parsed.isShared == false)
    }

    @Test func storedOwnerAndSharedFlagAreRead() throws {
        let data: [String: Any] = [
            "Name": "A", "Instructions": "x", "Ingredients": [[String: Any]](), "OwnerId": "owner", "IsShared": true,
        ]
        let parsed = try #require(FirestoreMapping.recipe(from: data, id: "r", fallbackOwnerId: "other"))
        #expect(parsed.ownerId == "owner")
        #expect(parsed.isShared == true)
    }

    @Test func v1ShapedRecipeWithoutIngredientsArrayIsRejected() {
        let v1: [String: Any] = ["Name": "Old", "Instructions": "x", "OwnerId": "u", "IsShared": false]
        #expect(FirestoreMapping.recipe(from: v1, id: "r", fallbackOwnerId: "u") == nil)
    }

    @Test func malformedRecipesAreRejected() {
        let ok: [[String: Any]] = [["Name": "Flour"]]
        #expect(
            FirestoreMapping.recipe(from: ["Instructions": "x", "Ingredients": ok], id: "r", fallbackOwnerId: "u")
                == nil)
        #expect(FirestoreMapping.recipe(from: ["Name": 5, "Ingredients": ok], id: "r", fallbackOwnerId: "u") == nil)
        #expect(
            FirestoreMapping.recipe(from: ["Name": "A", "Ingredients": "flour"], id: "r", fallbackOwnerId: "u") == nil)
        #expect(
            FirestoreMapping.recipe(
                from: ["Name": "A", "Ingredients": [["Quantity": 1]]], id: "r", fallbackOwnerId: "u") == nil)
    }

    // MARK: - Pantry and shopping list

    @Test func listItemParsesNameQuantityAndUnit() throws {
        let item = try #require(
            FirestoreMapping.listItem(from: ["Name": "Milk", "Quantity": 2.0, "Unit": "l"], id: "milk"))
        #expect(item.id == "milk")
        #expect(item.name == "Milk")
        #expect(item.quantity == 2)
        #expect(item.unit == "l")
    }

    @Test func listItemWithOnlyANameIsValid() throws {
        let item = try #require(FirestoreMapping.listItem(from: ["Name": "Salt"], id: "salt"))
        #expect(item.quantity == nil)
        #expect(item.unit == nil)
    }

    @Test func v1ListDocumentWithoutANameIsRejected() {
        #expect(FirestoreMapping.listItem(from: ["CreatedAt": "x"], id: "abc") == nil)
        #expect(FirestoreMapping.listItem(from: ["Name": 3], id: "abc") == nil)
    }
}
