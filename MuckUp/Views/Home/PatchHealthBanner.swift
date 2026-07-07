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

struct PatchHealthBanner: View {
    let health: PatchHealth
    let openHazards: Int
    var stage: GrubLifecycleStage = .grub

    private var mood: GrubMood {
        if openHazards > 0 && health == .barren { return .concerned }
        if health == .thriving { return .celebrating }
        return .idle
    }

    var body: some View {
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
        .padding(Spacing.sm)
        .background(health.gradient)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .padding(.horizontal, Spacing.md)
    }
}
