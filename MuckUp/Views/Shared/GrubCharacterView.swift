import SwiftUI

/// Grub's actual namesake — a small illustrated creature (hand-drawn
/// Canvas shapes, no image assets, matching GrowthPlantView's approach)
/// that lives on Home instead of an abstract rank badge. It reacts to
/// what's happening around it rather than sitting static.
enum GrubMood {
    case idle, celebrating, concerned

    var bounce: CGFloat {
        switch self {
        case .idle:        return 0
        case .celebrating: return -8
        case .concerned:   return 0
        }
    }
}

struct GrubCharacterView: View {
    let mood: GrubMood
    var size: CGFloat = 72

    @State private var breathe = false

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height

            // Segmented larval body — three overlapping ellipses,
            // largest at the back tapering toward the head.
            let segments: [(dx: CGFloat, dy: CGFloat, r: CGFloat)] = [
                (0.30, 0.62, 0.30),
                (0.52, 0.58, 0.26),
                (0.72, 0.55, 0.20),
            ]
            for seg in segments {
                let r = w * seg.r
                let center = CGPoint(x: w * seg.dx, y: h * seg.dy)
                context.fill(
                    Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r * 0.85, width: r * 2, height: r * 1.7)),
                    with: .color(.muckLime)
                )
            }

            // Belly shading
            let bellyRect = CGRect(x: w * 0.28, y: h * 0.68, width: w * 0.5, height: h * 0.22)
            context.fill(Path(ellipseIn: bellyRect), with: .color(.muckFern.opacity(0.35)))

            // Head
            let headCenter = CGPoint(x: w * 0.80, y: h * 0.48)
            let headR = w * 0.19
            context.fill(
                Path(ellipseIn: CGRect(x: headCenter.x - headR, y: headCenter.y - headR, width: headR * 2, height: headR * 2)),
                with: .color(.muckLime)
            )

            // Eyes — wide and round when idle/celebrating, narrowed when concerned
            let eyeY = headCenter.y - headR * 0.15
            let eyeDX = headR * 0.42
            let eyeR = mood == .concerned ? headR * 0.14 : headR * 0.22
            for dx in [-eyeDX, eyeDX] {
                let c = CGPoint(x: headCenter.x + dx, y: eyeY)
                context.fill(
                    Path(ellipseIn: CGRect(x: c.x - eyeR, y: c.y - eyeR, width: eyeR * 2, height: eyeR * 2)),
                    with: .color(.muckNearBlack)
                )
            }

            // Antennae
            for dx: CGFloat in [-0.6, 0.6] {
                var path = Path()
                let base = CGPoint(x: headCenter.x + dx * headR * 0.5, y: headCenter.y - headR * 0.8)
                let tip = CGPoint(x: base.x + dx * headR * 0.4, y: base.y - headR * 0.8)
                path.move(to: base)
                path.addQuadCurve(to: tip, control: CGPoint(x: base.x + dx * headR * 0.7, y: base.y - headR * 0.5))
                context.stroke(path, with: .color(.muckMoss), lineWidth: max(1.5, w * 0.015))
                let tipR = w * 0.02
                context.fill(Path(ellipseIn: CGRect(x: tip.x - tipR, y: tip.y - tipR, width: tipR * 2, height: tipR * 2)), with: .color(.muckMoss))
            }

            // Mouth
            var mouth = Path()
            let mouthY = headCenter.y + headR * 0.35
            if mood == .concerned {
                mouth.move(to: CGPoint(x: headCenter.x - headR * 0.25, y: mouthY + headR * 0.1))
                mouth.addQuadCurve(
                    to: CGPoint(x: headCenter.x + headR * 0.25, y: mouthY + headR * 0.1),
                    control: CGPoint(x: headCenter.x, y: mouthY - headR * 0.1)
                )
            } else {
                mouth.move(to: CGPoint(x: headCenter.x - headR * 0.25, y: mouthY))
                mouth.addQuadCurve(
                    to: CGPoint(x: headCenter.x + headR * 0.25, y: mouthY),
                    control: CGPoint(x: headCenter.x, y: mouthY + headR * 0.35)
                )
            }
            context.stroke(mouth, with: .color(.muckNearBlack), lineWidth: max(1.5, w * 0.02))

            // Cheeks when celebrating
            if mood == .celebrating {
                for dx: CGFloat in [-1, 1] {
                    let c = CGPoint(x: headCenter.x + dx * headR * 0.75, y: headCenter.y + headR * 0.15)
                    let r = headR * 0.14
                    context.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(.muckAmber.opacity(0.5)))
                }
            }
        }
        .frame(width: size, height: size)
        .offset(y: (breathe ? -2 : 0) + mood.bounce)
        .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: breathe)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: mood.bounce)
        .onAppear { breathe = true }
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: Spacing.lg) {
        VStack { GrubCharacterView(mood: .idle); Text("Idle").font(.muckCaption) }
        VStack { GrubCharacterView(mood: .celebrating); Text("Celebrating").font(.muckCaption) }
        VStack { GrubCharacterView(mood: .concerned); Text("Concerned").font(.muckCaption) }
    }
    .padding()
    .background(Color.muckBg)
}
