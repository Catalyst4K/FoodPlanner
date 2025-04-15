//
//  UserItem.swift
//  FoodPlanner
//
//  Created by Callum Jones on 14/04/2025.
//

struct AppUser: Identifiable, Codable {
    var id: String
    var email: String
    var displayName: String
}
