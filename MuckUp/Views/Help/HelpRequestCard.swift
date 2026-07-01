import SwiftUI

struct HelpRequestCard: View {
    let request: HelpRequest
    let distance: String?
    let hasOffered: Bool

    private var isSoon: Bool {
        let days = Calendar.current.dateComponents([.day], from: .now, to: request.preferredDate).day ?? 999
        return days >= 0 && days <= 3
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .fill(Color.helpCategoryColor(request.category).opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: request.category.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(Color.helpCategoryColor(request.category))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(request.title)
                        .font(.muckHeadline)
                        .foregroundStyle(Color.muckNearBlack)
                        .lineLimit(1)
                    if isSoon {
                        Text("SOON")
                            .font(.muckMicro)
                            .foregroundStyle(Color.muckAmber)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.muckAmber.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                Text(request.requestDescription)
                    .font(.muckBody)
                    .foregroundStyle(Color.muckNearBlack.opacity(0.55))
                    .lineLimit(1)

                HStack(spacing: Spacing.xs) {
                    Label(request.preferredDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                    if let distance {
                        Label(distance, systemImage: "location.fill")
                    }
                    if !request.helperIds.isEmpty {
                        Label("\(request.helperIds.count) offered", systemImage: "hands.sparkles.fill")
                            .foregroundStyle(Color.muckGreen)
                    }
                }
                .font(.muckMicro)
                .foregroundStyle(Color.muckNearBlack.opacity(0.4))
            }

            Spacer()

            if hasOffered {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.muckGreen)
            }
        }
        .padding(Spacing.sm)
        .background(Color.muckSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .muckCardShadow()
    }
}
