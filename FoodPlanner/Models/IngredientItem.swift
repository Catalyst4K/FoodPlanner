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
    /// Extra amounts that couldn't be merged into `quantity` (shopping list only), e.g. "+ 1 cup".
    var note: String?

    /// This ingredient with its amount multiplied by `factor` (no amount stays no amount).
    func scaled(by factor: Double) -> IngredientItem {
        var copy = self
        copy.quantity = quantity.map { $0 * factor }
        return copy
    }
}
