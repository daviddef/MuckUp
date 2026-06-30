import SwiftUI
import CoreLocation

struct MuckCardView: View {
    let muck: Muck
    let hasVoted: Bool
    let onVote: () -> Void
    var userLocation: CLLocation? = nil

    var body: some View {
        HStack(spacing: 0) {
            // Vote column — separate tap target
            VoteColumnView(votes: muck.votes, hasVoted: hasVoted, action: onVote)
                .background(Color.muckBg)

            Divider()
                .frame(height: 56)
                .padding(.vertical, Spacing.sm)

            // Card body
            VStack(alignment: .leading, spacing: Spacing.xxs) {

                // Type + hazard badge row
                HStack(spacing: Spacing.xs) {
                    TypeBadgeView(type: muck.type)
                    if muck.isHazardous {
                        HStack(spacing: Spacing.xxxs) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 9))
                            Text("HAZARDOUS")
                                .font(.muckMicro)
                        }
                        .foregroundStyle(Color.muckRed)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 2)
                        .background(Color.muckRed.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    Spacer()
                    if muck.eventCount > 0 {
                        HStack(spacing: Spacing.xxxs) {
                            Image(systemName: "calendar")
                                .font(.system(size: 9))
                            Text("\(muck.eventCount)")
                                .font(.muckMicro)
                        }
                        .foregroundStyle(Color.muckAmber)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 2)
                        .background(Color.muckAmber.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }

                // Location
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "mappin")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                    Text(muck.location)
                        .font(.muckHeadline)
                        .foregroundStyle(Color.muckNearBlack)
                        .lineLimit(1)
                }

                // Description
                Text(muck.muckDescription)
                    .font(.muckBody)
                    .foregroundStyle(Color.muckNearBlack.opacity(0.65))
                    .lineLimit(2)

                // Footer row
                HStack {
                    if let distance = muck.distance(from: userLocation) {
                        Text(distance)
                            .font(.muckCaption)
                            .foregroundStyle(Color.muckNearBlack.opacity(0.4))
                    }
                    Text(muck.reportedDate.relativeFormatted)
                        .font(.muckCaption)
                        .foregroundStyle(Color.muckNearBlack.opacity(0.4))
                    Spacer()
                    Text(muck.id)
                        .font(.muckMicro)
                        .foregroundStyle(Color.muckNearBlack.opacity(0.25))
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.muckSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .muckCardShadow()
    }
}

// MARK: - Date helper

private extension Date {
    var relativeFormatted: String {
        let diff = Calendar.current.dateComponents([.day, .hour], from: self, to: .now)
        if let days = diff.day, days > 0 {
            return days == 1 ? "1 day ago" : "\(days) days ago"
        } else if let hours = diff.hour, hours > 0 {
            return "\(hours)h ago"
        } else {
            return "Just now"
        }
    }
}

#Preview {
    let muck = Muck.mockData[0]
    MuckCardView(muck: muck, hasVoted: false, onVote: {})
        .padding()
        .background(Color.muckBg)
}
