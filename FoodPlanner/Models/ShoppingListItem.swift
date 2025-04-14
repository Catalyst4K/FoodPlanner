//
//  ShoppingListItem.swift
//  FoodPlanner
//
//  Created by Callum Jones on 11/04/2025.
//
import Foundation

struct ShoppingListItem: Identifiable {
    var id = UUID()
    var ingredient: IngredientItem
    var isChecked: Bool = false  // Whether it's checked off or not
}
