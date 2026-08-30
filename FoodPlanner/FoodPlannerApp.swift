//
//  FoodPlannerApp.swift
//  FoodPlanner
//
//  Created by Callum Jones on 10/04/2025.
//

import SwiftUI
import Firebase
import FirebaseAuth
import UIKit

/// UIKit shim so we can dynamically lock/unlock orientations per-screen while remaining a pure SwiftUI app.
/// Views mutate `AppDelegate.orientationLock`; UIKit consults it whenever the system asks about supported orientations.
class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock: UIInterfaceOrientationMask = .portrait

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        AppDelegate.orientationLock
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Match every window's background to systemBackground so any edge exposed during
        // rotation (before SwiftUI fills the new frame) blends in instead of showing black.
        DispatchQueue.main.async {
            for scene in UIApplication.shared.connectedScenes {
                guard let windowScene = scene as? UIWindowScene else { continue }
                for window in windowScene.windows {
                    window.backgroundColor = .systemBackground
                }
            }
        }
        return true
    }
}

extension AppDelegate {
    /// Update the allowed orientations and force the system to reevaluate immediately.
    /// Both `setNeedsUpdateOfSupportedInterfaceOrientations()` and `requestGeometryUpdate(...)` are needed:
    /// the first prompts UIKit to re-query our AppDelegate before starting any rotation animation,
    /// the second commits the new orientation without waiting for a device rotation event.
    static func setAllowedOrientations(_ mask: UIInterfaceOrientationMask) {
        orientationLock = mask
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            scene.windows.forEach { $0.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations() }
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
        }
    }
}

@main
struct FoodPlannerApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var authViewModel = AuthViewModel()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    init() {
        FirebaseApp.configure()
        #if DEBUG
        // UI test entry point: force a signed-out state so tests always start at Login.
        if ProcessInfo.processInfo.arguments.contains("-uitest-signed-out") {
            try? Auth.auth().signOut()
        }
        #endif
    }

    @ViewBuilder
    var rootView: some View {
        if let user = authViewModel.user {
            AuthenticatedRoot(authViewModel: authViewModel, userId: user.uid)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .id(user.uid) // Rebuild the DataManager if the signed-in user changes
        } else {
            LoginView(authViewModel: authViewModel)
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if authViewModel.isLoading {
                    SplashScreenView()
                } else {
                    rootView
                }
            }
            .animation(.easeInOut(duration: 0.5), value: authViewModel.user)
            .onChange(of: scenePhase) { _, newPhase in
                // Re-seed the orientation lock whenever the scene becomes active. This makes UIKit
                // adopt our current lock immediately, avoiding a brief unwanted rotation-then-snap-back
                // the first time the user tilts the device after launch.
                if newPhase == .active {
                    AppDelegate.setAllowedOrientations(AppDelegate.orientationLock)
                }
            }
        }
    }
}

/// Owns the `DataManager` for the signed-in user so we can use `@StateObject`
/// without the placeholder-user hack.
private struct AuthenticatedRoot: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var dataManager: DataManager

    init(authViewModel: AuthViewModel, userId: String) {
        self.authViewModel = authViewModel
        _dataManager = StateObject(wrappedValue: DataManager(userId: userId))
    }

    var body: some View {
        MainTabView(authViewModel: authViewModel)
            .environmentObject(dataManager)
    }
}
