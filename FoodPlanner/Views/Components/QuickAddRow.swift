import SwiftUI

/// The "+ Add ingredient" row: a plus button and a text field that commits on return, on tapping the plus
/// button, and when focus is lost (so tapping away also saves).
struct QuickAddRow: View {
    enum Style {
        /// Inside the recipe forms (add and edit).
        case form
        /// Inside the pantry and shopping lists.
        case list
    }

    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    var style: Style = .form
    var fieldIdentifier: String?
    /// Ingredient names to suggest from while typing (empty: no suggestions).
    var knownNames: [String] = []
    let onCommit: () -> Void

    private var suggestions: [String] {
        isFocused.wrappedValue ? IngredientSuggestions.suggestions(for: text, known: knownNames) : []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            row
            suggestionBar
        }
    }

    @ViewBuilder
    private var suggestionBar: some View {
        if !suggestions.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(suggestion) {
                            text = IngredientSuggestions.completing(text, with: suggestion)
                            onCommit()
                            isFocused.wrappedValue = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityIdentifier("suggestion.\(suggestion)")
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 6)
            }
        }
    }

    private var row: some View {
        HStack(spacing: style == .list ? 8 : nil) {
            Button {
                onCommit()
                isFocused.wrappedValue = true
            } label: {
                if style == .form {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.gray)
                        .padding(.leading)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.gray)
                }
            }
            .buttonStyle(.plain)

            field
        }
        .padding(.horizontal)
        .padding(.vertical, style == .list ? 10 : 0)
        .onChange(of: isFocused.wrappedValue) { was, _ in
            if was { onCommit() }
        }
    }

    @ViewBuilder
    private var field: some View {
        let base = TextField("Add ingredient", text: $text)
            .focused(isFocused)
            .submitLabel(.return)
            .onSubmit(onCommit)
        let sized =
            style == .form
            ? AnyView(base.padding(.vertical, 10).padding(.horizontal, 4))
            : AnyView(base)
        if let fieldIdentifier {
            sized.accessibilityIdentifier(fieldIdentifier)
        } else {
            sized
        }
    }
}
