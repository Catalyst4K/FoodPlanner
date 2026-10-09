import Testing

@testable import FoodPlanner

@Suite("AppInfo")
struct AppInfoTests {
    @Test func versionAndBuildAreCombined() {
        let info: [String: Any] = ["CFBundleShortVersionString": "1.2.0", "CFBundleVersion": "7"]
        #expect(AppInfo.versionDescription(from: info) == "1.2.0 (7)")
    }

    @Test func identicalVersionAndBuildAreNotRepeated() {
        let info: [String: Any] = ["CFBundleShortVersionString": "1.0", "CFBundleVersion": "1.0"]
        #expect(AppInfo.versionDescription(from: info) == "1.0")
    }

    @Test func missingKeysFallBackGracefully() {
        #expect(AppInfo.versionDescription(from: ["CFBundleShortVersionString": "2.0"]) == "2.0")
        #expect(AppInfo.versionDescription(from: ["CFBundleVersion": "9"]) == "build 9")
        #expect(AppInfo.versionDescription(from: [:]) == "unknown")
        #expect(AppInfo.versionDescription(from: nil) == "unknown")
    }

    @Test func privacyPolicyLinkIsAValidHTTPSURL() {
        #expect(AppLinks.privacyPolicy?.scheme == "https")
    }

    @Test func currentVersionComesFromTheMainBundle() {
        #expect(!AppInfo.currentVersionDescription.isEmpty)
    }
}
