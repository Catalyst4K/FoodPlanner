import Foundation

/// Turns an amount, unit and name back into text ("200 g plain flour", "1½ tbsp sugar", "3 eggs"). Foundation-only.
enum IngredientFormatter {
    private static let fractions: [(value: Double, glyph: String)] = [
        (0.125, "⅛"), (0.25, "¼"), (1.0 / 3, "⅓"), (0.375, "⅜"), (0.5, "½"), (0.625, "⅝"), (2.0 / 3, "⅔"), (0.75, "¾"),
        (0.875, "⅞"),
    ]

    static func format(_ item: IngredientItem) -> String {
        format(quantity: item.quantity, unit: item.unit, name: item.name)
    }

    static func format(quantity: Double?, unit: String?, name: String) -> String {
        guard let quantity, quantity.isFinite, quantity > 0 else { return name }
        var parts = [formatQuantity(quantity)]
        if let unit, !unit.isEmpty { parts.append(IngredientUnit.displayName(unit, for: quantity)) }
        parts.append(name)
        return parts.joined(separator: " ")
    }

    /// 1.5 → "1½", 0.25 → "¼", 200 → "200", 2.4 → "2.4". Amounts that sit within 0.02 of a common fraction
    /// snap to it; large amounts lose their decimals.
    static func formatQuantity(_ quantity: Double) -> String {
        guard quantity.isFinite, quantity > 0 else { return "" }
        if quantity >= 100 { return String(Int(quantity.rounded())) }

        var whole = quantity.rounded(.down)
        let fraction = quantity - whole
        if fraction < 0.02 { return String(Int(whole)) }
        if fraction > 0.98 { return String(Int(whole) + 1) }
        if quantity < 10, let match = fractions.first(where: { abs($0.value - fraction) < 0.02 }) {
            return whole == 0 ? match.glyph : "\(Int(whole))\(match.glyph)"
        }

        whole = quantity
        let places = quantity < 10 ? 2.0 : 1.0
        let factor = pow(10.0, places)
        let rounded = (whole * factor).rounded() / factor
        var text = String(format: "%.\(Int(places))f", rounded)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }
}
