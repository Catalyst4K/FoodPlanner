import Foundation
import Testing

@testable import FoodPlanner

@Suite struct AcknowledgementsTests {
    @Test func bundledListLoadsWithLicenceText() {
        let items = Acknowledgement.loadBundled()
        #expect(!items.isEmpty)
        #expect(items.contains { $0.name == "firebase-ios-sdk" })
        #expect(items.allSatisfy { !$0.licenseText.isEmpty && !$0.license.isEmpty })
    }
}
