import SwiftUI
import MapKit
import SwiftData

/// Small preview map on a muck's detail screen — shows the muck itself
/// plus any other nearby mucks, so a viewer can see it in local context.
struct MuckMiniMapView: View {
    let muck: Muck
    @Query private var allMucks: [Muck]

    @State private var cameraPosition: MapCameraPosition
    @State private var showFullMap = false

    private let nearbyRadiusMetres: Double = 1500

    init(muck: Muck) {
        self.muck = muck
        _cameraPosition = State(initialValue: .camera(
            MapCamera(centerCoordinate: muck.coordinate, distance: 2200)
        ))
    }

    private var nearbyMucks: [Muck] {
        let centre = CLLocation(latitude: muck.latitude, longitude: muck.longitude)
        return allMucks.filter { other in
            guard other.id != muck.id else { return false }
            let loc = CLLocation(latitude: other.latitude, longitude: other.longitude)
            return loc.distance(from: centre) <= nearbyRadiusMetres
        }
    }

    var body: some View {
        Button {
            showFullMap = true
        } label: {
            ZStack(alignment: .bottomTrailing) {
                Map(position: $cameraPosition, interactionModes: []) {
                    Annotation(muck.location, coordinate: muck.coordinate) {
                        MuckMapMarker(muck: muck)
                    }
                    ForEach(nearbyMucks) { other in
                        Annotation(other.location, coordinate: other.coordinate) {
                            MuckMapMarker(muck: other)
                                .opacity(0.7)
                                .scaleEffect(0.8)
                        }
                    }
                }
                .mapStyle(.standard(elevation: .flat))
                .disabled(true)
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))

                if !nearbyMucks.isEmpty {
                    Label("\(nearbyMucks.count) nearby", systemImage: "mappin.and.ellipse")
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
        .sheet(isPresented: $showFullMap) {
            NavigationStack {
                MapViewScreen()
            }
        }
    }
}
