import Foundation

struct Recipe: Identifiable {
    var id: String
    var title: String
    var ingredients: [IngredientItem]
    var instructions: String
    var ownerId: String = ""      // Set by DataManager on write
    var isShared: Bool = false
}
