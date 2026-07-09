import Foundation
import CoreLocation

/// Fetches Brisbane City Council's "Gold Events" dataset — the Growing
/// Old (Living) program's community events for seniors. Surfaced
/// primarily in the Help tab (near the Companionship/Respite request
/// categories) rather than Find, though it's still a PartnerSource so
/// it inherits the standard map/Find visibility too.
final class GoldEventsService {
    static let shared = GoldEventsService()
    private init() {}

    private let baseURL = "https://data.brisbane.qld.gov.au/api/explore/v2.1/catalog/datasets/gold-events/records"
    static let defaultSearchRadiusMetres: Double = 30_000

    func fetchNearby(_ location: CLLocation, radiusMetres: Double = GoldEventsService.defaultSearchRadiusMetres) async -> [PartnerItem] {
        let brisbane = CLLocation(latitude: -27.4698, longitude: 153.0251)
        guard location.distance(from: brisbane) < max(60_000, radiusMetres) else { return [] }

        guard var components = URLComponents(string: baseURL) else { return [] }
        let today = ISO8601DateFormatter().string(from: .now)
        let point = "POINT(\(location.coordinate.longitude) \(location.coordinate.latitude))"

        components.queryItems = [
            URLQueryItem(name: "where", value: #"start_datetime>"\#(today)" and distance(geolocation, geom'\#(point)', \#(Int(radiusMetres))m)"#),
            URLQueryItem(name: "order_by", value: "start_datetime asc"),
            URLQueryItem(name: "limit", value: "30"),
        ]

        guard let url = components.url else { return [] }

        do {
            let (data, _) = try await URLSession.grubData.data(from: url)
            let decoded = try JSONDecoder().decode(ODSGenericEventsResponse.self, from: data)
            return decoded.results.compactMap { $0.toPartnerItem(source: .goldEvents, idPrefix: "gold") }
        } catch {
            print("⚠️ Gold events fetch failed: \(error.localizedDescription)")
            return []
        }
    }
}
