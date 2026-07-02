import SwiftUI
import CoreLocation

/// Unified activity feed — replaces Home's separate mini-map-list,
/// "Events near you" carousel, and plain muck list with one chronological
/// stream. Mucks, events, external partner items, and (when the Hazard
/// filter is active) area-awareness alerts all render as the same kind
/// of row, so "what's happening near me" reads as one feed instead of
/// four competing sections.
enum HomeActivityItem: Identifiable {
    case muck(Muck)
    case event(MuckEvent)
    case partner(PartnerItem)
    case awareness(AwarenessItem)

    var id: String {
        switch self {
        case .muck(let m):      return "muck-\(m.id)"
        case .event(let e):     return "event-\(e.id)"
        case .partner(let p):   return "partner-\(p.id)"
        case .awareness(let a): return "awareness-\(a.id)"
        }
    }

    /// Most recent moment this item became relevant — a just-cleared
    /// muck bubbles up like a fresh post, not buried at its original
    /// report date.
    var activityDate: Date {
        switch self {
        case .muck(let m):      return m.closedDate ?? m.reportedDate
        case .event(let e):     return e.isLive ? .now : e.eventDate
        case .partner(let p):   return p.date ?? .distantPast
        case .awareness:        return .now
        }
    }

    var popularityScore: Int {
        switch self {
        case .muck(let m):    return m.votes
        case .event(let e):   return e.participants
        case .partner(let p): return p.attendees ?? 0
        case .awareness(let a): return a.severity == .warning ? 1000 : a.severity == .caution ? 500 : 0
        }
    }

    var isLive: Bool {
        if case .event(let e) = self { return e.isLive }
        return false
    }

    // Awareness items are standing conditions, not "activity" — always
    // float to the top when present so warnings aren't buried by an old
    // popular muck.
    var isPriority: Bool {
        if case .awareness = self { return true }
        return false
    }
}

struct HomeActivityFeed: View {
    let items: [HomeActivityItem]
    let userLocation: CLLocation?
    let onSelect: (HomeActivityItem) -> Void

    var body: some View {
        List(items) { item in
            ActivityFeedRow(item: item, userLocation: userLocation)
                .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.md, bottom: Spacing.xs, trailing: Spacing.md))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .onTapGesture { onSelect(item) }
        }
        .listStyle(.plain)
    }
}

private struct ActivityFeedRow: View {
    let item: HomeActivityItem
    let userLocation: CLLocation?

    var body: some View {
        switch item {
        case .muck(let muck):
            MuckFeedCard(muck: muck, userLocation: userLocation)
        case .event(let event):
            EventFeedCard(event: event)
        case .partner(let partnerItem):
            PartnerFeedCard(item: partnerItem)
        case .awareness(let awarenessItem):
            AwarenessRow(item: awarenessItem)
                .padding(Spacing.sm)
                .background(Color.muckSurface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                .muckCardShadow()
        }
    }
}

// MARK: - Muck feed card (compact — full detail is one tap away)

private struct MuckFeedCard: View {
    let muck: Muck
    let userLocation: CLLocation?

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .fill(Color.muckTypeColor(muck.type).opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: muck.type.icon)
                    .font(.system(size: 17))
                    .foregroundStyle(Color.muckTypeColor(muck.type))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Spacing.xxs) {
                    Text(muck.isClosed ? "Cleared" : "Raised")
                        .font(.muckMicro)
                        .foregroundStyle(muck.isClosed ? Color.muckGreen : Color.muckNearBlack.opacity(0.4))
                    if muck.isHazardous {
                        Label("Hazardous", systemImage: "exclamationmark.triangle.fill")
                            .font(.muckMicro)
                            .foregroundStyle(Color.muckRed)
                    }
                }
                Text(muck.location)
                    .font(.muckHeadline)
                    .foregroundStyle(Color.muckNearBlack)
                    .lineLimit(1)
                Text(muck.muckDescription)
                    .font(.muckBody)
                    .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Label("\(muck.votes)", systemImage: "arrow.up")
                    .font(.muckMicro)
                    .foregroundStyle(Color.muckNearBlack.opacity(0.4))
                if let distance = muck.distance(from: userLocation) {
                    Text(distance)
                        .font(.muckMicro)
                        .foregroundStyle(Color.muckNearBlack.opacity(0.35))
                }
            }
        }
        .padding(Spacing.sm)
        .background(muck.isClosed ? Color.muckGreen.opacity(0.05) : Color.muckSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .muckCardShadow()
    }
}

// MARK: - Event feed card

private struct EventFeedCard: View {
    let event: MuckEvent

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .fill((event.isLive ? Color.muckRed : Color.muckAmber).opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "calendar")
                    .font(.system(size: 17))
                    .foregroundStyle(event.isLive ? Color.muckRed : Color.muckAmber)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Spacing.xxs) {
                    Text(event.isLive ? "LIVE NOW" : event.isToday ? "TODAY" : "EVENT")
                        .font(.muckMicro)
                        .foregroundStyle(event.isLive ? Color.muckRed : Color.muckAmber)
                    if event.isAttending {
                        Label("Going", systemImage: "checkmark.circle.fill")
                            .font(.muckMicro)
                            .foregroundStyle(Color.muckGreen)
                    }
                }
                Text(event.title)
                    .font(.muckHeadline)
                    .foregroundStyle(Color.muckNearBlack)
                    .lineLimit(1)
                Text(event.eventDate, style: .date)
                    .font(.muckBody)
                    .foregroundStyle(Color.muckNearBlack.opacity(0.5))
            }

            Spacer()

            Label("\(event.participants)", systemImage: "person.2.fill")
                .font(.muckMicro)
                .foregroundStyle(Color.muckNearBlack.opacity(0.4))
        }
        .padding(Spacing.sm)
        .background(event.isAttending ? Color.muckGreen.opacity(0.05) : Color.muckSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .strokeBorder(event.isLive ? Color.muckRed.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
        .muckCardShadow()
    }
}

// MARK: - Partner feed card

private struct PartnerFeedCard: View {
    let item: PartnerItem

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .fill(Color.partnerColor(item.source).opacity(0.12))
                    .frame(width: 44, height: 44)
                Text(item.source.emoji)
                    .font(.system(size: 18))
            }

            VStack(alignment: .leading, spacing: 2) {
                SourceBadgeView(source: item.source)
                Text(item.name)
                    .font(.muckHeadline)
                    .foregroundStyle(Color.muckNearBlack)
                    .lineLimit(1)
                if let displayDate = item.displayDate {
                    Text(displayDate)
                        .font(.muckBody)
                        .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                }
            }

            Spacer()

            Image(systemName: "arrow.up.right")
                .font(.system(size: 12))
                .foregroundStyle(Color.muckNearBlack.opacity(0.25))
        }
        .padding(Spacing.sm)
        .background(Color.muckSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .muckCardShadow()
    }
}
