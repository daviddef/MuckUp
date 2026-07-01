import SwiftUI
import MapKit
import CoreLocation

/// Small pannable map on the Home screen. As the user drags the map around,
/// `onRegionChange` reports the new centre + approximate radius so the list
/// below can re-filter to whatever area is currently in view.
struct HomeMiniMapView: View {
    let mucks: [Muck]
    let userLocation: CLLocation?
    let onSelectMuck: (Muck) -> Void
    let onRegionChange: (CLLocationCoordinate2D, Double) -> Void

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var hasCentered = false
    @State private var hasReceivedLiveLocation = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Map(position: $cameraPosition) {
                UserAnnotation()
                ForEach(mucks) { muck in
                    Annotation(muck.location, coordinate: muck.coordinate) {
                        MuckMapMarker(muck: muck)
                            .onTapGesture { onSelectMuck(muck) }
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .onMapCameraChange(frequency: .continuous) { context in
                let radiusMetres = (context.region.span.latitudeDelta / 2) * 111_000
                onRegionChange(context.region.center, radiusMetres)
            }

            // Re-centre button
            Button {
                if let userLocation {
                    withAnimation {
                        cameraPosition = .camera(MapCamera(centerCoordinate: userLocation.coordinate, distance: 3000))
                    }
                }
            } label: {
                Image(systemName: "location.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.muckGreen)
                    .frame(width: 32, height: 32)
                    .background(.regularMaterial)
                    .clipShape(Circle())
                    .muckFloatShadow()
            }
            .padding(Spacing.xs)
        }
        .frame(height: 190)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .strokeBorder(Color.muckNearBlack.opacity(0.08))
        )
        .padding(.horizontal, Spacing.md)
        .onAppear {
            guard !hasCentered else { return }
            hasCentered = true
            let centre = userLocation?.coordinate
                ?? CLLocationCoordinate2D(latitude: -37.8136, longitude: 144.9631)
            cameraPosition = .camera(MapCamera(centerCoordinate: centre, distance: 3000))
        }
        .onChange(of: userLocation != nil) { _, hasLocation in
            // Re-centre the first time we get a real GPS fix — but only once,
            // so we don't fight the user if they've already panned around.
            guard hasLocation, !hasReceivedLiveLocation, let loc = userLocation else { return }
            hasReceivedLiveLocation = true
            withAnimation {
                cameraPosition = .camera(MapCamera(centerCoordinate: loc.coordinate, distance: 3000))
            }
        }
    }
}
