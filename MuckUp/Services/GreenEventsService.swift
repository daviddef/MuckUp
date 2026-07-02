import Foundation
import CoreLocation

/// Fetches Brisbane City Council's "Green Events" dataset — a small,
/// already-curated list of nature/sustainability events (26 records at
/// time of writing), distinct from the larger general events feed.
///
/// Same OpenDataSoft Explore v2.1 shape as BrisbaneEventsService — kept
/// as its own file rather than a shared abstraction, matching how each
/// partner integration in this app gets its own small service file.
final class GreenEventsService {
    static let shared = GreenEventsService()
    private init() {}

    private let baseURL = "https://data.brisbane.qld.gov.au/api/explore/v2.1/catalog/datasets/green-events/records"
    private let searchRadiusMetres = 30_000

    func fetchNearby(_ location: CLLocation) async -> [PartnerItem] {
        let brisbane = CLLocation(latitude: -27.4698, longitude: 153.0251)
        guard location.distance(from: brisbane) < 60_000 else { return [] }

        guard var components = URLComponents(string: baseURL) else { return [] }
        let today = ISO8601DateFormatter().string(from: .now)
        let point = "POINT(\(location.coordinate.longitude) \(location.coordinate.latitude))"

        components.queryItems = [
            URLQueryItem(name: "where", value: #"start_datetime>"\#(today)" and distance(geolocation, geom'\#(point)', \#(searchRadiusMetres)m)"#),
            URLQueryItem(name: "order_by", value: "start_datetime asc"),
            URLQueryItem(name: "limit", value: "30"),
        ]

        guard let url = components.url else { return [] }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(ODSGreenEventsResponse.self, from: data)
            return decoded.results.compactMap { $0.toPartnerItem() }
        } catch {
            print("⚠️ Green events fetch failed: \(error.localizedDescription)")
            return []
        }
    }
}

// MARK: - Response models

private struct ODSGreenEventsResponse: Decodable {
    let results: [ODSGreenEventRecord]
}

private struct ODSGreenEventRecord: Decodable {
    let subject: String?
    let description: String?
    let venue: String?
    let venueaddress: String?
    let startDatetime: String?
    let webLink: String?
    let cost: String?
    let geolocation: ODSGreenGeoLocation?

    enum CodingKeys: String, CodingKey {
        case subject, description, venue, venueaddress, cost, geolocation
        case startDatetime = "start_datetime"
        case webLink = "web_link"
    }

    func toPartnerItem() -> PartnerItem? {
        guard let subject, let geolocation, let webLink, let url = URL(string: webLink) else { return nil }
        let date = startDatetime.flatMap { ISO8601DateFormatter().date(from: $0) }

        return PartnerItem(
            id: "green-\(subject.hashValue)-\(startDatetime ?? "")",
            name: subject,
            organisation: "Brisbane City Council",
            source: .greenEvents,
            latitude: geolocation.lat,
            longitude: geolocation.lon,
            date: date,
            itemDescription: venueaddress ?? venue ?? description,
            externalURL: url
        )
    }
}

private struct ODSGreenGeoLocation: Decodable {
    let lon: Double
    let lat: Double
}
