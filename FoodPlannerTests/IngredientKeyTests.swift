import Testing

@testable import FoodPlanner

@Suite("IngredientKey")
struct IngredientKeyTests {
    @Test func trimsAndCollapsesWhitespace() {
        #expect(IngredientKey.normalized("  Olive   Oil ") == "olive oil")
        #expect(IngredientKey.normalized("\tolive\n oil\n") == "olive oil")
    }

    @Test func isCaseInsensitive() {
        #expect(IngredientKey.normalized("OLIVE OIL") == IngredientKey.normalized("olive oil"))
    }

    @Test func foldsDiacritics() {
        #expect(IngredientKey.normalized("Jalapeño") == "jalapeno")
        #expect(IngredientKey.normalized("Crème fraîche") == "creme fraiche")
    }

    @Test func foldsFullWidthCharacters() {
        #expect(IngredientKey.normalized("ＲＩＣＥ") == "rice")
    }

    @Test func emptyAndWhitespaceOnlyNormaliseToEmpty() {
        #expect(IngredientKey.normalized("") == "")
        #expect(IngredientKey.normalized("  \n\t ") == "")
    }

    @Test func doesNotMergePlurals() {
        #expect(IngredientKey.normalized("egg") != IngredientKey.normalized("eggs"))
    }

    // MARK: - documentID

    @Test func documentIDForPlainNameIsTheNormalisedName() {
        #expect(IngredientKey.documentID(for: "  Olive   Oil ") == "olive oil")
        #expect(IngredientKey.documentID(for: "Jalapeño") == "jalapeno")
    }

    @Test func documentIDEscapesPercentAndSlash() {
        #expect(IngredientKey.documentID(for: "1/2 & 1/2") == "1%2F2 & 1%2F2")
        #expect(IngredientKey.documentID(for: "100% juice") == "100%25 juice")
        // `%` is escaped first, so an already-escaped sequence can't collide with a slash.
        #expect(IngredientKey.documentID(for: "a%2Fb") != IngredientKey.documentID(for: "a/b"))
    }

    @Test func documentIDAvoidsReservedNames() {
        #expect(IngredientKey.documentID(for: ".") == "k_.")
        #expect(IngredientKey.documentID(for: "..") == "k_..")
        #expect(IngredientKey.documentID(for: "__name__") == "k___name__")
        #expect(IngredientKey.documentID(for: "__") == "__")
    }

    @Test func documentIDOfEmptyNameIsEmpty() {
        #expect(IngredientKey.documentID(for: "   ") == "")
    }

    @Test func longNamesAreTruncatedOnACharacterBoundary() {
        let ascii = String(repeating: "a", count: 500)
        #expect(IngredientKey.documentID(for: ascii).utf8.count == 400)

        // "é" folds to "e"; use a character with no ASCII fold so multi-byte characters survive.
        let multibyte = String(repeating: "日", count: 200)  // 3 bytes each = 600 bytes
        let id = IngredientKey.documentID(for: multibyte)
        #expect(id.utf8.count <= 400)
        #expect(id.utf8.count == 399)  // 133 characters; a 134th would exceed 400
        #expect(id.allSatisfy { $0 == "日" })
    }

    @Test func sameIngredientTypedDifferentlyGetsTheSameID() {
        let a = IngredientKey.documentID(for: "Olive  Oil ")
        let b = IngredientKey.documentID(for: "olive oil")
        #expect(a == b)
    }
}
