import SwiftUI
import SwiftData
import CoreLocation

struct ScheduleEventView: View {
    var preselectedMuck: Muck?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var muckVM: MuckViewModel
    @EnvironmentObject var locationService: LocationService
    @Query private var allMucks: [Muck]

    @State private var title = ""
    @State private var description = ""
    @State private var eventDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    @State private var selectedMuckIds: Set<String> = []
    @State private var isSaved = false
    @State private var muckSearch = ""
    @State private var expandedRadius = false
    @State private var quickLookMuck: Muck?

    // Radius thresholds in metres
    private let nearbyRadius: Double = 10_000   // 10 km
    private let expandedRadiusKm: Double = 50_000  // 50 km
    private let suggestionCount = 5

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

    private var visibleMucks: [Muck] {
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

    // Top-voted, nearby, not-yet-selected mucks — a nudge, not a requirement
    private var suggestedMucks: [Muck] {
        guard muckSearch.isEmpty else { return [] }
        let radius = expandedRadius ? expandedRadiusKm : nearbyRadius
        let userLoc = locationService.location
        return eligibleMucks
            .filter { muck in
                !selectedMuckIds.contains(muck.id) &&
                (userLoc == nil || distanceMetres(muck, from: userLoc) <= radius) &&
                muck.votes > 0
            }
            .sorted { $0.votes > $1.votes }
            .prefix(suggestionCount)
            .map { $0 }
    }

    // Mucks that exist but are outside the current radius (and not selected)
    private var hiddenCount: Int {
        guard !expandedRadius, locationService.location != nil else { return 0 }
        return eligibleMucks.filter { muck in
            !selectedMuckIds.contains(muck.id) &&
            distanceMetres(muck, from: locationService.location) > nearbyRadius
        }.count
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && !selectedMuckIds.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                // ── Suggested mucks ──────────────────────────────────
                if !suggestedMucks.isEmpty {
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
                        Text("Based on votes and proximity. Optional — add any that fit.")
                            .font(.muckMicro)
                            .foregroundStyle(Color.muckNearBlack.opacity(0.4))
                    }
                }

                // ── Muck picker ──────────────────────────────────────
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
        }
        .onAppear {
            if let muck = preselectedMuck {
                selectedMuckIds.insert(muck.id)
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

    private func createEvent() {
        let event = MuckEvent(
            title: title,
            location: allMucks.first(where: { selectedMuckIds.contains($0.id) })?.location ?? "",
            date: eventDate,
            description: description,
            muckIds: Array(selectedMuckIds),
            participants: 1,
            isAttending: true
        )
        modelContext.insert(event)
        for id in selectedMuckIds {
            allMucks.first(where: { $0.id == id })?.eventCount += 1
        }
        muckVM.award(.participate)
        isSaved = true
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

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 72))
                .foregroundStyle(Color.muckGreen)
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
    }
}
