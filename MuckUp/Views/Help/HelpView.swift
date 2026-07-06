import SwiftUI
import SwiftData
import CoreLocation
import MapKit

enum HelpLane: String, CaseIterable {
    case helpWorld, helpMe

    var title: String {
        switch self {
        case .helpWorld: return "🌍 Help Us Cleanup"
        case .helpMe:    return "🙋 Help Me"
        }
    }
}

struct HelpView: View {
    @Query private var allMucks: [Muck]
    @Query(sort: \MuckEvent.eventDate) private var allEvents: [MuckEvent]
    @Query private var allHelpRequests: [HelpRequest]

    @EnvironmentObject var muckVM: MuckViewModel
    @EnvironmentObject var helpVM: HelpViewModel
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var partnerVM: PartnerViewModel

    @State private var lane: HelpLane = .helpWorld
    @State private var showAskForHelp = false
    @State private var showRaiseMuck = false
    @State private var selectedRequest: HelpRequest?
    @State private var selectedGoldEvent: PartnerItem?
    @State private var showNearbyMucks = false
    @State private var showUpcomingEvents = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $lane) {
                    ForEach(HelpLane.allCases, id: \.self) { l in
                        Text(l.title).tag(l)
                    }
                }
                .pickerStyle(.segmented)
                .padding(Spacing.md)

                switch lane {
                case .helpWorld: helpWorldTab
                case .helpMe:    helpMeTab
                }
            }
            .background(Color.muckBg)
            .navigationTitle("Community")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showAskForHelp) {
                AskForHelpView()
            }
            .sheet(isPresented: $showRaiseMuck) {
                RaiseMuckView()
            }
            .sheet(isPresented: $showNearbyMucks) {
                NearbyMucksSheet(mucks: muckVM.filtered(allMucks))
            }
            .sheet(isPresented: $showUpcomingEvents) {
                UpcomingEventsSheet(events: allEvents.filter { !$0.isPast })
            }
            .navigationDestination(item: $selectedRequest) { request in
                HelpRequestDetailView(request: request)
            }
            .sheet(item: $selectedGoldEvent) { item in
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
        }
        .task {
            if partnerVM.items.isEmpty {
                if let loc = locationService.location {
                    await partnerVM.fetchAll(near: loc)
                } else {
                    partnerVM.loadMockData()
                }
            }
        }
    }

    // MARK: - Help Us Cleanup (environmental impact launcher)

    private var openMuckCount: Int { muckVM.filtered(allMucks).count }
    private var upcomingEventCount: Int { allEvents.filter { !$0.isPast }.count }

    private var helpWorldTab: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    laneHeader(
                        title: "Neighbourhood Cleanup",
                        subtitle: "Spot litter, report a hazard, or join a community cleanup near you."
                    )

                    HelpWorldMiniMapView(mucks: muckVM.filtered(allMucks), userLocation: locationService.location)

                    HStack(spacing: Spacing.sm) {
                        HelpStatCard(icon: "mappin.circle.fill", value: "\(openMuckCount)", label: "open mucks nearby") {
                            showNearbyMucks = true
                        }
                        HelpStatCard(icon: "calendar", value: "\(upcomingEventCount)", label: "upcoming events") {
                            showUpcomingEvents = true
                        }
                    }

                    VStack(spacing: Spacing.sm) {
                        NavigationLink {
                            MapViewScreen()
                        } label: {
                            HelpLaneActionRow(
                                icon: "map.fill",
                                title: "Browse the Map",
                                subtitle: "See every open muck and event around you.",
                                color: Color.muckAmber,
                                isLink: true
                            ) {}
                        }
                        .buttonStyle(.plain)

                        Button {
                            withAnimation { lane = .helpMe }
                        } label: {
                            HelpLaneActionRow(
                                icon: "hand.raised.fill",
                                title: "Switch to Help Me",
                                subtitle: "Browse requests from neighbours who need a hand.",
                                color: Color.helpCategoryColor(.other),
                                isLink: true
                            ) {}
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Spacing.md)
            }

            PrimaryButton(title: "Raise a Muck", icon: "leaf.fill") {
                showRaiseMuck = true
            }
            .padding(Spacing.md)
        }
    }

    // MARK: - Help Me (personal request feed)

    private var openRequestCount: Int { allHelpRequests.filter { $0.status != .completed }.count }
    private var offeredByMeCount: Int { muckVM.offeredHelpIds.count }

    private var helpMeTab: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    laneHeader(
                        title: "Ask a Neighbour",
                        subtitle: "Get a hand with yard work, moving, repairs, or just some company."
                    )

                    HelpMeMiniMapView(
                        requests: helpVM.filtered(allHelpRequests),
                        userLocation: locationService.location
                    )

                    HStack(spacing: Spacing.sm) {
                        HelpStatCard(icon: "hand.raised.fill", value: "\(openRequestCount)", label: "open requests nearby")
                        HelpStatCard(icon: "hands.sparkles.fill", value: "\(offeredByMeCount)", label: "you've offered")
                    }

                    // Community programs for seniors — Growing Old Program events
                    let goldEvents = partnerVM.items.filter { $0.source == .goldEvents }
                    if !goldEvents.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("👴 Community programs for seniors")
                                .font(.muckHeadline)
                                .foregroundStyle(Color.muckNearBlack)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: Spacing.sm) {
                                    ForEach(goldEvents.prefix(10)) { item in
                                        GoldEventCard(item: item)
                                            .onTapGesture { selectedGoldEvent = item }
                                    }
                                }
                            }
                        }
                    }

                    // Category filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.xs) {
                            FilterPill(title: "All", isActive: helpVM.categoryFilter == nil) {
                                helpVM.categoryFilter = nil
                            }
                            ForEach(HelpCategory.allCases, id: \.self) { cat in
                                FilterPill(
                                    title: cat.displayName,
                                    isActive: helpVM.categoryFilter == cat,
                                    activeColor: Color.helpCategoryColor(cat)
                                ) {
                                    helpVM.categoryFilter = (helpVM.categoryFilter == cat) ? nil : cat
                                }
                            }
                        }
                    }

                    let requests = helpVM.filtered(allHelpRequests)

                    if requests.isEmpty {
                        VStack(spacing: Spacing.sm) {
                            EmptyStateIllustration(systemImage: "hand.raised.fill")
                            Text("No open requests nearby")
                                .font(.muckTitle)
                                .foregroundStyle(Color.muckNearBlack)
                            Text("Be the first to ask your neighbours for a hand.")
                                .font(.muckBody)
                                .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.xl)
                    } else {
                        VStack(spacing: Spacing.sm) {
                            ForEach(requests) { request in
                                HelpRequestCard(
                                    request: request,
                                    distance: request.distanceLabel(from: locationService.location),
                                    hasOffered: helpVM.hasOffered(request)
                                )
                                .onTapGesture { selectedRequest = request }
                            }
                        }
                    }
                }
                .padding(Spacing.md)
            }

            PrimaryButton(title: "Ask for Help", icon: "hand.raised.fill") {
                showAskForHelp = true
            }
            .padding(Spacing.md)
        }
    }

    // MARK: - Shared header

    private func laneHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(title)
                .font(.muckDisplay)
                .foregroundStyle(Color.muckNearBlack)
            Text(subtitle)
                .font(.muckBody)
                .foregroundStyle(Color.muckNearBlack.opacity(0.5))
        }
    }
}

// MARK: - Help World mini map

private struct HelpWorldMiniMapView: View {
    let mucks: [Muck]
    let userLocation: CLLocation?

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showFullMap = false

    var body: some View {
        Button {
            showFullMap = true
        } label: {
            ZStack(alignment: .bottomTrailing) {
                Map(position: $cameraPosition, interactionModes: []) {
                    ForEach(mucks.prefix(30)) { muck in
                        Annotation(muck.location, coordinate: muck.coordinate) {
                            MuckMapMarker(muck: muck)
                                .scaleEffect(0.8)
                        }
                    }
                }
                .mapStyle(.standard(elevation: .flat))
                .disabled(true)
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))

                if !mucks.isEmpty {
                    Label("\(mucks.count) nearby", systemImage: "mappin.and.ellipse")
                        .font(.muckMicro)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 4)
                        .background(Color.muckNearBlack.opacity(0.6))
                        .clipShape(Capsule())
                        .padding(Spacing.xs)
                }
            }
        }
        .buttonStyle(.plain)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .strokeBorder(Color.muckNearBlack.opacity(0.08))
        )
        .onAppear { centre() }
        .onChange(of: mucks.map(\.id)) { _, _ in centre() }
        .sheet(isPresented: $showFullMap) {
            NavigationStack {
                MapViewScreen()
            }
        }
    }

    private func centre() {
        let target = userLocation?.coordinate
            ?? mucks.first?.coordinate
            ?? CLLocationCoordinate2D(latitude: -37.8136, longitude: 144.9631)
        cameraPosition = .camera(MapCamera(centerCoordinate: target, distance: 4000))
    }
}

// MARK: - Help Me mini map

private struct HelpMeMiniMapView: View {
    let requests: [HelpRequest]
    let userLocation: CLLocation?

    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Map(position: $cameraPosition, interactionModes: []) {
                ForEach(requests) { request in
                    MapCircle(center: request.blurredCoordinate, radius: request.blurRadiusMetres)
                        .foregroundStyle(Color.helpCategoryColor(request.category).opacity(0.18))
                        .stroke(Color.helpCategoryColor(request.category), lineWidth: 1.5)
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .disabled(true)
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))

            if !requests.isEmpty {
                Label("\(requests.count) nearby", systemImage: "hand.raised.fill")
                    .font(.muckMicro)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, 4)
                    .background(Color.muckNearBlack.opacity(0.6))
                    .clipShape(Capsule())
                    .padding(Spacing.xs)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .strokeBorder(Color.muckNearBlack.opacity(0.08))
        )
        .onAppear { centre() }
        .onChange(of: requests.map(\.id)) { _, _ in centre() }
    }

    private func centre() {
        let target = userLocation?.coordinate
            ?? requests.first?.blurredCoordinate
            ?? CLLocationCoordinate2D(latitude: -37.8136, longitude: 144.9631)
        cameraPosition = .camera(MapCamera(centerCoordinate: target, distance: 4000))
    }
}

// MARK: - Gold Event Card (seniors' programs)

private struct GoldEventCard: View {
    let item: PartnerItem

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            SourceBadgeView(source: item.source)
            Text(item.name)
                .font(.muckHeadline)
                .foregroundStyle(Color.muckNearBlack)
                .lineLimit(2)
            if let date = item.displayDate {
                Text(date)
                    .font(.muckCaption)
                    .foregroundStyle(Color.muckNearBlack.opacity(0.5))
            }
        }
        .padding(Spacing.sm)
        .frame(width: 170, alignment: .leading)
        .background(Color.muckSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .strokeBorder(Color.partnerColor(.goldEvents).opacity(0.3), lineWidth: 1)
        )
        .muckCardShadow()
    }
}

// MARK: - Stat card

private struct HelpStatCard: View {
    let icon: String
    let value: String
    let label: String
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(Color.muckGreen)
                    Spacer()
                    if action != nil {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.muckNearBlack.opacity(0.25))
                    }
                }
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.muckNearBlack)
                Text(label)
                    .font(.muckMicro)
                    .foregroundStyle(Color.muckNearBlack.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.sm)
            .background(Color.muckSurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

// MARK: - Nearby mucks / upcoming events sheets

private struct NearbyMucksSheet: View {
    let mucks: [Muck]
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var muckVM: MuckViewModel
    @EnvironmentObject var locationService: LocationService
    @State private var selectedMuck: Muck?

    var body: some View {
        NavigationStack {
            Group {
                if mucks.isEmpty {
                    VStack(spacing: Spacing.sm) {
                        EmptyStateIllustration(systemImage: "mappin.slash")
                        Text("No open mucks nearby")
                            .font(.muckBody)
                            .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(mucks) { muck in
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
                    .listStyle(.plain)
                }
            }
            .background(Color.muckBg)
            .navigationTitle("Open Mucks Nearby")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.muckNearBlack)
                }
            }
            .navigationDestination(item: $selectedMuck) { muck in
                ViewMuckView(muck: muck)
            }
        }
    }
}

private struct UpcomingEventsSheet: View {
    let events: [MuckEvent]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedEvent: MuckEvent?

    var body: some View {
        NavigationStack {
            Group {
                if events.isEmpty {
                    VStack(spacing: Spacing.sm) {
                        EmptyStateIllustration(systemImage: "calendar.badge.exclamationmark")
                        Text("No upcoming events")
                            .font(.muckBody)
                            .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(events) { event in
                        EventRowView(event: event)
                            .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.md, bottom: Spacing.xs, trailing: Spacing.md))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .onTapGesture { selectedEvent = event }
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color.muckBg)
            .navigationTitle("Upcoming Events")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.muckNearBlack)
                }
            }
            .navigationDestination(item: $selectedEvent) { event in
                if event.isToday || event.isLive {
                    EventLiveView(event: event)
                } else {
                    EventDetailView(event: event)
                }
            }
        }
    }
}

// MARK: - Action row

private struct HelpLaneActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    var isLink: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                ZStack {
                    Circle().fill(color.opacity(0.12)).frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.muckHeadline)
                        .foregroundStyle(Color.muckNearBlack)
                    Text(subtitle)
                        .font(.muckCaption)
                        .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.muckNearBlack.opacity(0.25))
            }
            .padding(Spacing.sm)
            .background(Color.muckSurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
        .buttonStyle(.plain)
        .disabled(isLink)
    }
}
