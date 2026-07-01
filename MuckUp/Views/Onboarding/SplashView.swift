import SwiftUI

/// Custom splash shown over the app on launch. The system launch screen
/// swaps instantly, so this SwiftUI overlay holds a beat longer and fades
/// out, giving the brand moment room to breathe.
struct SplashView: View {
    let onFinished: () -> Void

    @State private var iconScale: CGFloat = 0.85
    @State private var contentOpacity: Double = 0
    @State private var isFadingOut = false

    var body: some View {
        ZStack {
            Color.muckGreen.ignoresSafeArea()

            VStack(spacing: Spacing.md) {
                Image("LaunchIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 130, height: 130)
                    .scaleEffect(iconScale)

                VStack(spacing: 4) {
                    Text("GRUB")
                        .font(.system(size: 40, weight: .black))
                        .foregroundStyle(.white)
                        .kerning(1)
                    Text("spot it · log it · clean it up")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
            .opacity(contentOpacity)
        }
        .opacity(isFadingOut ? 0 : 1)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) {
                iconScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.4)) {
                contentOpacity = 1
            }
            // Hold, then fade the whole splash out
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation(.easeInOut(duration: 0.55)) {
                    isFadingOut = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                    onFinished()
                }
            }
        }
    }
}
