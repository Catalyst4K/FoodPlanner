//
//  Recipe.swift
//  FoodPlanner
//
//  Created by Callum Jones on 10/04/2025.
//
// Recipe.swift
import Foundation

struct Recipe: Identifiable {
    var id = UUID()
    var title: String
    var ingredients: [IngredientItem]
    var instructions: String
}

