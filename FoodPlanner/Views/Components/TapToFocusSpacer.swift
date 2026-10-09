import SwiftUI

/// Fills the empty area under a list. Tapping it focuses the add field when idle and dismisses the keyboard
/// when already typing.
struct TapToFocusSpacer: View {
    var isFocused: FocusState<Bool>.Binding
    var minHeight: CGFloat = 120

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .frame(minHeight: minHeight)
            .onTapGesture {
                isFocused.wrappedValue.toggle()
            }
    }
}
