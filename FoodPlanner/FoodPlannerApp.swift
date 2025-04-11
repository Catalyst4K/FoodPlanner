//
//  FoodPlannerApp.swift
//  FoodPlanner
//
//  Created by Callum Jones on 10/04/2025.
//

import SwiftUI

@main
struct FoodPlannerApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
