import Foundation

/// Normalises ingredient names so "Olive  Oil ", "olive oil" and "OLIVE OIL" are the same
/// ingredient everywhere (matching, de-duplication, Firestore document IDs).
/// Foundation-only so it can be unit-tested without Firebase. Rules: docs/IMPLEMENTATION_PLAN.md, Appendix C.
enum IngredientKey {
    /// Trimmed, whitespace-collapsed, case-, diacritic- and width-insensitive form of `name`.
    /// May be empty; callers must reject empty names before writing.
    static func normalized(_ name: String) -> String {
        let collapsed =
            name
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return collapsed.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }

    /// A Firestore-safe document ID derived from the normalised name. Callers must reject empty
    /// names first; an empty name yields an empty (invalid) ID.
    static func documentID(for name: String) -> String {
        var key = normalized(name)
        key = key.replacingOccurrences(of: "%", with: "%25").replacingOccurrences(of: "/", with: "%2F")
        if key == "." || key == ".." || (key.hasPrefix("__") && key.hasSuffix("__") && key.count >= 4) {
            key = "k_" + key
        }
        return truncatedToUTF8Bytes(key, limit: 400)
    }

    /// Cuts `string` to at most `limit` UTF-8 bytes, never splitting a character.
    private static func truncatedToUTF8Bytes(_ string: String, limit: Int) -> String {
        guard string.utf8.count > limit else { return string }
        var result = ""
        var bytes = 0
        for character in string {
            let size = String(character).utf8.count
            if bytes + size > limit { break }
            result.append(character)
            bytes += size
        }
        return result
    }
}
