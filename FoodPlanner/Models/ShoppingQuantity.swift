import Foundation

/// Combines amounts when the same ingredient is added to the shopping list again. Foundation-only.
enum ShoppingQuantity {
    struct Merged: Equatable {
        var quantity: Double?
        var unit: String?
        var note: String?
    }

    /// Merges `adding` into `existing`:
    /// - nothing to add (no amount): `existing` is unchanged;
    /// - `existing` has no amount yet: take the added amount;
    /// - same unit (or both unit-less counts): sum;
    /// - convertible units (g↔kg, ml↔l): convert the added amount to `existing`'s unit and sum;
    /// - otherwise keep `existing` and append the new amount to `note` ("+ 1 cup").
    static func merge(existing: IngredientItem, adding: IngredientItem) -> Merged {
        let unchanged = Merged(quantity: existing.quantity, unit: existing.unit, note: existing.note)
        guard let addedQuantity = adding.quantity, addedQuantity > 0 else { return unchanged }
        guard let existingQuantity = existing.quantity else {
            return Merged(quantity: addedQuantity, unit: adding.unit, note: existing.note)
        }
        if existing.unit == adding.unit {
            return Merged(quantity: existingQuantity + addedQuantity, unit: existing.unit, note: existing.note)
        }
        if let existingUnit = existing.unit, let addedUnit = adding.unit,
            let converted = IngredientUnit.convert(addedQuantity, from: addedUnit, to: existingUnit)
        {
            return Merged(quantity: existingQuantity + converted, unit: existingUnit, note: existing.note)
        }
        let extra =
            "+ "
            + IngredientFormatter.format(quantity: addedQuantity, unit: adding.unit, name: "").trimmingCharacters(
                in: .whitespaces)
        let note = [existing.note, extra].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
        return Merged(quantity: existingQuantity, unit: existing.unit, note: note)
    }
}
