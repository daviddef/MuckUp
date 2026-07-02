import SwiftUI

/// Little leaf/sparkle burst for celebration moments (closing a muck,
/// resolving a help request, wrapping up an event). Attach via the
/// `.confettiBurst(trigger:)` modifier — fires once each time `trigger`
/// flips to true, then resets itself.
private struct ConfettiPiece: Identifiable {
    let id = UUID()
    let symbol: String
    let color: Color
    let angle: Double
    let distance: CGFloat
    let delay: Double
    let rotation: Double
}

struct ConfettiBurstView: View {
    let isActive: Bool

    private let pieces: [ConfettiPiece] = {
        let symbols = ["leaf.fill", "sparkle", "star.fill"]
        let colors: [Color] = [.muckGreen, .muckLime, .muckAmber, .muckFern]
        return (0..<16).map { i in
            ConfettiPiece(
                symbol: symbols[i % symbols.count],
                color: colors[i % colors.count],
                angle: Double(i) / 16 * 360,
                distance: CGFloat.random(in: 70...130),
                delay: Double.random(in: 0...0.08),
                rotation: Double.random(in: -180...180)
            )
        }
    }()

    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(pieces) { piece in
                Image(systemName: piece.symbol)
                    .font(.system(size: 14))
                    .foregroundStyle(piece.color)
                    .offset(
                        x: animate ? CGFloat(cos(piece.angle * .pi / 180)) * piece.distance : 0,
                        y: animate ? CGFloat(sin(piece.angle * .pi / 180)) * piece.distance : 0
                    )
                    .rotationEffect(.degrees(animate ? piece.rotation : 0))
                    .opacity(animate ? 0 : 1)
                    .animation(.easeOut(duration: 0.7).delay(piece.delay), value: animate)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: isActive) { _, newValue in
            guard newValue else { return }
            animate = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                animate = true
            }
        }
    }
}

private struct ConfettiBurstModifier: ViewModifier {
    @Binding var trigger: Bool

    func body(content: Content) -> some View {
        content.overlay(ConfettiBurstView(isActive: trigger))
    }
}

extension View {
    /// Fires a leaf/sparkle burst centred on this view whenever `trigger`
    /// becomes true. Caller doesn't need to reset it back to false.
    func confettiBurst(trigger: Binding<Bool>) -> some View {
        modifier(ConfettiBurstModifier(trigger: trigger))
    }
}
