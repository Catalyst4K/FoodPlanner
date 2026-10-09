import Foundation

/// An ingredient line split into amount, unit and name.
struct ParsedIngredient: Equatable {
    var quantity: Double?
    /// A normalised unit (Appendix E), or nil for counts like "3 eggs" and lines with no amount.
    var unit: String?
    var name: String
}

/// Parses free text such as "200g plain flour", "1 1/2 cups milk" or "½ tsp salt". Never fails: the worst
/// case is the whole (trimmed) text becoming the name. Foundation-only.
enum IngredientParser {
    private static let unicodeFractions: [Character: Double] = [
        "½": 0.5, "⅓": 1.0 / 3, "⅔": 2.0 / 3, "¼": 0.25, "¾": 0.75, "⅕": 0.2, "⅖": 0.4, "⅗": 0.6, "⅘": 0.8,
        "⅙": 1.0 / 6, "⅚": 5.0 / 6, "⅛": 0.125, "⅜": 0.375, "⅝": 0.625, "⅞": 0.875,
    ]

    static func parse(_ text: String) -> ParsedIngredient {
        let line = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
        guard !line.isEmpty else { return ParsedIngredient(quantity: nil, unit: nil, name: "") }

        var rest = Substring(line)
        guard var quantity = scanAmount(&rest) else {
            return ParsedIngredient(quantity: nil, unit: nil, name: line)
        }

        // A range ("2-3", "2 to 3"): keep it simple and take the upper bound.
        if let upper = scanRangeEnd(&rest) { quantity = upper }

        // Optional unit, attached ("200g") or spaced ("200 g").
        var unit: String?
        let attached = rest.prefix { $0.isLetter || $0 == "." }
        if !rest.isEmpty, rest.first?.isWhitespace == false {
            // Letters glued to the number must be a unit ("200g"); otherwise this isn't an amount ("7up").
            guard let normalized = IngredientUnit.normalized(String(attached)) else {
                return ParsedIngredient(quantity: nil, unit: nil, name: line)
            }
            unit = normalized
            rest = rest.dropFirst(attached.count)
        } else {
            let afterSpace = rest.drop { $0.isWhitespace }
            let word = afterSpace.prefix { $0.isLetter || $0 == "." }
            if let normalized = IngredientUnit.normalized(String(word)) {
                unit = normalized
                rest = afterSpace.dropFirst(word.count)
            }
        }

        var name = rest.trimmingCharacters(in: .whitespaces)
        if name.lowercased().hasPrefix("of ") { name = String(name.dropFirst(3)).trimmingCharacters(in: .whitespaces) }
        // "200 g" with no name, or "3": there is nothing to call it, so keep the whole text as the name.
        guard !name.isEmpty else { return ParsedIngredient(quantity: nil, unit: nil, name: line) }
        return ParsedIngredient(quantity: quantity, unit: unit, name: name)
    }

    // MARK: - Scanning

    /// Reads a leading amount: integer, decimal (`1.5`, `1,5`), fraction (`1/2`), mixed (`1 1/2`, `1½`) or a
    /// unicode fraction (`½`). Advances `rest` past it and past one following space.
    private static func scanAmount(_ rest: inout Substring) -> Double? {
        var cursor = rest
        var total = 0.0
        var sawWhole = false

        if let whole = scanDecimal(&cursor) {
            total = whole
            sawWhole = true
            // "1/2": a slash directly after an integer makes it a fraction, not a whole number.
            if cursor.first == "/", whole == whole.rounded() {
                var probe = cursor
                if let denominator = scanDigits(dropping: &probe, after: "/"), denominator != 0 {
                    rest = probe
                    return whole / denominator
                }
            }
        }

        // Fractional part: "½" right after the number ("1½"), or after a space ("1 ½", "1 1/2").
        if let fraction = scanFraction(&cursor) {
            total += fraction
            rest = cursor
            return total
        }
        if sawWhole {
            let spaced = cursor.drop { $0 == " " }
            if spaced.count != cursor.count {
                var probe = spaced
                if let fraction = scanFraction(&probe) {
                    total += fraction
                    rest = probe
                    return total
                }
            }
            rest = cursor
            return total
        }
        return nil
    }

    private static func scanFraction(_ cursor: inout Substring) -> Double? {
        if let first = cursor.first, let value = unicodeFractions[first] {
            cursor = cursor.dropFirst()
            return value
        }
        // "1/2" form
        var probe = cursor
        if let numerator = scanDigits(&probe), probe.first == "/",
            let denominator = scanDigits(dropping: &probe, after: "/"), denominator != 0
        {
            cursor = probe
            return numerator / denominator
        }
        return nil
    }

    /// Digits with an optional decimal part. `.` or `,` followed by one or two digits is a decimal point; a comma
    /// followed by three digits is a thousands separator ("1,000").
    private static func scanDecimal(_ cursor: inout Substring) -> Double? {
        var probe = cursor
        let whole = probe.prefix { $0.isASCII && $0.isNumber }
        guard !whole.isEmpty else { return nil }
        probe = probe.dropFirst(whole.count)
        var text = String(whole)

        if let separator = probe.first, separator == "." || separator == "," {
            let digits = probe.dropFirst().prefix { $0.isASCII && $0.isNumber }
            if separator == "," && digits.count == 3 {
                text += String(digits)
                probe = probe.dropFirst(1 + digits.count)
            } else if !digits.isEmpty {
                text += "." + String(digits)
                probe = probe.dropFirst(1 + digits.count)
            }
        }
        guard let value = Double(text) else { return nil }
        cursor = probe
        return value
    }

    private static func scanDigits(_ cursor: inout Substring) -> Double? {
        let digits = cursor.prefix { $0.isASCII && $0.isNumber }
        guard !digits.isEmpty, let value = Double(digits) else { return nil }
        cursor = cursor.dropFirst(digits.count)
        return value
    }

    /// Reads the digits after `separator`, which `cursor` is currently sitting on.
    private static func scanDigits(dropping cursor: inout Substring, after separator: Character) -> Double? {
        guard cursor.first == separator else { return nil }
        var probe = cursor.dropFirst()
        guard let value = scanDigits(&probe) else { return nil }
        cursor = probe
        return value
    }

    /// After a first amount: "-", "–", "—" or " to " followed by another amount gives the range's upper bound.
    private static func scanRangeEnd(_ rest: inout Substring) -> Double? {
        var probe = rest.drop { $0 == " " }
        if let dash = probe.first, "-–—".contains(dash) {
            probe = probe.dropFirst().drop { $0 == " " }
        } else if probe.lowercased().hasPrefix("to ") {
            probe = probe.dropFirst(3).drop { $0 == " " }
        } else {
            return nil
        }
        var amount = probe
        guard let upper = scanAmount(&amount) else { return nil }
        rest = amount
        return upper
    }
}
