import SwiftUI
import CoreLocation

@MainActor
final class AwarenessViewModel: ObservableObject {
    @Published var waterwayItems: [AwarenessItem] = []
    @Published var isLoading = false

    /// Map-pinnable items only — animal complaints have no coordinates.
    var mapItems: [AwarenessItem] { waterwayItems }

    func loadWaterwayData() async {
        guard waterwayItems.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        waterwayItems = await WaterwaySafetyService.shared.fetchAll()
    }

    /// "Things to be aware of" near a specific point — nearby waterway
    /// readings plus the suburb-level animal complaint summary for
    /// wherever that point reverse-geocodes to.
    func fetchNearby(_ coordinate: CLLocationCoordinate2D, radiusMetres: Double = 5000) async -> [AwarenessItem] {
        if waterwayItems.isEmpty {
            await loadWaterwayData()
        }
        let centre = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let nearbyWaterway = waterwayItems.filter { item in
            guard let itemCoord = item.coordinate else { return false }
            let loc = CLLocation(latitude: itemCoord.latitude, longitude: itemCoord.longitude)
            return loc.distance(from: centre) <= radiusMetres
        }

        var animalItem: AwarenessItem?
        if let suburb = await reverseGeocodeSuburb(coordinate) {
            animalItem = await AnimalComplaintsService.shared.fetchSummary(suburb: suburb)
        }

        return nearbyWaterway + [animalItem].compactMap { $0 }
    }

    private func reverseGeocodeSuburb(_ coordinate: CLLocationCoordinate2D) async -> String? {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            return placemarks.first?.locality
        } catch {
            return nil
        }
    }
}
