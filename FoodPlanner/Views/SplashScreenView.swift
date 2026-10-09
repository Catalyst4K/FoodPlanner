import SwiftUI

struct SplashScreenView: View {
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            Text("Recipe App")
                .font(.largeTitle)
                .fontWeight(.bold)
        }
    }
}

#Preview {
    SplashScreenView()
}
