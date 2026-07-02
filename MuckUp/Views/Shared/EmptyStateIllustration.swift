import SwiftUI

/// Small hand-drawn vector illustration for empty states — a leaf resting
/// in a soft circle — instead of a plain grey SF Symbol.
struct EmptyStateIllustration: View {
    var systemImage: String = "leaf.fill"
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

            Image(systemName: systemImage)
                .font(.system(size: size * 0.4))
                .foregroundStyle(Color.muckGreen.opacity(0.6))
                .rotationEffect(.degrees(-8))
        }
    }
}

#Preview {
    EmptyStateIllustration()
        .padding()
        .background(Color.muckBg)
}
