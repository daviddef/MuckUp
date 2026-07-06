import SwiftUI

struct WeeklyChallengeCard: View {
    let challenge: WeeklyChallenge
    let progressCount: Int

    private var fraction: Double {
        guard challenge.targetCount > 0 else { return 0 }
        return min(1, Double(progressCount) / Double(challenge.targetCount))
    }

    private var isComplete: Bool { progressCount >= challenge.targetCount }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .fill(Color.muckTypeColor(challenge.type).opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: isComplete ? "checkmark.seal.fill" : challenge.type.icon)
                    .foregroundStyle(Color.muckTypeColor(challenge.type))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: Spacing.xxs) {
                    Text("THIS WEEK")
                        .font(.muckMicro)
                        .foregroundStyle(Color.muckNearBlack.opacity(0.4))
                    if isComplete {
                        Text("· Complete!")
                            .font(.muckMicro)
                            .foregroundStyle(Color.muckGreen)
                    }
                }
                Text(challenge.title)
                    .font(.muckHeadline)
                    .foregroundStyle(Color.muckNearBlack)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.muckNearBlack.opacity(0.08))
                        Capsule()
                            .fill(isComplete ? Color.muckGreen : Color.muckTypeColor(challenge.type))
                            .frame(width: geo.size.width * fraction)
                    }
                }
                .frame(height: 6)

                Text("\(min(progressCount, challenge.targetCount)) / \(challenge.targetCount)")
                    .font(.muckMicro)
                    .foregroundStyle(Color.muckNearBlack.opacity(0.4))
            }
        }
        .padding(Spacing.sm)
        .background(Color.muckSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .padding(.horizontal, Spacing.md)
        .muckCardShadow()
    }
}
