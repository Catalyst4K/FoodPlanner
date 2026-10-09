import Foundation

struct IngredientItem: Identifiable {
    var id: String
    var name: String
    var quantity: Double?
    var unit: String?

    static func from(dictionary: [String: Any], id: String) -> IngredientItem? {
        guard let name = dictionary["Name"] as? String else {
            return nil
        }

        let quantity = dictionary["Quantity"] as? Double
        let unit = dictionary["Unit"] as? String

        return IngredientItem(id: id, name: name, quantity: quantity, unit: unit)
    }
}
