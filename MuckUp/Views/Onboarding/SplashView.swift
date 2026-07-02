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

            // Sizing/spacing matched to LaunchScreen.storyboard so the handoff
            // from the system launch screen to this view is seamless — no
            // visible jump in icon size or text position.
            VStack(spacing: 0) {
                Image("LaunchIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .scaleEffect(iconScale)
                    .padding(.bottom, 16)

                Text("GRUB")
                    .font(.system(size: 48, weight: .black))
                    .foregroundStyle(.white)

                Text("spot it · log it · clean it up")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
                    .padding(.top, 6)
            }
            .offset(y: -30)
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
