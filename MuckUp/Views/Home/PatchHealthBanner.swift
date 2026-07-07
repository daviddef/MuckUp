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
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                GrubCharacterView(stage: stage, mood: mood, size: 52)

                VStack(alignment: .leading, spacing: 2) {
                    Text(health.label)
                        .font(.muckHeadline)
                        .foregroundStyle(.white)
                    if openHazards > 0 {
                        Text("\(openHazards) hazard\(openHazards == 1 ? "" : "s") still need attention")
                            .font(.muckCaption)
                            .foregroundStyle(.white.opacity(0.85))
                    } else {
                        Text("Raise or clear a muck nearby to help it grow")
                            .font(.muckCaption)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                Spacer()
            }

            if let challenge {
                Divider().background(.white.opacity(0.25))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: Spacing.xxs) {
                        Text("THIS WEEK")
                            .font(.muckMicro)
                            .foregroundStyle(.white.opacity(0.7))
                        if isChallengeComplete {
                            Text("· Complete!")
                                .font(.muckMicro)
                                .foregroundStyle(.white)
                        }
                    }
                    Text(challenge.title)
                        .font(.muckCaption)
                        .foregroundStyle(.white)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.2))
                            Capsule().fill(.white)
                                .frame(width: geo.size.width * challengeFraction)
                        }
                    }
                    .frame(height: 5)

                    Text("\(min(challengeProgress, challenge.targetCount)) / \(challenge.targetCount)")
                        .font(.muckMicro)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .padding(Spacing.sm)
        .background(health.gradient)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .padding(.horizontal, Spacing.md)
    }
}
