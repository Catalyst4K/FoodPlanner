import Foundation

/// An ingredient in a recipe, the pantry or the shopping list.
///
/// `id` is stable and derived from the name: for pantry and shopping-list documents it is the
/// document ID, and for recipe ingredients it is `IngredientKey.documentID(for: name)`.
struct IngredientItem: Identifiable {
    var id: String
    var name: String
    var quantity: Double?
    var unit: String?
}
