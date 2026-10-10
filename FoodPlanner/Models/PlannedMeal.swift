import Foundation

/// When in the day a meal is planned. Raw values are stored in Firestore, so don't rename them.
enum MealSlot: String, CaseIterable, Identifiable, Comparable {
    case breakfast, lunch, dinner, snack

    var id: String { rawValue }

    var title: String {
        switch self {
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .dinner: "Dinner"
        case .snack: "Snack"
        }
    }

    /// Display order within a day.
    private var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }
    static func < (lhs: MealSlot, rhs: MealSlot) -> Bool { lhs.order < rhs.order }
}

/// One recipe planned for one slot of one day.
struct PlannedMeal: Identifiable, Equatable {
    var id: String
    var recipeId: String
    /// Denormalised so a deleted recipe still shows something sensible.
    var recipeName: String
    var slot: MealSlot
    /// Servings to cook; nil means "as the recipe is written".
    var servings: Int?
}
