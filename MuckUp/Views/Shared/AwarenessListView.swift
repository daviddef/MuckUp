import SwiftUI

/// A single "thing to be aware of" row — waterway safety, planned burn,
/// or animal complaint summary. Shared across Schedule Event, Home, and
/// event detail/live screens so the presentation stays consistent
/// wherever awareness data shows up.
struct AwarenessRow: View {
    let item: AwarenessItem

    private var color: Color {
        switch item.severity {
        case .warning: return .muckRed
        case .caution: return .muckAmber
        case .info:    return .muckGreen
        }
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: item.category.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.muckHeadline)
                    .foregroundStyle(Color.muckNearBlack)
                Text(item.detail)
                    .font(.muckCaption)
                    .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                    .lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11))
                .foregroundStyle(Color.muckNearBlack.opacity(0.25))
        }
        .padding(.vertical, Spacing.xxs)
    }
}

/// Card-style "⚠️ Things to be aware of in this area" block — used
/// outside of a List (Home, event screens). ScheduleEventView renders
/// its own List Section using AwarenessRow directly since it needs
/// List-specific chrome (headers/footers), but this wraps the same
/// rows in a plain card for contexts that aren't already inside a List.
struct AwarenessListCard: View {
    let items: [AwarenessItem]
    let isLoading: Bool
    let onSelect: (AwarenessItem) -> Void
    var title: String = "⚠️ Things to be aware of"
    var emptyText: String? = nil

    // Capped so a busy area (e.g. a dozen+ planned burns) can't push the
    // rest of the screen off-viewport with no way to scroll back to it —
    // beyond this many rows, the card scrolls internally instead.
    private let maxVisibleRows = 4
    private let rowHeight: CGFloat = 62

    var body: some View {
        if isLoading || !items.isEmpty || emptyText != nil {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(.muckTitle)
                    .foregroundStyle(Color.muckNearBlack)

                if isLoading {
                    HStack(spacing: Spacing.xs) {
                        ProgressView().tint(Color.muckGreen)
                        Text("Checking the area…")
                            .font(.muckBody)
                            .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                    }
                    .padding(Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.muckSurface)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                } else if items.isEmpty {
                    if let emptyText {
                        Text(emptyText)
                            .font(.muckBody)
                            .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                            .padding(Spacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.muckSurface)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 1) {
                            ForEach(items) { item in
                                Button {
                                    onSelect(item)
                                } label: {
                                    AwarenessRow(item: item)
                                        .padding(.horizontal, Spacing.sm)
                                }
                                .buttonStyle(.plain)
                                .background(Color.muckSurface)
                            }
                        }
                    }
                    .frame(height: min(CGFloat(items.count), CGFloat(maxVisibleRows)) * rowHeight)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))

                    if items.count > maxVisibleRows {
                        Text("\(items.count) total — scroll for more")
                            .font(.muckMicro)
                            .foregroundStyle(Color.muckNearBlack.opacity(0.4))
                    }
                }
            }
        }
    }
}
