//
//  FoodPlannerApp.swift
//  FoodPlanner
//
//  Created by Callum Jones on 10/04/2025.
//

import SwiftUI
import Firebase

@main
struct FoodPlannerApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var authViewModel = AuthViewModel()

    init() {
        FirebaseApp.configure()
    }
    
    @ViewBuilder
    var rootView: some View {
        if authViewModel.user == nil {
            LoginView(authViewModel: authViewModel)
                .transition(.opacity)
        } else {
            MainTabView(authViewModel: authViewModel)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .transition(.opacity)
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if authViewModel.isLoading {
                    SplashScreenView()
                        .transition(.opacity)
                } else {
                    rootView
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: authViewModel.user)
        }
    }
}
