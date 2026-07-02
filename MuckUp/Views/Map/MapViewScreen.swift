import SwiftUI
import MapKit
import SwiftData

struct MapViewScreen: View {
    @Query private var allMucks: [Muck]
    @EnvironmentObject var muckVM: MuckViewModel
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var partnerVM: PartnerViewModel
    @EnvironmentObject var awarenessVM: AwarenessViewModel

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedMuck: Muck? = nil
    @State private var showPartnerPanel = false
    @State private var selectedAwarenessItem: AwarenessItem? = nil

    private var visibleMucks: [Muck] {
        let filtered = muckVM.filtered(allMucks)
        // Hide partner markers when type filter is active (done via partnerVM)
        return filtered
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $cameraPosition) {
                // User location
                UserAnnotation()

                // Muck markers
                ForEach(visibleMucks) { muck in
                    Annotation(muck.location, coordinate: muck.coordinate) {
                        MuckMapMarker(muck: muck)
                            .onTapGesture { selectedMuck = muck }
                    }
                }

                // Partner markers — hidden when type filter active
                if muckVM.typeFilter == nil {
                    ForEach(partnerVM.filteredItems) { item in
                        Annotation(item.name, coordinate: CLLocationCoordinate2D(latitude: item.latitude, longitude: item.longitude)) {
                            PartnerMapMarker(source: item.source)
                        }
                    }
                }

                // Area awareness markers (waterway safety, etc.) — only
                // shown when the Hazard type filter is active, same
                // convention as partner markers hiding under a type filter.
                if muckVM.typeFilter == .hazard {
                    ForEach(awarenessVM.mapItems) { item in
                        if let coordinate = item.coordinate {
                            Annotation(item.title, coordinate: coordinate) {
                                AwarenessMapMarker(item: item)
                                    .onTapGesture { selectedAwarenessItem = item }
                            }
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .ignoresSafeArea(edges: .bottom)

            // Type filter bar overlay
            VStack {
                TypeFilterBar(selection: $muckVM.typeFilter)
                    .padding(.top, Spacing.xs)
                    .background(.regularMaterial)
                Spacer()
            }

            // Partner panel toggle
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        withAnimation { showPartnerPanel.toggle() }
                    } label: {
                        Label("Partners", systemImage: "building.2")
                            .font(.muckHeadline)
                            .foregroundStyle(Color.muckNearBlack)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.xs)
                            .background(.regularMaterial)
                            .clipShape(Capsule())
                            .muckFloatShadow()
                    }
                    .padding(.trailing, Spacing.md)
                    .padding(.bottom, Spacing.md)
                }
            }
        }
        .sheet(item: $selectedMuck) { muck in
            ViewMuckView(muck: muck)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showPartnerPanel) {
            PartnerSourcesPanel()
                .presentationDetents([.height(360)])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedAwarenessItem) { item in
            AwarenessDetailSheet(item: item)
        }
        .task {
            await awarenessVM.loadWaterwayData()
            await awarenessVM.loadBurnData()
            // Hazard data (Brisbane waterway sites + planned burns) is
            // spread across the whole metro area — a tight zoom on the
            // user's own location means none of it is ever in frame.
            // Fit the camera to actually show it when the filter is on.
            if muckVM.typeFilter == .hazard {
                fitCameraToAwareness()
            }
        }
        .onChange(of: muckVM.typeFilter) { _, newValue in
            if newValue == .hazard {
                fitCameraToAwareness()
            }
        }
        .navigationTitle("Map")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let loc = locationService.location {
                cameraPosition = .camera(MapCamera(centerCoordinate: loc.coordinate, distance: 5000))
            } else {
                // Default to Melbourne CBD
                cameraPosition = .camera(MapCamera(
                    centerCoordinate: CLLocationCoordinate2D(latitude: -37.8136, longitude: 144.9631),
                    distance: 8000
                ))
            }
            partnerVM.loadMockData()
        }
    }

    private func fitCameraToAwareness() {
        let coordinates = awarenessVM.mapItems.compactMap(\.coordinate)
        guard !coordinates.isEmpty else { return }

        let lats = coordinates.map(\.latitude)
        let lons = coordinates.map(\.longitude)
        let centre = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lons.min()! + lons.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((lats.max()! - lats.min()!) * 1.4, 0.05),
            longitudeDelta: max((lons.max()! - lons.min()!) * 1.4, 0.05)
        )
        withAnimation {
            cameraPosition = .region(MKCoordinateRegion(center: centre, span: span))
        }
    }
}

// MARK: - Map Markers

struct MuckMapMarker: View {
    let muck: Muck

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.muckTypeColor(muck.type))
                .frame(width: 32, height: 32)
            Image(systemName: muck.type.icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
        .overlay(
            Circle().strokeBorder(.white, lineWidth: 2)
        )
        .shadow(radius: 3)
    }
}

struct PartnerMapMarker: View {
    let source: PartnerSource

    var body: some View {
        Text(source.emoji)
            .font(.system(size: 20))
            .padding(Spacing.xxs)
            .background(Color.partnerColor(source).opacity(0.15))
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Color.partnerColor(source).opacity(0.4), lineWidth: 1))
    }
}

// MARK: - Partner Sources Panel

struct PartnerSourcesPanel: View {
    @EnvironmentObject var partnerVM: PartnerViewModel

    var body: some View {
        NavigationStack {
            List {
                ForEach(PartnerSource.allCases) { source in
                    HStack {
                        Text(source.emoji)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(source.displayName)
                                .font(.muckHeadline)
                                .foregroundStyle(Color.muckNearBlack)
                            Text("\(partnerVM.items.filter { $0.source == source }.count) items nearby")
                                .font(.muckCaption)
                                .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { partnerVM.enabledSources.contains(source) },
                            set: { _ in partnerVM.toggleSource(source) }
                        ))
                        .tint(Color.partnerColor(source))
                        .labelsHidden()
                    }
                }
            }
            .navigationTitle("Partner Sources")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
