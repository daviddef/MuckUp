import SwiftUI
import SwiftData
import CoreLocation
import MapKit

struct ScheduleEventView: View {
    var preselectedMuck: Muck?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var muckVM: MuckViewModel
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var awarenessVM: AwarenessViewModel
    @Query private var allMucks: [Muck]

    @State private var title = ""
    @State private var description = ""
    @State private var eventDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    @State private var selectedMuckIds: Set<String> = []
    @State private var isSaved = false
    @State private var muckSearch = ""
    @State private var expandedRadius = false
    @State private var quickLookMuck: Muck?
    @State private var showMuckLinking = true

    // Meetup location picker state
    @State private var pickedMeetupCoordinate: CLLocationCoordinate2D? = nil
    @State private var pickedMeetupAddress: String = "Locating…"
    @State private var isDraggingMeetup = false

    // Address search — jumps the map picker to a typed address
    @State private var addressSearchText = ""
    @State private var isSearchingAddress = false
    @State private var addressSearchError: String? = nil
    @State private var mapRecenterCoordinate: CLLocationCoordinate2D? = nil
    @State private var mapRecenterToken = 0

    // "Things to be aware of" near the meetup point
    @State private var nearbyAwarenessItems: [AwarenessItem] = []
    @State private var isLoadingAwareness = false
    @State private var selectedAwarenessItem: AwarenessItem? = nil

    // Radius thresholds in metres
    private let nearbyRadius: Double = 10_000   // 10 km
    private let expandedRadiusKm: Double = 50_000  // 50 km
    private let suggestionCount = 5
    private let visibleListCap = 40

    private var eligibleMucks: [Muck] {
        allMucks.filter { !$0.isClosed && $0.type.allowsEvents }
    }

    // Sorted by distance, pre-selected always included regardless of radius
    private var mucksByDistance: [Muck] {
        let userLoc = locationService.location
        return eligibleMucks.sorted {
            distanceMetres($0, from: userLoc) < distanceMetres($1, from: userLoc)
        }
    }

    private var matchingMucks: [Muck] {
        let userLoc = locationService.location
        let radius = expandedRadius ? expandedRadiusKm : nearbyRadius
        var result = mucksByDistance.filter { muck in
            // Always show pre-selected or already-ticked mucks
            if selectedMuckIds.contains(muck.id) { return true }
            if let loc = userLoc {
                return distanceMetres(muck, from: loc) <= radius
            }
            return true  // no location: show all
        }
        if !muckSearch.isEmpty {
            let q = muckSearch.lowercased()
            result = result.filter {
                $0.location.lowercased().contains(q) ||
                $0.muckDescription.lowercased().contains(q)
            }
        }
        return result
    }

    // Hard cap on rendered rows — a dense city could easily have 1,000s of
    // eligible mucks; the radius/search filters above do the real narrowing,
    // this is just a backstop so the list never renders something unbounded.
    private var visibleMucks: [Muck] {
        Array(matchingMucks.prefix(visibleListCap))
    }

    private var overflowCount: Int {
        max(0, matchingMucks.count - visibleListCap)
    }

    // Nearby, not-yet-selected mucks — top-voted first, falling back to
    // closest-by-distance so the section is never empty just because
    // nothing nearby has votes yet. A nudge, not a requirement.
    private var suggestedMucks: [Muck] {
        guard muckSearch.isEmpty else { return [] }
        let radius = expandedRadius ? expandedRadiusKm : nearbyRadius
        let userLoc = locationService.location
        let candidates = eligibleMucks.filter { muck in
            !selectedMuckIds.contains(muck.id) &&
            (userLoc == nil || distanceMetres(muck, from: userLoc) <= radius)
        }
        let voted = candidates.filter { $0.votes > 0 }.sorted { $0.votes > $1.votes }
        if voted.count >= suggestionCount {
            return Array(voted.prefix(suggestionCount))
        }
        // Top up with nearest-by-distance candidates not already included
        let votedIds = Set(voted.map(\.id))
        let byDistance = candidates
            .filter { !votedIds.contains($0.id) }
            .sorted { distanceMetres($0, from: userLoc) < distanceMetres($1, from: userLoc) }
        return Array((voted + byDistance).prefix(suggestionCount))
    }

    private var suggestionFooter: String {
        suggestedMucks.contains { $0.votes > 0 }
            ? "Based on votes and proximity. Optional — add any that fit."
            : "Nearest mucks in this area. Optional — add any that fit."
    }

    // Mucks that exist but are outside the current radius (and not selected)
    private var hiddenCount: Int {
        guard !expandedRadius, locationService.location != nil else { return 0 }
        return eligibleMucks.filter { muck in
            !selectedMuckIds.contains(muck.id) &&
            distanceMetres(muck, from: locationService.location) > nearbyRadius
        }.count
    }

    private var selectedMucks: [Muck] {
        allMucks.filter { selectedMuckIds.contains($0.id) }
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                // ── Event title ──────────────────────────────────────
                Section {
                    TextField("e.g. Princes Park Saturday Blitz", text: $title)
                        .font(.muckBody)
                } header: {
                    Text("Event Title *")
                        .font(.muckCaption)
                }

                // ── Description ──────────────────────────────────────
                Section {
                    TextEditor(text: $description)
                        .font(.muckBody)
                        .frame(minHeight: 80)
                } header: {
                    Text("Description")
                        .font(.muckCaption)
                }

                // ── Date ─────────────────────────────────────────────
                Section {
                    DatePicker("Date & Time", selection: $eventDate, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
                        .tint(Color.muckGreen)
                } header: {
                    Text("When")
                        .font(.muckCaption)
                }

                // ── Submit ───────────────────────────────────────────
                Section {
                    PrimaryButton(title: "Create Event", icon: "calendar.badge.plus", isDisabled: !isValid) {
                        createEvent()
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                // ── Meetup location ───────────────────────────────────
                Section {
                    MeetupLocationRow(
                        addressSearchText: $addressSearchText,
                        isSearchingAddress: isSearchingAddress,
                        addressSearchError: addressSearchError,
                        userLocation: locationService.location,
                        initialCoordinate: pickedMeetupCoordinate ?? centroidOfSelectedMucks,
                        isDraggingMeetup: $isDraggingMeetup,
                        pickedMeetupAddress: pickedMeetupAddress,
                        recenterCoordinate: mapRecenterCoordinate,
                        recenterToken: mapRecenterToken,
                        onSearch: { searchAddress() },
                        onCoordinateChanged: { coord in
                            pickedMeetupCoordinate = coord
                            reverseGeocodeMeetup(coord)
                            loadAwareness(near: coord)
                        }
                    )
                } header: {
                    Text("Where — Meeting Point")
                        .font(.muckCaption)
                } footer: {
                    Text("Search an address to jump the map, then fine-tune by dragging the pin.")
                        .font(.muckMicro)
                        .foregroundStyle(Color.muckNearBlack.opacity(0.4))
                }

                // ── Things to be aware of ─────────────────────────────
                if isLoadingAwareness || !nearbyAwarenessItems.isEmpty {
                    Section {
                        AwarenessSectionRows(
                            isLoadingAwareness: isLoadingAwareness,
                            nearbyAwarenessItems: nearbyAwarenessItems,
                            onSelect: { selectedAwarenessItem = $0 }
                        )
                    } header: {
                        Text("⚠️ Things to be aware of in this area")
                            .font(.muckCaption)
                    } footer: {
                        Text("From Brisbane City Council open data — waterway safety and animal complaint reports near your meeting point.")
                            .font(.muckMicro)
                            .foregroundStyle(Color.muckNearBlack.opacity(0.4))
                    }
                }

                // ── Link mucks — collapsed by default; optional add-on,
                // not every event has (or needs) a muck attached ────────
                Section {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showMuckLinking.toggle()
                        }
                    } label: {
                        HStack {
                            Label("Link Mucks to this Event", systemImage: "mappin.and.ellipse")
                                .font(.muckHeadline)
                                .foregroundStyle(Color.muckNearBlack)
                            Spacer()
                            if !selectedMuckIds.isEmpty {
                                Text("\(selectedMuckIds.count) selected")
                                    .font(.muckCaption)
                                    .foregroundStyle(Color.muckGreen)
                            }
                            Image(systemName: showMuckLinking ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.muckNearBlack.opacity(0.4))
                        }
                    }
                    .buttonStyle(.plain)
                } footer: {
                    if !showMuckLinking {
                        Text("Optional — tap to browse nearby mucks to clean up at this event.")
                            .font(.muckMicro)
                            .foregroundStyle(Color.muckNearBlack.opacity(0.4))
                    }
                }

                // ── Suggested mucks ──────────────────────────────────
                if showMuckLinking && !suggestedMucks.isEmpty {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Spacing.sm) {
                                ForEach(suggestedMucks) { muck in
                                    MuckSuggestionCard(
                                        muck: muck,
                                        distance: muck.distance(from: locationService.location),
                                        isSelected: selectedMuckIds.contains(muck.id),
                                        onTapCard: { quickLookMuck = muck },
                                        onToggle: { toggleMuck(muck) }
                                    )
                                }
                            }
                            .padding(.vertical, Spacing.xxs)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: Spacing.md, bottom: Spacing.xs, trailing: Spacing.md))
                    } header: {
                        Text("🔥 Suggested for this area")
                            .font(.muckCaption)
                    } footer: {
                        Text(suggestionFooter)
                            .font(.muckMicro)
                            .foregroundStyle(Color.muckNearBlack.opacity(0.4))
                    }
                }

                // ── Selected mucks proximity map ─────────────────────
                if showMuckLinking && selectedMucks.count > 1 {
                    Section {
                        SelectedMucksMapView(mucks: selectedMucks, onSelect: { quickLookMuck = $0 })
                            .listRowInsets(EdgeInsets(top: 0, leading: Spacing.md, bottom: Spacing.xs, trailing: Spacing.md))
                    } header: {
                        Text("Proximity of selected mucks")
                            .font(.muckCaption)
                    } footer: {
                        Text("Spread out mucks mean more walking between stops on the day.")
                            .font(.muckMicro)
                            .foregroundStyle(Color.muckNearBlack.opacity(0.4))
                    }
                }

                // ── Muck picker ──────────────────────────────────────
                if showMuckLinking {
                Section {
                    // Inline search when list is non-trivial
                    if eligibleMucks.count > 4 {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(Color.muckNearBlack.opacity(0.35))
                                .font(.system(size: 14))
                            TextField("Search mucks…", text: $muckSearch)
                                .font(.muckBody)
                                .foregroundStyle(Color.muckNearBlack)
                        }
                        .padding(.vertical, Spacing.xxs)
                    }

                    if visibleMucks.isEmpty {
                        Text(muckSearch.isEmpty ? "No mucks nearby." : "No results for \"\(muckSearch)\".")
                            .font(.muckBody)
                            .foregroundStyle(Color.muckNearBlack.opacity(0.4))
                            .padding(.vertical, Spacing.xs)
                    } else {
                        ForEach(visibleMucks) { muck in
                            MuckPickerCard(
                                muck: muck,
                                isSelected: selectedMuckIds.contains(muck.id),
                                distance: muck.distance(from: locationService.location),
                                onTapCard: { quickLookMuck = muck },
                                onToggle: { toggleMuck(muck) }
                            )
                            .listRowInsets(EdgeInsets(top: Spacing.xxs, leading: Spacing.md, bottom: Spacing.xxs, trailing: Spacing.md))
                            .listRowSeparator(.hidden)
                        }

                        if overflowCount > 0 {
                            Text("+\(overflowCount) more match — narrow your search to see them.")
                                .font(.muckMicro)
                                .foregroundStyle(Color.muckNearBlack.opacity(0.4))
                                .padding(.vertical, Spacing.xxs)
                        }
                    }

                    // Expand radius affordance
                    if hiddenCount > 0 {
                        Button {
                            withAnimation { expandedRadius = true }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 12))
                                Text("Show \(hiddenCount) more muck\(hiddenCount == 1 ? "" : "s") within 50 km")
                                    .font(.muckCaption)
                            }
                            .foregroundStyle(Color.muckGreen)
                            .padding(.vertical, Spacing.xxs)
                        }
                        .buttonStyle(.plain)
                    } else if expandedRadius && hiddenCount == 0 {
                        Button {
                            withAnimation { expandedRadius = false }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.down.right.and.arrow.up.left")
                                    .font(.system(size: 12))
                                Text("Show nearby only")
                                    .font(.muckCaption)
                            }
                            .foregroundStyle(Color.muckNearBlack.opacity(0.4))
                            .padding(.vertical, Spacing.xxs)
                        }
                        .buttonStyle(.plain)
                    }

                } header: {
                    HStack {
                        Text("Select Mucks")
                        Spacer()
                        if !selectedMuckIds.isEmpty {
                            Text("\(selectedMuckIds.count) selected")
                                .foregroundStyle(Color.muckGreen)
                        }
                    }
                    .font(.muckCaption)
                }
                }

            }
            .listStyle(.insetGrouped)
            .navigationTitle("Schedule Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.muckNearBlack)
                }
            }
            .navigationDestination(isPresented: $isSaved) {
                EventSavedView(onBackToHome: { dismiss() })
            }
            .sheet(item: $quickLookMuck) { muck in
                MuckQuickLookSheet(
                    muck: muck,
                    isSelected: selectedMuckIds.contains(muck.id),
                    distance: muck.distance(from: locationService.location),
                    onToggle: { toggleMuck(muck) }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedAwarenessItem) { item in
                AwarenessDetailSheet(item: item)
            }
        }
        .onAppear {
            if let muck = preselectedMuck {
                selectedMuckIds.insert(muck.id)
                showMuckLinking = true
            }
            let start = centroidOfSelectedMucks ?? locationService.location?.coordinate
            if let start {
                pickedMeetupCoordinate = start
                reverseGeocodeMeetup(start)
                loadAwareness(near: start)
            } else {
                pickedMeetupAddress = "Move the map to set the meeting point"
            }
        }
    }

    // MARK: - Helpers

    private func toggleMuck(_ muck: Muck) {
        if selectedMuckIds.contains(muck.id) {
            selectedMuckIds.remove(muck.id)
        } else {
            selectedMuckIds.insert(muck.id)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func distanceMetres(_ muck: Muck, from location: CLLocation?) -> Double {
        guard let location else { return 0 }
        return CLLocation(latitude: muck.latitude, longitude: muck.longitude)
            .distance(from: location)
    }

    // Centre point of whatever mucks are already selected (e.g. arriving via
    // "Add to Event" or Litter Map's Schedule Cleanup) — a sensible starting
    // pin for the meetup point before the organiser adjusts it themselves.
    private var centroidOfSelectedMucks: CLLocationCoordinate2D? {
        guard !selectedMucks.isEmpty else { return nil }
        let lats = selectedMucks.map(\.latitude)
        let lons = selectedMucks.map(\.longitude)
        return CLLocationCoordinate2D(
            latitude: lats.reduce(0, +) / Double(lats.count),
            longitude: lons.reduce(0, +) / Double(lons.count)
        )
    }

    private func reverseGeocodeMeetup(_ coord: CLLocationCoordinate2D) {
        let geocoder = CLGeocoder()
        let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        geocoder.reverseGeocodeLocation(loc) { placemarks, _ in
            guard let place = placemarks?.first else { return }
            let parts = [place.name, place.locality, place.administrativeArea]
                .compactMap { $0 }
            pickedMeetupAddress = parts.prefix(2).joined(separator: ", ")
        }
    }

    private func searchAddress() {
        let query = addressSearchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        addressSearchError = nil
        isSearchingAddress = true

        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(query) { placemarks, _ in
            isSearchingAddress = false
            guard let coordinate = placemarks?.first?.location?.coordinate else {
                addressSearchError = "Couldn't find that address — try adding a suburb."
                return
            }
            mapRecenterCoordinate = coordinate
            mapRecenterToken += 1
        }
    }

    // Debounced — onCoordinateChanged fires on every map region change
    // while dragging, so this waits for the pin to settle before hitting
    // the network for waterway/animal-complaint data.
    @State private var awarenessLoadTask: Task<Void, Never>?

    private func loadAwareness(near coord: CLLocationCoordinate2D) {
        awarenessLoadTask?.cancel()
        isLoadingAwareness = true
        awarenessLoadTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            let items = await awarenessVM.fetchNearby(coord)
            guard !Task.isCancelled else { return }
            nearbyAwarenessItems = items
            isLoadingAwareness = false
        }
    }

    private func createEvent() {
        let meetupCoord = pickedMeetupCoordinate
            ?? centroidOfSelectedMucks
            ?? locationService.location?.coordinate
            ?? CLLocationCoordinate2D(latitude: -37.8136, longitude: 144.9631)

        let event = MuckEvent(
            title: title,
            location: pickedMeetupAddress,
            date: eventDate,
            description: description,
            muckIds: Array(selectedMuckIds),
            participants: 1,
            isAttending: true,
            meetupLatitude: meetupCoord.latitude,
            meetupLongitude: meetupCoord.longitude
        )
        modelContext.insert(event)
        for id in selectedMuckIds {
            allMucks.first(where: { $0.id == id })?.eventCount += 1
        }
        muckVM.award(.participate)
        isSaved = true
    }
}
