import SwiftUI

/// Shown while `AuthManager` restores the session on cold start.
struct SessionRestoreView: View {
    @State private var isRotating = false

    var body: some View {
        ZStack {
            Color.theme.splashBackground
                .ignoresSafeArea()

            // Folder `icons` has provides-namespace — name is `icons/splash`.
            Image("icons/splash")
                .resizable()
                .scaledToFit()
                .frame(width: 168, height: 168)
                .clipShape(RoundedRectangle(cornerRadius: 38, style: .continuous))
                .rotationEffect(.degrees(isRotating ? 360 : 0))
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.Brand.name)
        .accessibilityValue(L10n.Common.loading)
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                isRotating = true
            }
        }
    }
}

#Preview {
    SessionRestoreView()
}
