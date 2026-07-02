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

    private var mucks: [Muck] {
        let base = muckVM.filtered(allMucks)
        guard let mapCentre else { return base }
        let centreLoc = CLLocation(latitude: mapCentre.latitude, longitude: mapCentre.longitude)
        return base
            .filter { muck in
                let loc = CLLocation(latitude: muck.latitude, longitude: muck.longitude)
                return loc.distance(from: centreLoc) <= mapRadiusMetres
            }
            .sorted { a, b in
                let da = CLLocation(latitude: a.latitude, longitude: a.longitude).distance(from: centreLoc)
                let db = CLLocation(latitude: b.latitude, longitude: b.longitude).distance(from: centreLoc)
                return da < db
            }
    }

    // External Find items (World Cleanup, TrashMob, Litter Map, etc.) —
    // included on the mini map and "Events near you" by default, hidden
    // when the external-events icon at the top of Home is toggled off.
    private var visiblePartnerItems: [PartnerItem] {
        guard partnerVM.showOnHome else { return [] }
        return partnerVM.items.filter { partnerVM.enabledSources.contains($0.source) }
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

    // "Things to be aware of" under the Hazard filter — waterway safety
    // and planned burns are already fully loaded (Brisbane-wide, not a
    // per-location fetch), so this is a plain client-side distance filter
    // against whatever area the mini map is currently showing. Animal
    // complaints aren't included here (suburb+quarter lookup, better
    // suited to a fixed point like an event's meetup pin than a map that
    // pans continuously).
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

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color.muckBg.ignoresSafeArea(edges: .bottom)

                VStack(spacing: 0) {
                    // Filter + sort bar — sits above the map so filtering
                    // is the first thing you see, and applies to the map,
                    // "Events near you", and the list below all at once
                    filterBar

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

                    // Upcoming events near you
                    NearbyEventsSection(
                        events: allEvents,
                        partnerItems: visiblePartnerItems,
                        userLocation: locationService.location,
                        onSelectEvent: { selectedEvent = $0 },
                        onSelectPartnerItem: { selectedPartnerItem = $0 }
                    )

                    // "Things to be aware of" — always shown under the Hazard filter
                    if muckVM.typeFilter == .hazard && !nearbyAwarenessForHome.isEmpty {
                        AwarenessListCard(
                            items: nearbyAwarenessForHome,
                            isLoading: false,
                            onSelect: { selectedAwarenessItem = $0 }
                        )
                        .padding(.horizontal, Spacing.md)
                        .padding(.bottom, Spacing.sm)
                    }

                    // List
                    if mucks.isEmpty {
                        emptyState
                    } else {
                        muckList
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

    private var muckList: some View {
        List {
            ForEach(mucks) { muck in
                MuckCardView(
                    muck: muck,
                    hasVoted: !muckVM.canVote(muck),
                    onVote: { muckVM.upvote(muck) },
                    userLocation: locationService.location
                )
                .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.md, bottom: Spacing.xs, trailing: Spacing.md))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .onTapGesture { selectedMuck = muck }
            }
        }
        .listStyle(.plain)
        .refreshable {
            // Refresh hook — live data fetch will go here
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            EmptyStateIllustration()
            Text("No mucks here")
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
            return "No mucks in this part of the map. Try panning around."
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

            // Points badge
            HStack(spacing: Spacing.xxs) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10, weight: .bold))
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
