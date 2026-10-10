import Foundation

/// The name shown on recipes a user shares. Foundation-only.
enum DisplayName {
    static let maxLength = 50

    /// Trimmed, whitespace collapsed, and cut to `maxLength` characters.
    static func clean(_ text: String) -> String {
        let collapsed = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(
            separator: " ")
        return String(collapsed.prefix(maxLength)).trimmingCharacters(in: .whitespaces)
    }

    /// What to show for a user: what they typed, else the part of their email before the `@`, else "Someone".
    static func resolved(_ typed: String, email: String?) -> String {
        let name = clean(typed)
        if !name.isEmpty { return name }
        if let email {
            let fallback = clean(String(email.prefix { $0 != "@" }))
            if !fallback.isEmpty { return fallback }
        }
        return "Someone"
    }
}
