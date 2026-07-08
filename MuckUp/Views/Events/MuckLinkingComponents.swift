import SwiftUI
import MapKit
import CoreLocation

// Pulled out of ScheduleEventView (which had grown past 900 lines) — these
// four views are only ever used from the muck-linking section of that
// screen, but are fully self-contained (no dependency on its state beyond
// what's passed in), so moving them costs nothing and makes the main
// file's structure legible at a glance.

// MARK: - Selected Mucks Proximity Map

struct SelectedMucksMapView: View {
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

struct MuckSuggestionCard: View {
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

struct MuckPickerCard: View {
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

struct MuckQuickLookSheet: View {
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
