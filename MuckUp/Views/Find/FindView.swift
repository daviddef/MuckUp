import SwiftUI
import CoreLocation
import MapKit

enum FindDisplayMode: String, CaseIterable {
    case list, map, timeline

    var icon: String {
        switch self {
        case .list:     return "list.bullet"
        case .map:      return "map"
        case .timeline: return "calendar.day.timeline.left"
        }
    }
}

struct FindView: View {
    @EnvironmentObject var partnerVM: PartnerViewModel
    @EnvironmentObject var locationService: LocationService
    @State private var searchText = ""
    @State private var displayMode: FindDisplayMode = .list

    private var filteredItems: [PartnerItem] {
        let base = partnerVM.filteredItems
        guard !searchText.isEmpty else { return base }
        let q = searchText.lowercased()
        return base.filter {
            $0.name.lowercased().contains(q) ||
            ($0.itemDescription?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Source filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.xs) {
                        FilterPill(title: "All", isActive: partnerVM.sourceFilter == nil) {
                            partnerVM.sourceFilter = nil
                        }
                        ForEach(PartnerSource.allCases) { source in
                            FilterPill(
                                title: source.displayName,
                                isActive: partnerVM.sourceFilter == source,
                                activeColor: Color.partnerColor(source)
                            ) {
                                partnerVM.sourceFilter = (partnerVM.sourceFilter == source) ? nil : source
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                }
                .padding(.vertical, Spacing.xs)

                // Display mode switch
                Picker("View", selection: $displayMode) {
                    ForEach(FindDisplayMode.allCases, id: \.self) { mode in
                        Image(systemName: mode.icon).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xs)

                if partnerVM.isLoading {
                    Spacer()
                    ProgressView("Finding nearby activity…")
                        .tint(Color.muckGreen)
                    Spacer()
                } else {
                    switch displayMode {
                    case .list:
                        listView
                    case .map:
                        FindMapView(items: filteredItems)
                    case .timeline:
                        FindTimelineView(items: filteredItems)
                    }
                }
            }
            .background(Color.muckBg)
            .navigationTitle("Find")
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
    }

    private var listView: some View {
        List {
            ForEach(filteredItems) { item in
                PartnerItemRow(item: item)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.md, bottom: Spacing.xs, trailing: Spacing.md))
            }

            // More Organisations footer
            Section {
                MoreOrganisationsView()
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .searchable(text: $searchText, prompt: "Search nearby activity")
    }
}

// MARK: - Find: Map view

struct FindMapView: View {
    let items: [PartnerItem]
    @EnvironmentObject var locationService: LocationService
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedItem: PartnerItem?

    var body: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()
            ForEach(items) { item in
                Annotation(item.name, coordinate: CLLocationCoordinate2D(latitude: item.latitude, longitude: item.longitude)) {
                    PartnerMapMarker(source: item.source)
                        .onTapGesture { selectedItem = item }
                }
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .onAppear {
            if let loc = locationService.location {
                cameraPosition = .camera(MapCamera(centerCoordinate: loc.coordinate, distance: 6000))
            }
        }
        .sheet(item: $selectedItem) { item in
            NavigationStack {
                ScrollView {
                    PartnerItemRow(item: item)
                        .padding(Spacing.md)
                }
                .background(Color.muckBg)
                .navigationTitle(item.source.displayName)
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.height(280)])
            .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Find: Timeline view

struct FindTimelineView: View {
    let items: [PartnerItem]

    private var groupedByDate: [(label: String, items: [PartnerItem])] {
        let dated = items.filter { $0.date != nil }
        let undated = items.filter { $0.date == nil }

        let grouped = Dictionary(grouping: dated) { item -> Date in
            Calendar.current.startOfDay(for: item.date!)
        }
        var sections = grouped.keys.sorted().map { day -> (String, [PartnerItem]) in
            let label: String
            if Calendar.current.isDateInToday(day) {
                label = "Today"
            } else if Calendar.current.isDateInTomorrow(day) {
                label = "Tomorrow"
            } else {
                label = day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
            }
            return (label, grouped[day]!.sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) })
        }
        if !undated.isEmpty {
            sections.append(("Ongoing", undated))
        }
        return sections
    }

    var body: some View {
        if items.isEmpty {
            Spacer()
            VStack(spacing: Spacing.md) {
                EmptyStateIllustration(systemImage: "calendar.day.timeline.left")
                Text("Nothing on the timeline yet")
                    .font(.muckTitle)
                    .foregroundStyle(Color.muckNearBlack)
                Text("Try a different filter or check back soon.")
                    .font(.muckBody)
                    .foregroundStyle(Color.muckNearBlack.opacity(0.5))
            }
            Spacer()
        } else {
            List {
                ForEach(groupedByDate, id: \.label) { section in
                    Section(section.label) {
                        ForEach(section.items) { item in
                            PartnerItemRow(item: item)
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

struct PartnerItemRow: View {
    let item: PartnerItem
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var muckVM: MuckViewModel
    @State private var scheduleMuck: Muck?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                SourceBadgeView(source: item.source)
                if let emoji = item.weatherEmoji {
                    Text(emoji)
                        .font(.muckCaption)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 2)
                        .background(Color.muckSurface)
                        .clipShape(Capsule())
                }
                Spacer()
                if let date = item.displayDate {
                    Text(date)
                        .font(.muckCaption)
                        .foregroundStyle(Color.muckNearBlack.opacity(0.4))
                }
            }

            Text(item.name)
                .font(.muckTitle)
                .foregroundStyle(Color.muckNearBlack)

            if let desc = item.itemDescription {
                Text(desc)
                    .font(.muckBody)
                    .foregroundStyle(Color.muckNearBlack.opacity(0.65))
                    .lineLimit(2)
            }

            if let attendees = item.attendees {
                Label("\(attendees) attending", systemImage: "person.2")
                    .font(.muckCaption)
                    .foregroundStyle(Color.muckNearBlack.opacity(0.5))
            }

            // CTA
            if item.source.promptsCreateMuck {
                HStack {
                    SecondaryButton(title: "📅  Schedule Cleanup") {
                        scheduleCleanup()
                    }
                    Spacer()
                    Link("View on \(item.source.displayName) →", destination: item.externalURL)
                        .font(.muckCaption)
                        .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                }
            } else {
                Link("View on \(item.source.displayName) →", destination: item.externalURL)
                    .font(.muckCaption)
                    .foregroundStyle(Color.partnerColor(item.source))
            }
        }
        .padding(Spacing.md)
        .background(Color.muckSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .sheet(item: $scheduleMuck) { muck in
            ScheduleEventView(preselectedMuck: muck)
        }
        .muckCardShadow()
    }

    /// Litter Map items aren't Mucks yet — silently create the linking Muck
    /// record from the report, then jump straight into scheduling a cleanup
    /// for it, instead of making the user go through Raise a Muck manually.
    private func scheduleCleanup() {
        let muck = Muck(
            location: item.name,
            description: item.itemDescription ?? "Reported via \(item.source.displayName).",
            type: .cleanup,
            latitude: item.latitude,
            longitude: item.longitude
        )
        modelContext.insert(muck)
        muckVM.recordRaised(muck.id)
        scheduleMuck = muck
    }
}

struct MoreOrganisationsView: View {
    let orgs: [(name: String, url: URL)] = [
        ("Keep Australia Beautiful", URL(string: "https://www.kab.org.au")!),
        ("Clean Up Australia", URL(string: "https://www.cleanup.org.au")!),
        ("OzGREEN", URL(string: "https://www.ozgreen.org.au")!),
        ("Tangaroa Blue", URL(string: "https://www.tangaroablue.org")!),
        ("Planet Ark", URL(string: "https://planetark.org")!),
        ("Landcare Australia", URL(string: "https://landcareaustralia.org.au")!),
        ("Bush Heritage", URL(string: "https://www.bushheritage.org.au")!),
        ("Greening Australia", URL(string: "https://www.greeningaustralia.org.au")!),
        ("Australian Conservation Foundation", URL(string: "https://www.acf.org.au")!),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("More Organisations")
                .font(.muckTitle)
                .foregroundStyle(Color.muckNearBlack)
                .padding(.bottom, Spacing.xxs)
            ForEach(orgs, id: \.name) { org in
                Link(destination: org.url) {
                    HStack {
                        Text(org.name)
                            .font(.muckBody)
                            .foregroundStyle(Color.muckNearBlack)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.muckNearBlack.opacity(0.3))
                    }
                    .padding(.vertical, Spacing.xxs)
                }
                Divider()
            }
        }
        .padding(Spacing.md)
        .background(Color.muckSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
    }
}
