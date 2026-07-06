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
    @State private var showMuckLinking = false

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
                    // Address search — jumps the map to a typed address
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.muckNearBlack.opacity(0.35))
                        TextField("Search an address…", text: $addressSearchText)
                            .font(.muckBody)
                            .foregroundStyle(Color.muckNearBlack)
                            .submitLabel(.search)
                            .onSubmit { searchAddress() }
                        if isSearchingAddress {
                            ProgressView().tint(Color.muckGreen)
                        } else if !addressSearchText.isEmpty {
                            Button {
                                searchAddress()
                            } label: {
                                Text("Go")
                                    .font(.muckCaption)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, Spacing.sm)
                                    .padding(.vertical, Spacing.xxs)
                                    .background(Color.muckGreen)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, Spacing.xxxs)

                    if let addressSearchError {
                        Text(addressSearchError)
                            .font(.muckCaption)
                            .foregroundStyle(Color.muckRed)
                    }

                    MuckLocationPicker(
                        userLocation: locationService.location,
                        initialCoordinate: pickedMeetupCoordinate ?? centroidOfSelectedMucks,
                        isDragging: $isDraggingMeetup,
                        onCoordinateChanged: { coord in
                            pickedMeetupCoordinate = coord
                            reverseGeocodeMeetup(coord)
                            loadAwareness(near: coord)
                        },
                        recenterCoordinate: mapRecenterCoordinate,
                        recenterToken: mapRecenterToken
                    )
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.md)
                            .strokeBorder(Color.muckNearBlack.opacity(0.1))
                    )
                    .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.md, bottom: Spacing.xs, trailing: Spacing.md))

                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(Color.muckGreen)
                            .font(.system(size: 14))
                        Text(isDraggingMeetup ? "Drop to set the meeting point…" : pickedMeetupAddress)
                            .font(.muckBody)
                            .foregroundStyle(isDraggingMeetup
                                ? Color.muckNearBlack.opacity(0.4)
                                : Color.muckNearBlack)
                            .animation(.easeInOut(duration: 0.15), value: isDraggingMeetup)
                        Spacer()
                    }
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
                        if isLoadingAwareness {
                            HStack(spacing: Spacing.xs) {
                                ProgressView().tint(Color.muckGreen)
                                Text("Checking the area…")
                                    .font(.muckBody)
                                    .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                            }
                            .padding(.vertical, Spacing.xxs)
                        } else {
                            ForEach(nearbyAwarenessItems) { item in
                                Button {
                                    selectedAwarenessItem = item
                                } label: {
                                    AwarenessRow(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
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
                EventSavedView()
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

// MARK: - Selected Mucks Proximity Map

private struct SelectedMucksMapView: View {
    let mucks: [Muck]
    let onSelect: (Muck) -> Void

    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $cameraPosition) {
            ForEach(mucks) { muck in
                Annotation(muck.location, coordinate: muck.coordinate) {
                    MuckMapMarker(muck: muck)
                        .scaleEffect(0.85)
                        .onTapGesture { onSelect(muck) }
                }
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .disabled(false)
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .strokeBorder(Color.muckNearBlack.opacity(0.08))
        )
        .onAppear { fitCamera() }
        .onChange(of: mucks.map(\.id)) { _, _ in fitCamera() }
    }

    private func fitCamera() {
        guard !mucks.isEmpty else { return }
        let lats = mucks.map(\.latitude)
        let lons = mucks.map(\.longitude)
        let centre = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lons.min()! + lons.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((lats.max()! - lats.min()!) * 1.8, 0.01),
            longitudeDelta: max((lons.max()! - lons.min()!) * 1.8, 0.01)
        )
        withAnimation {
            cameraPosition = .region(MKCoordinateRegion(center: centre, span: span))
        }
    }
}

// MARK: - Suggested Muck Card (horizontal carousel)

private struct MuckSuggestionCard: View {
    let muck: Muck
    let distance: String?
    let isSelected: Bool
    let onTapCard: () -> Void
    let onToggle: () -> Void

    var body: some View {
        Button(action: onTapCard) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    thumbnail
                        .frame(width: 168, height: 90)
                        .clipped()

                    Button(action: onToggle) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(isSelected ? Color.muckGreen : .white)
                            .background(Circle().fill(isSelected ? .white : Color.muckNearBlack.opacity(0.4)))
                            .clipShape(Circle())
                    }
                    .padding(6)

                    VStack {
                        Spacer()
                        HStack {
                            Label("\(muck.votes)", systemImage: "arrow.up")
                                .font(.muckMicro)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.muckNearBlack.opacity(0.55))
                                .clipShape(Capsule())
                            Spacer()
                        }
                        .padding(6)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(muck.location)
                        .font(.muckCaption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.muckNearBlack)
                        .lineLimit(1)
                    HStack {
                        TypeBadgeView(type: muck.type, compact: true)
                        if let distance {
                            Text(distance)
                                .font(.muckMicro)
                                .foregroundStyle(Color.muckNearBlack.opacity(0.4))
                        }
                    }
                }
                .padding(Spacing.xs)
            }
            .frame(width: 168)
            .background(Color.muckSurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .strokeBorder(isSelected ? Color.muckGreen : Color.muckNearBlack.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = muck.photoData, let ui = UIImage(data: data) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Color.muckTypeColor(muck.type).opacity(0.15)
                Image(systemName: muck.type.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(Color.muckTypeColor(muck.type))
            }
        }
    }
}

// MARK: - Awareness Row

// MARK: - Muck Picker Card (full list, vertical)

private struct MuckPickerCard: View {
    let muck: Muck
    let isSelected: Bool
    let distance: String?
    let onTapCard: () -> Void
    let onToggle: () -> Void

    var body: some View {
        Button(action: onTapCard) {
            HStack(spacing: Spacing.sm) {
                thumbnail
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm))

                VStack(alignment: .leading, spacing: 2) {
                    Text(muck.location)
                        .font(.muckHeadline)
                        .foregroundStyle(Color.muckNearBlack)
                    Text(muck.muckDescription)
                        .font(.muckBody)
                        .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                        .lineLimit(1)
                    HStack(spacing: Spacing.xs) {
                        TypeBadgeView(type: muck.type, compact: true)
                        if let distance {
                            Text(distance)
                                .font(.muckMicro)
                                .foregroundStyle(Color.muckNearBlack.opacity(0.35))
                        }
                        Label("\(muck.votes)", systemImage: "arrow.up")
                            .font(.muckMicro)
                            .foregroundStyle(Color.muckNearBlack.opacity(0.35))
                    }
                }

                Spacer()

                Button(action: onToggle) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                        .font(.system(size: 24))
                        .foregroundStyle(isSelected ? Color.muckGreen : Color.muckNearBlack.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
            .padding(Spacing.xs)
            .background(Color.muckSurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .strokeBorder(isSelected ? Color.muckGreen.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = muck.photoData, let ui = UIImage(data: data) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Color.muckTypeColor(muck.type).opacity(0.15)
                Image(systemName: muck.type.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(Color.muckTypeColor(muck.type))
            }
        }
    }
}

// MARK: - Quick Look Sheet

private struct MuckQuickLookSheet: View {
    let muck: Muck
    let isSelected: Bool
    let distance: String?
    let onToggle: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var localSelected: Bool

    init(muck: Muck, isSelected: Bool, distance: String?, onToggle: @escaping () -> Void) {
        self.muck = muck
        self.isSelected = isSelected
        self.distance = distance
        self.onToggle = onToggle
        _localSelected = State(initialValue: isSelected)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    if let data = muck.photoData, let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    }

                    HStack {
                        TypeBadgeView(type: muck.type)
                        Spacer()
                        Label("\(muck.votes) votes", systemImage: "arrow.up")
                            .font(.muckCaption)
                            .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                    }

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Label(muck.location, systemImage: "mappin.circle.fill")
                            .font(.muckTitle)
                            .foregroundStyle(Color.muckNearBlack)
                        HStack(spacing: Spacing.xs) {
                            if let distance {
                                Text("\(distance) away")
                                    .font(.muckCaption)
                                    .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                            }
                            Text(muck.reportedDate, style: .date)
                                .font(.muckCaption)
                                .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                        }
                    }

                    Text(muck.muckDescription)
                        .font(.muckBody)
                        .foregroundStyle(Color.muckNearBlack.opacity(0.8))

                    if muck.eventCount > 0 {
                        Label("\(muck.eventCount) other event\(muck.eventCount == 1 ? "" : "s") already linked", systemImage: "calendar")
                            .font(.muckCaption)
                            .foregroundStyle(Color.muckGreen)
                    }

                    PrimaryButton(
                        title: localSelected ? "Added to this Event" : "Add to this Event",
                        icon: localSelected ? "checkmark" : "plus"
                    ) {
                        onToggle()
                        localSelected.toggle()
                    }
                    .padding(.top, Spacing.xs)
                }
                .padding(Spacing.md)
            }
            .background(Color.muckBg)
            .navigationTitle("Muck Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.muckNearBlack)
                }
            }
        }
    }
}

// MARK: - Event Saved

struct EventSavedView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var celebrate = false

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 72))
                .foregroundStyle(Color.muckGreen)
                .confettiBurst(trigger: $celebrate)
            Text("Event Scheduled!")
                .font(.muckDisplay)
                .foregroundStyle(Color.muckNearBlack)
            Text("+5 Muck Points earned")
                .font(.muckHeadline)
                .foregroundStyle(Color.muckAmber)
            Text("Confirmation and details will be sent to your registered email.")
                .font(.muckBody)
                .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
            Spacer()
            PrimaryButton(title: "Back to Home") {
                dismiss()
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
        .background(Color.muckBg.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .onAppear { celebrate = true }
    }
}
