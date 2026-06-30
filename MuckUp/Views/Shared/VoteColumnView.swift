import SwiftUI

struct VoteColumnView: View {
    let votes: Int
    let hasVoted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xxxs) {
                Image(systemName: hasVoted ? "arrowtriangle.up.fill" : "arrowtriangle.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(hasVoted ? Color.muckGreen : Color.muckNearBlack.opacity(0.4))
                Text("\(votes)")
                    .font(.muckCaption)
                    .foregroundStyle(hasVoted ? Color.muckGreen : Color.muckNearBlack)
                    .monospacedDigit()
            }
            .frame(width: 44)
            .padding(.vertical, Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(hasVoted ? "Voted — \(votes) votes" : "Upvote — \(votes) votes")
        .accessibilityHint(hasVoted ? "You have already voted" : "Double tap to upvote")
    }
}

#Preview {
    HStack {
        VoteColumnView(votes: 24, hasVoted: false, action: {})
        VoteColumnView(votes: 41, hasVoted: true, action: {})
    }
    .padding()
}
