import SwiftUI

/// "Servings  4  [-][+]" for the recipe forms. Zero means "not set" (nil).
struct ServingsStepper: View {
    @Binding var servings: Int?

    var body: some View {
        HStack {
            Text("Servings")
                .font(.title3)
            Spacer()
            Text(servings.map(String.init) ?? "Not set")
                .foregroundColor(.secondary)
            Stepper(
                "Servings",
                value: Binding(get: { servings ?? 0 }, set: { servings = $0 == 0 ? nil : $0 }),
                in: 0...100
            )
            .labelsHidden()
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("form.servings")
    }
}
