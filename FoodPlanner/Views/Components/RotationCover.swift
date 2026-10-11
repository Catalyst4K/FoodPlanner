import SwiftUI
import UIKit

extension View {
    /// Hides the rotation animation behind a solid cover. The cover appears INSTANTLY on rotation (no fade-in,
    /// otherwise UIKit's rotation animation would already be underway), then fades out once the rotation has
    /// finished, revealing the newly laid-out orientation.
    func coversRotation() -> some View { modifier(RotationCover()) }
}

private struct RotationCover: ViewModifier {
    @State private var opacity: Double = 0

    func body(content: Content) -> some View {
        content
            // Solid background so any exposed edges during rotation blend in instead of showing black.
            .background(Color(.systemBackground).ignoresSafeArea())
            .overlay {
                Color(.systemBackground)
                    .ignoresSafeArea()
                    // Extra oversize keeps corners covered while UIKit rotates the frame.
                    .frame(width: 3000, height: 3000)
                    .opacity(opacity)
                    .allowsHitTesting(opacity > 0.01)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                // Only mask real orientation changes (portrait ↔ landscape). Ignore face-up / face-down.
                let orientation = UIDevice.current.orientation
                guard orientation.isPortrait || orientation.isLandscape else { return }

                opacity = 1  // Instant cover: critically no animation here.
                // Wait past UIKit's rotation animation (~0.3–0.4s) before fading the cover out.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeOut(duration: 0.35)) {
                        opacity = 0
                    }
                }
            }
    }
}
