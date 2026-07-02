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

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color.muckBg.ignoresSafeArea()

                VStack(spacing: 0) {
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

                    // Filter + sort bar
                    filterBar

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
        }
    }

    // MARK: - Sub-views

    private var filterBar: some View {
        HStack(spacing: 0) {
            // Type filters + external-events toggle — icon only
            HStack(spacing: Spacing.xs) {
                TypeFilterBar(selection: $muckVM.typeFilter, iconOnly: true)

                FilterPill(
                    title: "External Events",
                    icon: "building.2.fill",
                    iconOnly: true,
                    isActive: partnerVM.showOnHome,
                    activeColor: Color.muckAmber
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        partnerVM.showOnHome.toggle()
                    }
                }
            }

            Spacer()

            // Sort options — visually distinct from the filters above
            HStack(spacing: Spacing.xxs) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.muckNearBlack.opacity(0.35))

                HStack(spacing: 0) {
                    ForEach(MuckSortOrder.allCases, id: \.self) { order in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                muckVM.sortOrder = order
                            }
                        } label: {
                            Image(systemName: order.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(muckVM.sortOrder == order ? .white : .muckNearBlack.opacity(0.6))
                                .frame(width: 28, height: 24)
                                .background(muckVM.sortOrder == order ? Color.muckNearBlack : Color.clear)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(order.displayName)
                    }
                }
                .padding(3)
                .background(Color.muckSurface)
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(Color.muckNearBlack.opacity(0.1), lineWidth: 1)
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
