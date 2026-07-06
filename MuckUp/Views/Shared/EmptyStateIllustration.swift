import SwiftUI

/// Small hand-drawn vector illustration for empty states, in a soft
/// circle. Contexts where nothing has happened *yet* near the user (the
/// default, no-argument case) get Grub itself, waiting for a mission —
/// everywhere else keeps a plain SF Symbol so the icon reads instantly
/// rather than forcing the character into places it doesn't fit the copy.
struct EmptyStateIllustration: View {
    var systemImage: String? = nil
    var size: CGFloat = 88

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.muckLime.opacity(0.18), Color.muckGreen.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(Color.muckGreen.opacity(0.6))
                    .rotationEffect(.degrees(-8))
            } else {
                GrubCharacterView(mood: .idle, size: size * 0.62)
            }
        }
    }
}

#Preview {
    EmptyStateIllustration()
        .padding()
        .background(Color.muckBg)
}
