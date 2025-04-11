//
//  PantryItem.swift
//  FoodPlanner
//
//  Created by Callum Jones on 11/04/2025.
//
import Foundation

struct PantryItem: Identifiable {
    var id = UUID()
    var ingredient: IngredientItem
    var isUsed: Bool = false // Whether it's used or still available
}
