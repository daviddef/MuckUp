import SwiftUI
import SwiftData

struct ProfileView: View {
    @Query private var allMucks: [Muck]
    @Query private var allEvents: [MuckEvent]
    @EnvironmentObject var muckVM: MuckViewModel
    @EnvironmentObject var eventVM: EventViewModel

    @State private var selectedTab = 0

    private var myMucks: [Muck] {
        let ids = Set(muckVM.raisedMuckIds)
        return allMucks.filter { ids.contains($0.id) }
            .sorted { $0.reportedDate > $1.reportedDate }
    }

    private var myClosedMucks: [Muck] {
        let ids = Set(muckVM.closedMuckIds)
        return allMucks.filter { ids.contains($0.id) }
    }

    private var myAttendedEvents: [MuckEvent] {
        let ids = Set(eventVM.attendedEventIds)
        return allEvents.filter { ids.contains($0.id) }
    }

    private var favMucks: [Muck] {
        let ids = StorageService.shared.loadFavouriteMucks(for: muckVM.userId)
        return allMucks.filter { ids.contains($0.id) }
    }
    private var favEvents: [MuckEvent] {
        let ids = StorageService.shared.loadFavouriteEvents(for: eventVM.userId)
        return allEvents.filter { ids.contains($0.id) }
    }

    private var totalBagsCollected: Int {
        myAttendedEvents.reduce(0) { $0 + $1.bagCount }
    }

    private var totalKgDiverted: Int {
        totalBagsCollected * 3
    }

    private var historyItems: [HistoryItem] {
        var items: [HistoryItem] = []
        items += myMucks.map { .init(date: $0.reportedDate, kind: .raised($0)) }
        items += myClosedMucks.compactMap { muck in
            guard let date = muck.closedDate else { return nil }
            return HistoryItem(date: date, kind: .closed(muck))
        }
        items += myAttendedEvents.map { .init(date: $0.eventDate, kind: .attended($0)) }
        return items.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                heroSection
                impactGrid

                // Tab picker
                Picker("", selection: $selectedTab) {
                    Text("History").tag(0)
                    Text("My Mucks").tag(1)
                    Text("⭐ Saved").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(Spacing.md)

                TabView(selection: $selectedTab) {
                    historyTab.tag(0)
                    muckListTab(mucks: myMucks, emptyText: "You haven't raised any mucks yet.").tag(1)
                    savedTab.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .background(Color.muckBg)
            .navigationTitle("My Profile")
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Muck Points")
                    .font(.muckCaption)
                    .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(Color.muckAmber)
                    Text("\(muckVM.points)")
                        .font(.muckDisplay)
                        .foregroundStyle(Color.muckNearBlack)
                }

                if muckVM.streak > 0 {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                        Text("\(muckVM.streak) day streak")
                            .font(.muckCaption)
                    }
                    .foregroundStyle(Color.muckRed)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, 3)
                    .background(Color.muckRed.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
            Spacer()
            Image(systemName: "person.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.muckNearBlack.opacity(0.2))
        }
        .padding(Spacing.md)
        .background(Color.muckSurface)
    }

    // MARK: - Impact grid

    private var impactGrid: some View {
        HStack(spacing: 1) {
            ImpactStatTile(icon: "mappin.circle.fill", value: "\(myMucks.count)", label: "Raised")
            ImpactStatTile(icon: "checkmark.seal.fill", value: "\(myClosedMucks.count)", label: "Cleared")
            ImpactStatTile(icon: "bag.fill", value: "\(totalBagsCollected)", label: "Bags")
            ImpactStatTile(icon: "scalemass.fill", value: "\(totalKgDiverted)kg", label: "Diverted")
        }
        .background(Color.muckNearBlack.opacity(0.06))
    }

    // MARK: - History tab

    private var historyTab: some View {
        Group {
            if historyItems.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.muckNearBlack.opacity(0.2))
                    Text("Your activity will show up here.")
                        .font(.muckBody)
                        .foregroundStyle(Color.muckNearBlack.opacity(0.4))
                        .padding(.top, Spacing.xs)
                    Spacer()
                }
            } else {
                List(historyItems) { item in
                    HistoryRow(item: item)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.md, bottom: Spacing.xs, trailing: Spacing.md))
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Saved tab (mucks + events combined)

    private var savedTab: some View {
        Group {
            if favMucks.isEmpty && favEvents.isEmpty {
                VStack {
                    Spacer()
                    Text("No saved items yet.")
                        .font(.muckBody)
                        .foregroundStyle(Color.muckNearBlack.opacity(0.4))
                    Spacer()
                }
            } else {
                List {
                    if !favMucks.isEmpty {
                        Section("Mucks") {
                            ForEach(favMucks) { muck in
                                MuckCardView(muck: muck, hasVoted: !muckVM.canVote(muck), onVote: {})
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.md, bottom: Spacing.xs, trailing: Spacing.md))
                            }
                        }
                    }
                    if !favEvents.isEmpty {
                        Section("Events") {
                            ForEach(favEvents) { event in
                                EventRowView(event: event)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.md, bottom: Spacing.xs, trailing: Spacing.md))
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func muckListTab(mucks: [Muck], emptyText: String) -> some View {
        if mucks.isEmpty {
            VStack {
                Spacer()
                Text(emptyText)
                    .font(.muckBody)
                    .foregroundStyle(Color.muckNearBlack.opacity(0.4))
                Spacer()
            }
        } else {
            List {
                ForEach(mucks) { muck in
                    MuckCardView(muck: muck, hasVoted: !muckVM.canVote(muck), onVote: {})
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.md, bottom: Spacing.xs, trailing: Spacing.md))
                }
            }
            .listStyle(.plain)
        }
    }
}

// MARK: - Impact stat tile

private struct ImpactStatTile: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.muckGreen)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color.muckNearBlack)
            Text(label)
                .font(.muckMicro)
                .foregroundStyle(Color.muckNearBlack.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .background(Color.muckSurface)
    }
}

// MARK: - History model + row

private struct HistoryItem: Identifiable {
    let date: Date
    let kind: Kind

    enum Kind {
        case raised(Muck)
        case closed(Muck)
        case attended(MuckEvent)
    }

    var id: String {
        switch kind {
        case .raised(let m):   return "raised-\(m.id)"
        case .closed(let m):   return "closed-\(m.id)"
        case .attended(let e): return "attended-\(e.id)"
        }
    }
}

private struct HistoryRow: View {
    let item: HistoryItem

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(iconColor)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.muckHeadline)
                    .foregroundStyle(Color.muckNearBlack)
                Text(subtitle)
                    .font(.muckCaption)
                    .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                    .lineLimit(1)
            }
            Spacer()
            Text(item.date, style: .date)
                .font(.muckMicro)
                .foregroundStyle(Color.muckNearBlack.opacity(0.35))
        }
        .padding(Spacing.sm)
        .background(Color.muckSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
    }

    private var icon: String {
        switch item.kind {
        case .raised:   return "flag.fill"
        case .closed:   return "checkmark.seal.fill"
        case .attended: return "calendar"
        }
    }

    private var iconColor: Color {
        switch item.kind {
        case .raised:   return Color.muckAmber
        case .closed:   return Color.muckGreen
        case .attended: return Color.muckGreen
        }
    }

    private var title: String {
        switch item.kind {
        case .raised:   return "Raised a muck"
        case .closed:   return "Cleared a muck"
        case .attended: return "Attended an event"
        }
    }

    private var subtitle: String {
        switch item.kind {
        case .raised(let m):   return m.location
        case .closed(let m):   return m.location
        case .attended(let e): return e.title
        }
    }
}
