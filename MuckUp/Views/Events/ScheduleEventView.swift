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

    // Radius thresholds in metres
    private let nearbyRadius: Double = 10_000   // 10 km
    private let expandedRadiusKm: Double = 50_000  // 50 km

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
                            MuckPickerRow(
                                muck: muck,
                                isSelected: selectedMuckIds.contains(muck.id),
                                distance: muck.distance(from: locationService.location)
                            ) {
                                toggleMuck(muck)
                            }
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

// MARK: - Muck Picker Row

private struct MuckPickerRow: View {
    let muck: Muck
    let isSelected: Bool
    let distance: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Color.muckGreen : Color.muckNearBlack.opacity(0.25))
                    .animation(.easeInOut(duration: 0.15), value: isSelected)

                VStack(alignment: .leading, spacing: 2) {
                    Text(muck.location)
                        .font(.muckHeadline)
                        .foregroundStyle(Color.muckNearBlack)
                    Text(muck.muckDescription)
                        .font(.muckBody)
                        .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    TypeBadgeView(type: muck.type, compact: true)
                    if let d = distance {
                        Text(d)
                            .font(.muckMicro)
                            .foregroundStyle(Color.muckNearBlack.opacity(0.35))
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
