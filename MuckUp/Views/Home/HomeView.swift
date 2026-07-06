import SwiftUI
import SwiftData
import CoreLocation

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allMucks: [Muck]
    @Query(sort: \MuckEvent.eventDate) private var allEvents: [MuckEvent]

    @EnvironmentObject var muckVM: MuckViewModel
    @EnvironmentObject var partnerVM: PartnerViewModel
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var awarenessVM: AwarenessViewModel

    @State private var showRaiseMuck = false
    @State private var selectedMuck: Muck? = nil
    @State private var selectedEvent: MuckEvent? = nil
    @State private var selectedPartnerItem: PartnerItem? = nil
    @State private var selectedAwarenessItem: AwarenessItem? = nil

    // Map-driven area filter — updated as the mini map is panned
    @State private var mapCentre: CLLocationCoordinate2D? = nil
    @State private var mapRadiusMetres: Double = 3000

    private let nearbyEventRadiusMetres: Double = 30_000
    private let patchRadiusMetres: Double = 5_000

    private var mucks: [Muck] {
        let base = muckVM.filtered(allMucks)
        guard let mapCentre else { return base }
        let centreLoc = CLLocation(latitude: mapCentre.latitude, longitude: mapCentre.longitude)
        return base.filter { muck in
            let loc = CLLocation(latitude: muck.latitude, longitude: muck.longitude)
            return loc.distance(from: centreLoc) <= mapRadiusMetres
        }
    }

    // External Find items (World Cleanup, TrashMob, Litter Map, etc.) —
    // included on the mini map and feed by default, hidden when the
    // external-events toggle in the Filters menu is switched off.
    private var visiblePartnerItems: [PartnerItem] {
        guard partnerVM.showOnHome else { return [] }
        return partnerVM.items.filter { partnerVM.enabledSources.contains($0.source) }
    }

    private var upcomingEvents: [MuckEvent] {
        let now = Date.now
        let centre = mapCentre ?? locationService.location?.coordinate
        return allEvents
            .filter { $0.eventDate >= now || $0.isLive }
            .filter { event in
                guard let centre else { return true }
                guard event.meetupLatitude != 0 || event.meetupLongitude != 0 else { return true }
                let loc = CLLocation(latitude: event.meetupLatitude, longitude: event.meetupLongitude)
                let centreLoc = CLLocation(latitude: centre.latitude, longitude: centre.longitude)
                return loc.distance(from: centreLoc) <= nearbyEventRadiusMetres
            }
    }

    // A single live line that makes the data feel like something actually
    // happening, not a static form — bags collected + mucks cleared in
    // the last 7 days, from data already loaded (no extra fetch).
    private var communityPulse: String? {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        let bags = allEvents
            .filter { ($0.endedDate ?? $0.eventDate) >= weekAgo }
            .reduce(0) { $0 + $1.bagCount }
        let cleared = allMucks.filter { muck in
            guard let closed = muck.closedDate else { return false }
            return closed >= weekAgo
        }.count

        guard bags > 0 || cleared > 0 else { return nil }
        var parts: [String] = []
        if bags > 0 { parts.append("\(bags) bag\(bags == 1 ? "" : "s") collected") }
        if cleared > 0 { parts.append("\(cleared) muck\(cleared == 1 ? "" : "s") cleared") }
        return parts.joined(separator: " · ") + " this week 🎉"
    }

    // Local mucks (all, not just the filtered/open set) within the patch
    // radius — used to score how "healthy" the area around you is.
    private var patchMucks: [Muck] {
        guard let centre = mapCentre ?? locationService.location?.coordinate else { return [] }
        let centreLoc = CLLocation(latitude: centre.latitude, longitude: centre.longitude)
        return allMucks.filter { muck in
            guard !muck.isHiddenByFlags else { return false }
            let loc = CLLocation(latitude: muck.latitude, longitude: muck.longitude)
            return loc.distance(from: centreLoc) <= patchRadiusMetres
        }
    }

    private var patchHealth: PatchHealth {
        let closed = patchMucks.filter(\.isClosed).count
        let open = patchMucks.count - closed
        let hazards = patchMucks.filter { !$0.isClosed && $0.isHazardous }.count
        return PatchHealth.score(openCount: open, closedCount: closed, openHazards: hazards)
    }

    private var patchOpenHazards: Int {
        patchMucks.filter { !$0.isClosed && $0.isHazardous }.count
    }

    // "Things to be aware of" under the Hazard filter — waterway safety
    // and planned burns are already fully loaded (Brisbane-wide, not a
    // per-location fetch), so this is a plain client-side distance filter
    // against whatever area the mini map is currently showing.
    private var nearbyAwarenessForHome: [AwarenessItem] {
        guard muckVM.typeFilter == .hazard else { return [] }
        guard let centre = mapCentre ?? locationService.location?.coordinate else {
            return awarenessVM.mapItems
        }
        let centreLoc = CLLocation(latitude: centre.latitude, longitude: centre.longitude)
        return awarenessVM.mapItems.filter { item in
            guard let coord = item.coordinate else { return false }
            let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            return loc.distance(from: centreLoc) <= 15_000
        }
    }

    // One unified, ordered stream — mucks, events, external items, and
    // hazard alerts all read as "activity" instead of four stacked,
    // independently-scrolling sections competing for the same screen.
    private var activityFeed: [HomeActivityItem] {
        var items: [HomeActivityItem] = []
        items += mucks.map { .muck($0) }
        items += upcomingEvents.map { .event($0) }
        items += visiblePartnerItems.map { .partner($0) }
        items += nearbyAwarenessForHome.map { .awareness($0) }

        return items.sorted { a, b in
            if a.isPriority != b.isPriority { return a.isPriority }
            if a.isLive != b.isLive { return a.isLive }
            switch muckVM.sortOrder {
            case .votes: return a.popularityScore > b.popularityScore
            case .date:  return a.activityDate > b.activityDate
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color.muckBg.ignoresSafeArea(edges: .bottom)

                VStack(spacing: 0) {
                    // Filter + sort bar — sits above the map so filtering
                    // is the first thing you see, and applies to the map
                    // and feed below all at once
                    filterBar

                    PatchHealthBanner(health: patchHealth, openHazards: patchOpenHazards)
                        .padding(.bottom, Spacing.xs)

                    if let communityPulse {
                        Text(communityPulse)
                            .font(.muckCaption)
                            .foregroundStyle(Color.muckGreen)
                            .padding(.horizontal, Spacing.md)
                            .padding(.bottom, Spacing.xs)
                            .transition(.opacity)
                    }

                    // Mini map — pan to browse a different area
                    HomeMiniMapView(
                        mucks: muckVM.filtered(allMucks),
                        partnerItems: visiblePartnerItems,
                        awarenessItems: muckVM.typeFilter == .hazard ? awarenessVM.mapItems : [],
                        userLocation: locationService.location,
                        onSelectMuck: { selectedMuck = $0 },
                        onSelectPartnerItem: { selectedPartnerItem = $0 },
                        onSelectAwarenessItem: { selectedAwarenessItem = $0 },
                        onRegionChange: { centre, radius in
                            mapCentre = centre
                            mapRadiusMetres = radius
                        }
                    )
                    .padding(.top, Spacing.xs)
                    .padding(.bottom, Spacing.sm)

                    // One unified activity feed
                    if activityFeed.isEmpty {
                        emptyState
                    } else {
                        HomeActivityFeed(
                            items: activityFeed,
                            userLocation: locationService.location,
                            onSelect: { item in
                                switch item {
                                case .muck(let muck):           selectedMuck = muck
                                case .event(let event):         selectedEvent = event
                                case .partner(let partnerItem): selectedPartnerItem = partnerItem
                                case .awareness(let item):      selectedAwarenessItem = item
                                }
                            }
                        )
                    }
                }

                // Floating action button
                fab
            }
            .navigationTitle("")
            .toolbar { toolbar }
            .sheet(isPresented: $showRaiseMuck) {
                RaiseMuckView()
            }
            .navigationDestination(item: $selectedMuck) { muck in
                ViewMuckView(muck: muck)
            }
            .navigationDestination(item: $selectedEvent) { event in
                if event.isToday || event.isLive {
                    EventLiveView(event: event)
                } else {
                    EventDetailView(event: event)
                }
            }
            .sheet(item: $selectedPartnerItem) { item in
                NavigationStack {
                    ScrollView {
                        PartnerItemRow(item: item)
                            .padding(Spacing.md)
                    }
                    .background(Color.muckBg)
                    .navigationTitle(item.source.displayName)
                    .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedAwarenessItem) { item in
                AwarenessDetailSheet(item: item)
            }
        }
        .task {
            if partnerVM.items.isEmpty {
                if let loc = locationService.location {
                    await partnerVM.fetchAll(near: loc)
                } else {
                    partnerVM.loadMockData()
                }
            }
            await awarenessVM.loadWaterwayData()
            await awarenessVM.loadBurnData()

            // Retry any local mucks that were raised offline or hit a
            // transient error before their public-database upload confirmed.
            await CloudKitMuckSyncService.shared.retryPendingUploads(allMucks)

            // Pull in mucks other users have raised nearby (shared public
            // database) and merge any not already present locally.
            if let loc = locationService.location {
                let remote = await CloudKitMuckSyncService.shared.fetchNearby(loc.coordinate, radiusMetres: 50_000)
                let localIds = Set(allMucks.map(\.id))
                for muck in remote where !localIds.contains(muck.id) {
                    modelContext.insert(muck)
                }
            }
        }
    }

    // MARK: - Sub-views

    // Just the 4 essentials up front; everything else (external events
    // toggle, sort order) lives one tap away in the Filters menu — the
    // top row is the first thing you see, so it should only show what
    // most people need most of the time.
    private var filterBar: some View {
        HStack(spacing: Spacing.xs) {
            TypeFilterBar(selection: $muckVM.typeFilter, iconOnly: true)

            Spacer()

            Menu {
                Toggle(isOn: $partnerVM.showOnHome) {
                    Label("External Events", systemImage: "building.2.fill")
                }

                Section("Sort by") {
                    ForEach(MuckSortOrder.allCases, id: \.self) { order in
                        Button {
                            muckVM.sortOrder = order
                        } label: {
                            Label(order.displayName, systemImage: order.icon)
                            if muckVM.sortOrder == order {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.muckNearBlack)
                    .frame(width: 36, height: 36)
                    .background(Color.muckSurface)
                    .clipShape(Circle())
                    .overlay(
                        Circle().strokeBorder(Color.muckNearBlack.opacity(0.12), lineWidth: 1)
                    )
            }
            .padding(.trailing, Spacing.md)
        }
        .padding(.top, Spacing.xs)
        .padding(.bottom, Spacing.sm)
        .background(Color.muckBg)
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            EmptyStateIllustration()
            Text("Nothing happening here yet")
                .font(.muckTitle)
                .foregroundStyle(Color.muckNearBlack)
            Text(emptyStateSubtitle)
                .font(.muckBody)
                .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(Spacing.xl)
    }

    private var emptyStateSubtitle: String {
        if muckVM.typeFilter != nil {
            return "Try removing the filter."
        } else if mapCentre != nil {
            return "Nothing in this part of the map. Try panning around."
        } else {
            return "Be the first to report an issue in your area."
        }
    }

    private var fab: some View {
        Button {
            showRaiseMuck = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.muckGreen)
                .clipShape(Circle())
                .muckFloatShadow()
        }
        .padding(.trailing, Spacing.lg)
        .padding(.bottom, Spacing.lg)
        .accessibilityLabel("Raise a Muck")
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Text("GRUB")
                .font(.muckDisplay)
                .foregroundStyle(Color.muckNearBlack)
        }

        ToolbarItemGroup(placement: .navigationBarTrailing) {
            NavigationLink(destination: MapViewScreen()) {
                Image(systemName: "map")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.muckNearBlack)
            }

            // Points + rank badge — surfaces rank on the daily screen
            // instead of it only ever being visible in Profile
            HStack(spacing: Spacing.xxs) {
                Text(muckVM.rank.emoji)
                    .font(.system(size: 11))
                Text("\(muckVM.points)")
                    .font(.muckCaption)
                    .monospacedDigit()
            }
            .foregroundStyle(Color.muckAmber)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.xxs)
            .background(Color.muckAmber.opacity(0.12))
            .clipShape(Capsule())
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(previewContainer)
        .environmentObject(MuckViewModel())
        .environmentObject(LocationService())
}
