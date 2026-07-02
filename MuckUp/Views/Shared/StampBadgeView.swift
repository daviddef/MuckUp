import SwiftUI

/// Collectible-feeling achievement badge — a rotated circular "stamp"
/// instead of a plain text pill.
struct StampBadgeView: View {
    let emoji: String
    let label: String
    var rotation: Double = -6

    var body: some View {
        VStack(spacing: 2) {
            Text(emoji)
                .font(.system(size: 20))
        }
        .frame(width: 52, height: 52)
        .background(
            Circle()
                .fill(Color.muckSurface)
                .overlay(
                    Circle()
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                        .foregroundStyle(Color.muckGreen.opacity(0.5))
                )
        )
        .overlay(
            Circle().strokeBorder(Color.muckGreen.opacity(0.25), lineWidth: 1)
        )
        .rotationEffect(.degrees(rotation))
        .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 2)
        .accessibilityLabel(label)
    }
}

#Preview {
    HStack(spacing: Spacing.md) {
        StampBadgeView(emoji: "🌍", label: "Eco Warrior", rotation: -8)
        StampBadgeView(emoji: "🤝", label: "Good Neighbour", rotation: 5)
        StampBadgeView(emoji: "🔥", label: "On Fire", rotation: -3)
    }
    .padding()
    .background(Color.muckBg)
}
