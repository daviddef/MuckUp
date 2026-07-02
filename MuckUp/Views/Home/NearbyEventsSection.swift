import SwiftUI
import CoreLocation

/// Horizontal carousel of upcoming events (and, unless filtered out at the
/// top of Home, external Find items) near the user. Items happening within
/// the next few days are visually flagged as "Soon".
struct NearbyEventsSection: View {
    let events: [MuckEvent]
    let partnerItems: [PartnerItem]
    let userLocation: CLLocation?
    let onSelectEvent: (MuckEvent) -> Void
    let onSelectPartnerItem: (PartnerItem) -> Void

    private let soonWindowDays = 3
    private let nearbyRadiusMetres: Double = 30_000  // 30 km — events are worth travelling for

    private enum NearbyItem: Identifiable {
        case event(MuckEvent)
        case partner(PartnerItem)

        var id: String {
            switch self {
            case .event(let e):   return "event-\(e.id)"
            case .partner(let p): return "partner-\(p.id)"
            }
        }

        var date: Date {
            switch self {
            case .event(let e):   return e.eventDate
            case .partner(let p): return p.date ?? .distantFuture
            }
        }

        var isLive: Bool {
            if case .event(let e) = self { return e.isLive }
            return false
        }
    }

    private var upcomingEvents: [MuckEvent] {
        let now = Date.now
        return events
            .filter { $0.eventDate >= now || $0.isLive }
            .filter { event in
                guard let userLocation else { return true }
                let loc = CLLocation(latitude: event.meetupLatitude, longitude: event.meetupLongitude)
                // meetupLatitude/Longitude default to 0,0 when unset — don't
                // let unset events get filtered out by a bogus distance
                guard event.meetupLatitude != 0 || event.meetupLongitude != 0 else { return true }
                return loc.distance(from: userLocation) <= nearbyRadiusMetres
            }
    }

    private var upcomingPartnerItems: [PartnerItem] {
        let now = Date.now
        return partnerItems
            .filter { ($0.date ?? now) >= now }
            .filter { item in
                guard let userLocation else { return true }
                let loc = CLLocation(latitude: item.latitude, longitude: item.longitude)
                return loc.distance(from: userLocation) <= nearbyRadiusMetres
            }
    }

    private var upcoming: [NearbyItem] {
        let merged = upcomingEvents.map { NearbyItem.event($0) } + upcomingPartnerItems.map { NearbyItem.partner($0) }
        return merged.sorted { a, b in
            if a.isLive != b.isLive { return a.isLive }
            return a.date < b.date
        }
    }

    private func isSoon(_ date: Date, isLive: Bool) -> Bool {
        guard !isLive else { return true }
        let days = Calendar.current.dateComponents([.day], from: .now, to: date).day ?? 999
        return days >= 0 && days <= soonWindowDays
    }

    var body: some View {
        if !upcoming.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Events near you")
                    .font(.muckTitle)
                    .foregroundStyle(Color.muckNearBlack)
                    .padding(.horizontal, Spacing.md)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        ForEach(upcoming) { item in
                            switch item {
                            case .event(let event):
                                NearbyEventCard(
                                    event: event,
                                    isSoon: isSoon(event.eventDate, isLive: event.isLive),
                                    distance: distanceLabel(latitude: event.meetupLatitude, longitude: event.meetupLongitude)
                                )
                                .onTapGesture { onSelectEvent(event) }
                            case .partner(let partnerItem):
                                NearbyPartnerCard(
                                    item: partnerItem,
                                    isSoon: isSoon(partnerItem.date ?? .distantFuture, isLive: false),
                                    distance: distanceLabel(latitude: partnerItem.latitude, longitude: partnerItem.longitude)
                                )
                                .onTapGesture { onSelectPartnerItem(partnerItem) }
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                }
            }
            .padding(.bottom, Spacing.sm)
        }
    }

    private func distanceLabel(latitude: Double, longitude: Double) -> String? {
        guard let userLocation, latitude != 0 || longitude != 0 else { return nil }
        let loc = CLLocation(latitude: latitude, longitude: longitude)
        let metres = loc.distance(from: userLocation)
        return metres < 1000 ? "\(Int(metres))m" : String(format: "%.1fkm", metres / 1000)
    }
}

private struct NearbyEventCard: View {
    let event: MuckEvent
    let isSoon: Bool
    let distance: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack {
                if event.isLive {
                    Label("LIVE", systemImage: "circle.fill")
                        .font(.muckMicro)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 2)
                        .background(Color.muckRed)
                        .clipShape(Capsule())
                } else if isSoon {
                    Text("SOON")
                        .font(.muckMicro)
                        .foregroundStyle(Color.muckAmber)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 2)
                        .background(Color.muckAmber.opacity(0.15))
                        .clipShape(Capsule())
                }
                Spacer()
                if event.isAttending {
                    Label("Going", systemImage: "checkmark.circle.fill")
                        .font(.muckMicro)
                        .foregroundStyle(Color.muckGreen)
                }
                if let distance {
                    Text(distance)
                        .font(.muckMicro)
                        .foregroundStyle(Color.muckNearBlack.opacity(0.35))
                }
            }

            Text(event.title)
                .font(.muckHeadline)
                .foregroundStyle(Color.muckNearBlack)
                .lineLimit(1)

            Text(event.eventDate, style: .date)
                .font(.muckCaption)
                .foregroundStyle(isSoon ? Color.muckAmber : Color.muckNearBlack.opacity(0.5))

            HStack(spacing: Spacing.xxs) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 10))
                Text("\(event.participants) going")
                    .font(.muckMicro)
            }
            .foregroundStyle(Color.muckNearBlack.opacity(0.4))
        }
        .padding(Spacing.sm)
        .frame(width: 190, alignment: .leading)
        .background(event.isAttending ? Color.muckGreen.opacity(0.06) : Color.muckSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .strokeBorder(borderColor, lineWidth: (isSoon || event.isAttending) ? 1.5 : 1)
        )
        .muckCardShadow()
    }

    private var borderColor: Color {
        if isSoon { return Color.muckAmber.opacity(0.4) }
        if event.isAttending { return Color.muckGreen.opacity(0.4) }
        return Color.muckNearBlack.opacity(0.08)
    }
}

private struct NearbyPartnerCard: View {
    let item: PartnerItem
    let isSoon: Bool
    let distance: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack {
                SourceBadgeView(source: item.source)
                Spacer()
                if let distance {
                    Text(distance)
                        .font(.muckMicro)
                        .foregroundStyle(Color.muckNearBlack.opacity(0.35))
                }
            }

            Text(item.name)
                .font(.muckHeadline)
                .foregroundStyle(Color.muckNearBlack)
                .lineLimit(1)

            if let displayDate = item.displayDate {
                Text(displayDate)
                    .font(.muckCaption)
                    .foregroundStyle(isSoon ? Color.muckAmber : Color.muckNearBlack.opacity(0.5))
            } else {
                Text("Ongoing")
                    .font(.muckCaption)
                    .foregroundStyle(Color.muckNearBlack.opacity(0.5))
            }
        }
        .padding(Spacing.sm)
        .frame(width: 190, alignment: .leading)
        .background(Color.muckSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .strokeBorder(isSoon ? Color.muckAmber.opacity(0.4) : Color.muckNearBlack.opacity(0.08), lineWidth: isSoon ? 1.5 : 1)
        )
        .muckCardShadow()
    }
}
