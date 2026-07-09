import SwiftUI

/// Grub's actual namesake — a small illustrated creature (hand-drawn
/// Canvas shapes, no image assets) that lives on Home instead of an
/// abstract rank badge. Its body plan advances through a real
/// metamorphosis as rank increases, so the same character carries the
/// whole progress story instead of a separate emoji per tier.
enum GrubLifecycleStage: Int, CaseIterable {
    case egg, grub, bigGrub, cocoon, wingsOut, fullFlight

    static func forRank(_ rank: MuckRank) -> GrubLifecycleStage {
        GrubLifecycleStage(rawValue: rank.rawValue) ?? .egg
    }

    var label: String {
        switch self {
        case .egg:        return "Egg"
        case .grub:        return "Grub"
        case .bigGrub:     return "Big Grub"
        case .cocoon:      return "Cocoon"
        case .wingsOut:    return "Wings Out"
        case .fullFlight:  return "Full Flight"
        }
    }
}

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
    var stage: GrubLifecycleStage = .grub
    let mood: GrubMood
    var size: CGFloat = 72
    // The idle vertical breathing loop reads fine at hero sizes (Profile,
    // rank-up banner) but is too much motion for a small, frequently-
    // visible spot like the patch-health card — callers there can turn
    // it off while keeping blink/sway.
    var bounceEnabled: Bool = true
    // A slow side-to-side patrol instead of the vertical bounce — reads
    // as "pacing the patch" rather than "bobbing in place".
    var walkEnabled: Bool = false
    var walkRange: CGFloat = 14

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false
    @State private var isBlinking = false
    @State private var blinkTask: Task<Void, Never>?
    @State private var walkedRight = false
    @State private var facingRight = true
    @State private var walkTask: Task<Void, Never>?

    // A Canvas can't interpolate between two completely different body
    // plans on its own — .animation() only tweens real View properties.
    // To crossfade a stage change (e.g. rank-up), keep the outgoing
    // stage's Canvas around at fading opacity while the new one fades in.
    @State private var outgoingStage: GrubLifecycleStage?
    @State private var crossfade: Double = 1

    var body: some View {
        ZStack {
            if let outgoingStage, crossfade < 1 {
                canvas(for: outgoingStage)
                    .opacity(1 - crossfade)
            }
            canvas(for: stage)
                .opacity(outgoingStage == nil ? 1 : crossfade)
        }
        .frame(width: size, height: size)
        .scaleEffect(x: (walkEnabled && !facingRight) ? -1 : 1, y: 1)
        .offset(
            x: walkEnabled && !reduceMotion ? (walkedRight ? walkRange / 2 : -walkRange / 2) : 0,
            y: (breathe && !reduceMotion && bounceEnabled ? -2 : 0) + (bounceEnabled ? mood.bounce : 0)
        )
        .animation(reduceMotion ? nil : .easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: breathe)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: mood.bounce)
        .animation(reduceMotion ? nil : .easeInOut(duration: 1.8), value: walkedRight)
        .onAppear {
            breathe = true
            startBlinkLoop()
            if walkEnabled { startWalkLoop() }
        }
        .onDisappear {
            blinkTask?.cancel()
            walkTask?.cancel()
        }
        .onChange(of: stage) { oldStage, _ in
            guard !reduceMotion else { return }
            outgoingStage = oldStage
            crossfade = 0
            withAnimation(.easeInOut(duration: 0.5)) { crossfade = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { outgoingStage = nil }
        }
        .accessibilityHidden(true)
    }

    // Hand-illustrated frame sets replace the flat vector drawing one
    // stage at a time as they arrive — a stage with no sprite folder
    // yet keeps using the Canvas body plan below.
    @ViewBuilder
    private func canvas(for stage: GrubLifecycleStage) -> some View {
        if AnimatedGrubSpriteView.hasSprite(for: stage) {
            AnimatedGrubSpriteView(stage: stage, size: size)
        } else {
            TimelineView(.animation(paused: reduceMotion)) { timeline in
                Canvas { context, canvasSize in
                    draw(stage: stage, in: &context, size: canvasSize, time: timeline.date.timeIntervalSinceReferenceDate)
                }
            }
        }
    }

    // Alternates a short walk left/right on a fixed cadence — the
    // .animation(value: walkedRight) modifier eases the actual offset,
    // this loop just flips the target and keeps facingRight in sync so
    // the sprite turns around at each end of its patrol.
    private func startWalkLoop() {
        guard !reduceMotion else { return }
        walkTask?.cancel()
        walkTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                guard !Task.isCancelled else { return }
                walkedRight.toggle()
                facingRight = walkedRight
            }
        }
    }

    // Randomised 3–6s blink cycle — the single highest-leverage idle
    // detail for reading as alive rather than a static illustration.
    // Skipped entirely under Reduce Motion.
    private func startBlinkLoop() {
        guard !reduceMotion else { return }
        blinkTask?.cancel()
        blinkTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64.random(in: 3_000_000_000...6_000_000_000))
                guard !Task.isCancelled else { return }
                isBlinking = true
                try? await Task.sleep(nanoseconds: 120_000_000)
                isBlinking = false
            }
        }
    }

    private func draw(stage: GrubLifecycleStage, in context: inout GraphicsContext, size canvasSize: CGSize, time: TimeInterval) {
        let w = canvasSize.width
        let h = canvasSize.height
        let sway: CGFloat = reduceMotion ? 0 : CGFloat(sin(time * 1.3)) * (w * 0.03)
        let eyeScale: CGFloat = isBlinking ? 0.12 : 1

        switch stage {
        case .egg:
            drawEgg(&context, w: w, h: h)
        case .grub:
            drawLarva(&context, w: w, h: h, bodyScale: 0.75, sway: sway, eyeScale: eyeScale)
        case .bigGrub:
            drawLarva(&context, w: w, h: h, bodyScale: 1.0, sway: sway, eyeScale: eyeScale)
        case .cocoon:
            drawCocoon(&context, w: w, h: h, sway: sway)
        case .wingsOut:
            drawButterfly(&context, w: w, h: h, wingSpread: 0.55, time: time, eyeScale: eyeScale)
        case .fullFlight:
            drawButterfly(&context, w: w, h: h, wingSpread: 1.0, time: time, eyeScale: eyeScale)
        }

        // Concerned/celebrating expression overlays apply on top of any
        // stage that has a visible face (egg has none).
        if stage != .egg && stage != .cocoon {
            drawExpressionAccents(&context, w: w, h: h, bodyScale: stage == .grub ? 0.75 : (stage == .bigGrub ? 1.0 : 0.8))
        }
    }

    private func drawEgg(_ context: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        let rect = CGRect(x: w * 0.36, y: h * 0.28, width: w * 0.28, height: h * 0.44)
        context.fill(Path(ellipseIn: rect), with: .color(.muckSurface))
        context.stroke(Path(ellipseIn: rect), with: .color(.muckMoss), lineWidth: max(1.5, w * 0.015))
        // A faint crack hints at what's coming without needing motion.
        var crack = Path()
        crack.move(to: CGPoint(x: w * 0.46, y: h * 0.4))
        crack.addLine(to: CGPoint(x: w * 0.5, y: h * 0.48))
        crack.addLine(to: CGPoint(x: w * 0.47, y: h * 0.56))
        context.stroke(crack, with: .color(.muckMoss.opacity(0.5)), lineWidth: max(1, w * 0.008))
    }

    private func drawLarva(_ context: inout GraphicsContext, w: CGFloat, h: CGFloat, bodyScale: CGFloat, sway: CGFloat, eyeScale: CGFloat) {
        let segments: [(dx: CGFloat, dy: CGFloat, r: CGFloat)] = [
            (0.30, 0.62, 0.30),
            (0.52, 0.58, 0.26),
            (0.72, 0.55, 0.20),
        ]
        for seg in segments {
            let r = w * seg.r * bodyScale
            let center = CGPoint(x: w * seg.dx, y: h * seg.dy)
            context.fill(
                Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r * 0.85, width: r * 2, height: r * 1.7)),
                with: .color(.muckLime)
            )
        }

        let bellyRect = CGRect(x: w * 0.28, y: h * 0.68, width: w * 0.5 * bodyScale, height: h * 0.22 * bodyScale)
        context.fill(Path(ellipseIn: bellyRect), with: .color(.muckFern.opacity(0.35)))

        let headCenter = CGPoint(x: w * 0.80, y: h * 0.48)
        let headR = w * 0.19 * bodyScale
        context.fill(
            Path(ellipseIn: CGRect(x: headCenter.x - headR, y: headCenter.y - headR, width: headR * 2, height: headR * 2)),
            with: .color(.muckLime)
        )

        let eyeY = headCenter.y - headR * 0.15
        let eyeDX = headR * 0.42
        let eyeR = headR * 0.22 * eyeScale
        for dx in [-eyeDX, eyeDX] {
            let c = CGPoint(x: headCenter.x + dx, y: eyeY)
            context.fill(
                Path(ellipseIn: CGRect(x: c.x - eyeR, y: c.y - max(1, eyeR), width: eyeR * 2, height: max(2, eyeR * 2))),
                with: .color(.muckNearBlack)
            )
        }

        for dxBase: CGFloat in [-0.6, 0.6] {
            var path = Path()
            let base = CGPoint(x: headCenter.x + dxBase * headR * 0.5, y: headCenter.y - headR * 0.8)
            let tip = CGPoint(x: base.x + dxBase * headR * 0.4 + sway, y: base.y - headR * 0.8)
            path.move(to: base)
            path.addQuadCurve(to: tip, control: CGPoint(x: base.x + dxBase * headR * 0.7 + sway * 0.5, y: base.y - headR * 0.5))
            context.stroke(path, with: .color(.muckMoss), lineWidth: max(1.5, w * 0.015))
            let tipR = w * 0.02
            context.fill(Path(ellipseIn: CGRect(x: tip.x - tipR, y: tip.y - tipR, width: tipR * 2, height: tipR * 2)), with: .color(.muckMoss))
        }
    }

    private func drawCocoon(_ context: inout GraphicsContext, w: CGFloat, h: CGFloat, sway: CGFloat) {
        let center = CGPoint(x: w * 0.5 + sway * 0.3, y: h * 0.55)
        let rect = CGRect(x: center.x - w * 0.16, y: center.y - h * 0.26, width: w * 0.32, height: h * 0.52)
        context.fill(Path(ellipseIn: rect), with: .color(Color(hex: "C9B27A")))
        context.stroke(Path(ellipseIn: rect), with: .color(.muckMoss), lineWidth: max(1.5, w * 0.012))
        for i in -2...2 {
            var band = Path()
            let y = center.y + CGFloat(i) * h * 0.09
            band.move(to: CGPoint(x: center.x - w * 0.14, y: y))
            band.addLine(to: CGPoint(x: center.x + w * 0.14, y: y))
            context.stroke(band, with: .color(.muckMoss.opacity(0.6)), lineWidth: max(1, w * 0.01))
        }
    }

    private func drawButterfly(_ context: inout GraphicsContext, w: CGFloat, h: CGFloat, wingSpread: CGFloat, time: TimeInterval, eyeScale: CGFloat) {
        let flap: CGFloat = reduceMotion ? wingSpread : wingSpread * (0.85 + CGFloat(sin(time * 4)) * 0.15)
        let center = CGPoint(x: w * 0.5, y: h * 0.5)

        for side: CGFloat in [-1, 1] {
            var upperWing = Path()
            let wx = center.x + side * w * 0.13 * flap
            let wy = center.y - h * 0.06
            upperWing.addEllipse(in: CGRect(x: wx - w * 0.13 * flap, y: wy - h * 0.12, width: w * 0.26 * flap, height: h * 0.24))
            context.fill(upperWing, with: .color(.muckAmber))

            var lowerWing = Path()
            let lwx = center.x + side * w * 0.10 * flap
            let lwy = center.y + h * 0.08
            lowerWing.addEllipse(in: CGRect(x: lwx - w * 0.09 * flap, y: lwy - h * 0.09, width: w * 0.18 * flap, height: h * 0.18))
            context.fill(lowerWing, with: .color(.muckGreen))
        }

        // Body
        let bodyRect = CGRect(x: center.x - w * 0.02, y: center.y - h * 0.16, width: w * 0.04, height: h * 0.32)
        context.fill(Path(ellipseIn: bodyRect), with: .color(.muckFern))

        // Face
        let headR = w * 0.06
        let headCenter = CGPoint(x: center.x, y: center.y - h * 0.16)
        context.fill(Path(ellipseIn: CGRect(x: headCenter.x - headR, y: headCenter.y - headR, width: headR * 2, height: headR * 2)), with: .color(.muckFern))
        let eyeR = headR * 0.28 * eyeScale
        for dx: CGFloat in [-1, 1] {
            let c = CGPoint(x: headCenter.x + dx * headR * 0.45, y: headCenter.y)
            context.fill(Path(ellipseIn: CGRect(x: c.x - eyeR, y: c.y - max(1, eyeR), width: eyeR * 2, height: max(2, eyeR * 2))), with: .color(.muckNearBlack))
        }
    }

    private func drawExpressionAccents(_ context: inout GraphicsContext, w: CGFloat, h: CGFloat, bodyScale: CGFloat) {
        let headCenter = CGPoint(x: w * 0.80, y: h * 0.48)
        let headR = w * 0.19 * bodyScale

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

        if mood == .celebrating {
            for dx: CGFloat in [-1, 1] {
                let c = CGPoint(x: headCenter.x + dx * headR * 0.75, y: headCenter.y + headR * 0.15)
                let r = headR * 0.14
                context.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(.muckAmber.opacity(0.5)))
            }
        }
    }
}

extension GrubLifecycleStage: Equatable {}

#Preview {
    HStack(spacing: Spacing.lg) {
        ForEach(GrubLifecycleStage.allCases, id: \.self) { stage in
            VStack {
                GrubCharacterView(stage: stage, mood: .idle)
                Text(stage.label).font(.muckCaption)
            }
        }
    }
    .padding()
    .background(Color.muckBg)
}
