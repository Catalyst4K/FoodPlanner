import Foundation

/// Converts between Firestore document data and app models. Foundation-only (no `Timestamp` or
/// `DocumentReference`), so it is unit-tested without Firebase. Schema: docs/IMPLEMENTATION_PLAN.md, Appendix A.
enum FirestoreMapping {
    // MARK: - Recipes

    /// Parses a recipe document. Returns nil when `Name` or `Ingredients` is missing or the wrong type,
    /// which is also how v1 documents (ingredients in a subcollection) are recognised and skipped.
    static func recipe(from data: [String: Any], id: String, fallbackOwnerId: String) -> Recipe? {
        guard let title = data["Name"] as? String,
            let rawIngredients = data["Ingredients"] as? [[String: Any]]
        else { return nil }

        var ingredients: [IngredientItem] = []
        for raw in rawIngredients {
            guard let name = raw["Name"] as? String else { return nil }
            ingredients.append(
                IngredientItem(
                    id: IngredientKey.documentID(for: name),
                    name: name,
                    quantity: double(raw["Quantity"]),
                    unit: raw["Unit"] as? String
                )
            )
        }

        return Recipe(
            id: id,
            title: title,
            ingredients: ingredients,
            instructions: data["Instructions"] as? String ?? "",
            ownerId: data["OwnerId"] as? String ?? fallbackOwnerId,
            isShared: data["IsShared"] as? Bool ?? false,
            servings: int(data["Servings"])
        )
    }

    /// The fields a recipe form owns. Excludes `OwnerId`, `IsShared` and timestamps, which `DataManager` sets.
    static func recipeFields(_ recipe: Recipe) -> [String: Any] {
        var fields: [String: Any] = [
            "Name": recipe.title,
            "Instructions": recipe.instructions,
            "Ingredients": recipe.ingredients.map(ingredientFields),
        ]
        if let servings = recipe.servings { fields["Servings"] = servings }
        return fields
    }

    // MARK: - Pantry and shopping list

    /// Parses a pantry or shopping-list document. `id` is the document ID (the ingredient key).
    static func listItem(from data: [String: Any], id: String) -> IngredientItem? {
        guard let name = data["Name"] as? String else { return nil }
        return IngredientItem(
            id: id, name: name, quantity: double(data["Quantity"]), unit: data["Unit"] as? String,
            note: data["Note"] as? String)
    }

    // MARK: - Helpers

    private static func ingredientFields(_ item: IngredientItem) -> [String: Any] {
        var fields: [String: Any] = ["Name": item.name]
        if let quantity = item.quantity { fields["Quantity"] = quantity }
        if let unit = item.unit, !unit.isEmpty { fields["Unit"] = unit }
        return fields
    }

    /// Firestore hands back whole numbers as `Int` and fractions as `Double`; accept either (but not `Bool`).
    private static func double(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        return nil
    }

    private static func int(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? Double, value == value.rounded() { return Int(value) }
        return nil
    }
}
