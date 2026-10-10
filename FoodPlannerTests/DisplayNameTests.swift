import Testing

@testable import FoodPlanner

@Suite("DisplayName")
struct DisplayNameTests {
    @Test func cleanTrimsAndCollapsesWhitespace() {
        #expect(DisplayName.clean("  Alice \n  Baker ") == "Alice Baker")
        #expect(DisplayName.clean("   ") == "")
    }

    @Test func cleanCapsTheLength() {
        let long = String(repeating: "a", count: 80)
        #expect(DisplayName.clean(long).count == 50)
        #expect(DisplayName.clean(String(repeating: "ab ", count: 40)).count <= 50)
        #expect(!DisplayName.clean(String(repeating: "ab ", count: 40)).hasSuffix(" "))
    }

    @Test func resolvedPrefersWhatTheUserTyped() {
        #expect(DisplayName.resolved(" Alice ", email: "alice@example.com") == "Alice")
    }

    @Test func resolvedFallsBackToTheEmailPrefixThenSomeone() {
        #expect(DisplayName.resolved("", email: "callum.jones@example.com") == "callum.jones")
        #expect(DisplayName.resolved("  ", email: "x@y.com") == "x")
        #expect(DisplayName.resolved("", email: nil) == "Someone")
        #expect(DisplayName.resolved("", email: "@example.com") == "Someone")
        #expect(DisplayName.resolved("", email: "") == "Someone")
    }
}
