import Foundation
import CoreLocation

/// Reads Brisbane City Council's planned hazard-reduction burns dataset.
/// Each record is really a polygon (the burn area boundary) but we only
/// use its centroid (`geo_point_2d`) for the map marker — rendering the
/// actual polygon outline is a reasonable future upgrade, not done here.
///
/// Dataset ID is year-versioned ("planned-burns-2026") same caveat as
/// the waterway safety dataset — needs a manual bump each year.
final class PlannedBurnsService {
    static let shared = PlannedBurnsService()
    private init() {}

    private let datasetURL = "https://data.brisbane.qld.gov.au/api/explore/v2.1/catalog/datasets/planned-burns-2026/records"

    func fetchAll() async -> [AwarenessItem] {
        guard var components = URLComponents(string: datasetURL) else { return [] }
        components.queryItems = [URLQueryItem(name: "limit", value: "100")]
        guard let url = components.url else { return [] }

        do {
            let (data, _) = try await URLSession.grubData.data(from: url)
            let decoded = try JSONDecoder().decode(BurnsResponse.self, from: data)
            return decoded.results.compactMap { record in
                guard let name = record.parkname else { return nil }
                let areaText = record.areaOfBl.map { String(format: "%.1f ha", $0) } ?? "unknown area"
                return AwarenessItem(
                    id: "burn-\(name.hashValue)-\(record.locality ?? "")",
                    category: .plannedBurn,
                    title: "Planned burn — \(name)",
                    detail: "\(record.locality.map { "\($0). " } ?? "")Hazard-reduction burn covering approx. \(areaText). Status: \(record.status ?? "Planned"). Avoid the area if smoke or closures are visible.",
                    severity: .caution,
                    coordinate: CLLocationCoordinate2D(latitude: record.geoPoint2d.lat, longitude: record.geoPoint2d.lon),
                    date: nil
                )
            }
        } catch {
            print("⚠️ Planned burns fetch failed: \(error.localizedDescription)")
            return []
        }
    }
}

// MARK: - Response models

private struct BurnsResponse: Decodable {
    let results: [BurnRecord]
}

private struct BurnRecord: Decodable {
    let parkname: String?
    let locality: String?
    let status: String?
    let areaOfBl: Double?
    let geoPoint2d: GeoPoint2D

    enum CodingKeys: String, CodingKey {
        case parkname, locality, status
        case areaOfBl = "area_of_bl"
        case geoPoint2d = "geo_point_2d"
    }
}

private struct GeoPoint2D: Decodable {
    let lon: Double
    let lat: Double
}
