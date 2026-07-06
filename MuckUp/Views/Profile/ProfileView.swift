import SwiftUI
import SwiftData

struct ProfileView: View {
    @Query private var allMucks: [Muck]
    @Query private var allEvents: [MuckEvent]
    @Query private var allHelpRequests: [HelpRequest]
    @EnvironmentObject var muckVM: MuckViewModel
    @EnvironmentObject var eventVM: EventViewModel
    @EnvironmentObject var authService: AuthService

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

    private var myPostedRequests: [HelpRequest] {
        let ids = Set(muckVM.postedHelpRequestIds)
        return allHelpRequests.filter { ids.contains($0.id) }
    }

    private var myOfferedRequests: [HelpRequest] {
        let ids = Set(muckVM.offeredHelpIds)
        return allHelpRequests.filter { ids.contains($0.id) }
    }

    private var myCompletedHelpCount: Int {
        muckVM.completedHelpIds.count
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

    // Lightweight badges derived from cumulative activity — a nudge toward
    // both lanes of community contribution, not a full achievements system.
    private var badges: [(emoji: String, label: String)] {
        var result: [(String, String)] = []
        if myClosedMucks.count >= 5 { result.append(("🌍", "Eco Warrior")) }
        if myOfferedRequests.count >= 3 { result.append(("🤝", "Good Neighbour")) }
        if muckVM.streak >= 7 { result.append(("🔥", "On Fire")) }
        return result
    }

    private var historyItems: [HistoryItem] {
        var items: [HistoryItem] = []
        items += myMucks.map { .init(date: $0.reportedDate, kind: .raised($0)) }
        items += myClosedMucks.compactMap { muck in
            guard let date = muck.closedDate else { return nil }
            return HistoryItem(date: date, kind: .closed(muck))
        }
        items += myAttendedEvents.map { .init(date: $0.eventDate, kind: .attended($0)) }
        items += myPostedRequests.map { .init(date: $0.createdDate, kind: .askedForHelp($0)) }
        items += myOfferedRequests.map { .init(date: $0.createdDate, kind: .offeredHelp($0)) }
        return items.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                heroSection
                impactGrid
                helpImpactGrid

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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if authService.isGuest {
                            Text("Guest mode — data stays on this device")
                        } else if let email = authService.currentUser?.email, !email.isEmpty {
                            Text(email)
                        }
                        Button("Sign Out", role: .destructive) {
                            authService.signOut()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(Color.muckNearBlack)
                    }
                }
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Muck Points")
                        .font(.muckCaption)
                        .foregroundStyle(.white.opacity(0.75))
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(.white)
                        Text("\(muckVM.points)")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: muckVM.points)
                    }

                    HStack(spacing: Spacing.xxs) {
                        Text(muckVM.rank.emoji)
                        Text(muckVM.rank.title)
                            .font(.muckCaption)
                    }
                    .foregroundStyle(.white.opacity(0.9))

                    if let toNext = muckVM.rank.pointsToNext(from: muckVM.points) {
                        VStack(alignment: .leading, spacing: 2) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(.white.opacity(0.2))
                                    Capsule().fill(.white)
                                        .frame(width: geo.size.width * muckVM.rank.progress(from: muckVM.points))
                                }
                            }
                            .frame(width: 110, height: 4)
                            Text("\(toNext) to \(muckVM.rank.next?.title ?? "")")
                                .font(.muckMicro)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(.top, 2)
                    }

                    if muckVM.streak > 0 {
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 12))
                            Text("\(muckVM.streak) day streak")
                                .font(.muckCaption)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.18))
                        .clipShape(Capsule())
                    }
                }
                Spacer()
                VStack(spacing: 2) {
                    GrowthPlantView(stage: PlantStage.forStreak(muckVM.streak), size: 56)
                    Text(PlantStage.forStreak(muckVM.streak).label)
                        .font(.muckMicro)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }

            if !badges.isEmpty {
                HStack(spacing: Spacing.sm) {
                    ForEach(badges, id: \.label) { badge in
                        StampBadgeView(emoji: badge.emoji, label: badge.label)
                    }
                }
                .padding(.top, Spacing.xxs)
            }
        }
        .padding(Spacing.md)
        .background(LinearGradient.muckGrowth)
    }

    // MARK: - Impact grids

    private var impactGrid: some View {
        VStack(spacing: 1) {
            Text("🌍 Help Us Cleanup")
                .font(.muckMicro)
                .foregroundStyle(Color.muckNearBlack.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.xs)
                .padding(.bottom, Spacing.xxxs)
                .background(Color.muckBg)

            HStack(spacing: 1) {
                ImpactStatTile(icon: "mappin.circle.fill", value: "\(myMucks.count)", label: "Raised")
                ImpactStatTile(icon: "checkmark.seal.fill", value: "\(myClosedMucks.count)", label: "Cleared")
                ImpactStatTile(icon: "bag.fill", value: "\(totalBagsCollected)", label: "Bags")
                ImpactStatTile(icon: "scalemass.fill", value: "\(totalKgDiverted)kg", label: "Diverted")
            }
        }
        .background(Color.muckNearBlack.opacity(0.06))
    }

    private var helpImpactGrid: some View {
        VStack(spacing: 1) {
            Text("🙋 Help Me")
                .font(.muckMicro)
                .foregroundStyle(Color.muckNearBlack.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.xs)
                .padding(.bottom, Spacing.xxxs)
                .background(Color.muckBg)

            HStack(spacing: 1) {
                ImpactStatTile(icon: "hand.raised.fill", value: "\(myPostedRequests.count)", label: "Asked")
                ImpactStatTile(icon: "hands.sparkles.fill", value: "\(myOfferedRequests.count)", label: "Offered")
                ImpactStatTile(icon: "person.fill.checkmark", value: "\(myCompletedHelpCount)", label: "Helped")
            }
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
        case askedForHelp(HelpRequest)
        case offeredHelp(HelpRequest)
    }

    var id: String {
        switch kind {
        case .raised(let m):        return "raised-\(m.id)"
        case .closed(let m):        return "closed-\(m.id)"
        case .attended(let e):      return "attended-\(e.id)"
        case .askedForHelp(let h):  return "asked-\(h.id)"
        case .offeredHelp(let h):   return "offered-\(h.id)"
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
        case .raised:        return "flag.fill"
        case .closed:        return "checkmark.seal.fill"
        case .attended:      return "calendar"
        case .askedForHelp:  return "hand.raised.fill"
        case .offeredHelp:   return "hands.sparkles.fill"
        }
    }

    private var iconColor: Color {
        switch item.kind {
        case .raised:        return Color.muckAmber
        case .closed:        return Color.muckGreen
        case .attended:      return Color.muckGreen
        case .askedForHelp:  return Color.helpCategoryColor(.other)
        case .offeredHelp:   return Color.muckGreen
        }
    }

    private var title: String {
        switch item.kind {
        case .raised:        return "Raised a muck"
        case .closed:        return "Cleared a muck"
        case .attended:      return "Attended an event"
        case .askedForHelp:  return "Asked for help"
        case .offeredHelp:   return "Offered to help"
        }
    }

    private var subtitle: String {
        switch item.kind {
        case .raised(let m):        return m.location
        case .closed(let m):        return m.location
        case .attended(let e):      return e.title
        case .askedForHelp(let h):  return h.title
        case .offeredHelp(let h):   return h.title
        }
    }
}
