//
//  NewRecipie.swift
//  FoodPlanner
//
//  Created by Callum Jones on 07/05/2025.
//

import Foundation

struct Recipe: Identifiable {
    var id: String
    var title: String
    var ingredients: [IngredientItem]
    var instructions: String
    var ownerId: String = ""      // Set by DataManager on write
    var isShared: Bool = false
}
