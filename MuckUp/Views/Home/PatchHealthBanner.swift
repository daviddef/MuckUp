import SwiftUI

/// Turns "your local area" from an abstract map into a place with a
/// visible state — barren, growing, or thriving — driven by the real
/// ratio of cleared vs outstanding mucks nearby. Grub lives in it and
/// reacts: worried near open hazards, pleased when the patch is healthy.
enum PatchHealth: CaseIterable {
    case barren, growing, thriving

    var label: String {
        switch self {
        case .barren:   return "Your patch needs help"
        case .growing:  return "Your patch is growing"
        case .thriving: return "Your patch is thriving"
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .barren:
            return LinearGradient(colors: [Color(hex: "8A6D3B"), Color(hex: "B8935A")], startPoint: .leading, endPoint: .trailing)
        case .growing:
            return LinearGradient(colors: [Color.muckMoss, Color.muckFern], startPoint: .leading, endPoint: .trailing)
        case .thriving:
            return LinearGradient(colors: [Color.muckFern, Color.muckLime], startPoint: .leading, endPoint: .trailing)
        }
    }

    static func score(openCount: Int, closedCount: Int, openHazards: Int) -> PatchHealth {
        let total = openCount + closedCount
        guard total > 0 else { return .growing }
        let clearRate = Double(closedCount) / Double(total)
        if openHazards > 0 && clearRate < 0.5 { return .barren }
        if clearRate >= 0.6 { return .thriving }
        if clearRate >= 0.25 { return .growing }
        return .barren
    }
}

/// The single Home hero card — patch health and this week's community
/// challenge used to be two separate cards stacked on top of each
/// other; folded into one here since they're both "what's the state of
/// things nearby" at a glance, and stacking them cost a full card's
/// worth of vertical space before the feed even started.
struct PatchHealthBanner: View {
    let health: PatchHealth
    let openHazards: Int
    var stage: GrubLifecycleStage = .grub
    var challenge: WeeklyChallenge? = nil
    var challengeProgress: Int = 0

    // Never show the egg here — at 36pt in a small, always-visible card
    // it reads as an odd oval rather than a lifecycle stage. A brand-new
    // user just sees the grub sprite until their first rank-up.
    private var displayStage: GrubLifecycleStage {
        stage == .egg ? .grub : stage
    }

    private var mood: GrubMood {
        if openHazards > 0 && health == .barren { return .concerned }
        if health == .thriving { return .celebrating }
        return .idle
    }

    private var challengeFraction: Double {
        guard let challenge, challenge.targetCount > 0 else { return 0 }
        return min(1, Double(challengeProgress) / Double(challenge.targetCount))
    }

    private var isChallengeComplete: Bool {
        guard let challenge else { return false }
        return challengeProgress >= challenge.targetCount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                // No walk/bounce here — at 36pt the side-to-side pacing
                // plus its horizontal flip on turn-around read as
                // "spinning" once the sprite (busier than the old flat
                // vector) was in place. The sprite's own built-in idle
                // animation is motion enough on its own.
                GrubCharacterView(stage: displayStage, mood: mood, size: 36, bounceEnabled: false, walkEnabled: false)

                Text(health.label)
                    .font(.muckHeadline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer()

                if openHazards > 0 {
                    Text("\(openHazards) hazard\(openHazards == 1 ? "" : "s")")
                        .font(.muckMicro)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 2)
                        .background(.white.opacity(0.2))
                        .clipShape(Capsule())
                }
            }

            if let challenge {
                HStack(spacing: Spacing.xs) {
                    Text(challenge.title)
                        .font(.muckMicro)
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.2))
                            Capsule().fill(.white)
                                .frame(width: geo.size.width * challengeFraction)
                        }
                    }
                    .frame(height: 4)

                    Text(isChallengeComplete ? "✓" : "\(min(challengeProgress, challenge.targetCount))/\(challenge.targetCount)")
                        .font(.muckMicro)
                        .foregroundStyle(.white.opacity(0.8))
                        .fixedSize()
                }
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs + 2)
        .background(health.gradient)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .padding(.horizontal, Spacing.md)
    }
}
