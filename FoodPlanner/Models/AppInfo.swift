import Foundation

/// App metadata shown on the account screen. Foundation-only so it is unit-tested.
enum AppInfo {
    /// "1.0 (3)" from an Info.plist dictionary; falls back gracefully if keys are missing.
    static func versionDescription(from info: [String: Any]?) -> String {
        let version = info?["CFBundleShortVersionString"] as? String
        let build = info?["CFBundleVersion"] as? String
        switch (version, build) {
        case let (version?, build?) where build != version: return "\(version) (\(build))"
        case let (version?, _): return version
        case let (nil, build?): return "build \(build)"
        default: return "unknown"
        }
    }

    static var currentVersionDescription: String {
        versionDescription(from: Bundle.main.infoDictionary)
    }
}

/// Links the app opens. The privacy policy URL is a placeholder until it is hosted (plan task 5.3).
enum AppLinks {
    static let privacyPolicy = URL(string: "https://catalyst4k.github.io/FoodPlanner/privacy")
}
