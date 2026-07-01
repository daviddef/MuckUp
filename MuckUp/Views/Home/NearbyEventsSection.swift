import SwiftUI
import CoreLocation

/// Horizontal carousel of upcoming events near the user, shown on Home.
/// Events happening within the next few days are visually flagged as "Soon".
struct NearbyEventsSection: View {
    let events: [MuckEvent]
    let userLocation: CLLocation?
    let onSelect: (MuckEvent) -> Void

    private let soonWindowDays = 3
    private let nearbyRadiusMetres: Double = 30_000  // 30 km — events are worth travelling for

    private var upcoming: [MuckEvent] {
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
            .sorted { a, b in
                if a.isLive != b.isLive { return a.isLive }
                return a.eventDate < b.eventDate
            }
    }

    private func isSoon(_ event: MuckEvent) -> Bool {
        guard !event.isLive else { return true }
        let days = Calendar.current.dateComponents([.day], from: .now, to: event.eventDate).day ?? 999
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
                        ForEach(upcoming) { event in
                            NearbyEventCard(
                                event: event,
                                isSoon: isSoon(event),
                                distance: distanceLabel(for: event)
                            )
                            .onTapGesture { onSelect(event) }
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                }
            }
            .padding(.bottom, Spacing.sm)
        }
    }

    private func distanceLabel(for event: MuckEvent) -> String? {
        guard let userLocation, event.meetupLatitude != 0 || event.meetupLongitude != 0 else { return nil }
        let loc = CLLocation(latitude: event.meetupLatitude, longitude: event.meetupLongitude)
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
