import Foundation
import CoreLocation

/// Fetches environment/cleanup-flavoured events from Brisbane City Council's
/// public OpenDataSoft Explore v2.1 API — no API key required.
///
/// Docs: https://help.opendatasoft.com/apis/ods-explore-v2/#tag/Dataset/operation/getRecords
/// Dataset: https://data.brisbane.qld.gov.au/explore/dataset/brisbane-city-council-events/
final class BrisbaneEventsService {
    static let shared = BrisbaneEventsService()
    private init() {}

    private let baseURL = "https://data.brisbane.qld.gov.au/api/explore/v2.1/catalog/datasets/brisbane-city-council-events/records"

    /// Default radius, used both to scope the API query and to decide
    /// whether it's even worth calling — Brisbane-only dataset, so anyone
    /// far away (e.g. Melbourne, where the rest of Grub's mock data
    /// lives) gets nothing rather than a pile of irrelevant interstate
    /// results. Callers can widen/narrow this via Find's radius slider.
    static let defaultSearchRadiusMetres: Double = 30_000

    func fetchNearby(_ location: CLLocation, radiusMetres: Double = BrisbaneEventsService.defaultSearchRadiusMetres) async -> [PartnerItem] {
        // Brisbane CBD-ish bounding check — cheap guard before hitting the network.
        let brisbane = CLLocation(latitude: -27.4698, longitude: 153.0251)
        guard location.distance(from: brisbane) < max(60_000, radiusMetres) else { return [] }

        guard var components = URLComponents(string: baseURL) else { return [] }
        let today = ISO8601DateFormatter().string(from: .now)
        let point = "POINT(\(location.coordinate.longitude) \(location.coordinate.latitude))"

        components.queryItems = [
            URLQueryItem(name: "where", value: #"event_type="Green" and start_datetime>"\#(today)" and distance(geolocation, geom'\#(point)', \#(Int(radiusMetres))m)"#),
            URLQueryItem(name: "order_by", value: "start_datetime asc"),
            URLQueryItem(name: "limit", value: "30"),
        ]

        guard let url = components.url else { return [] }

        do {
            let (data, _) = try await URLSession.grubData.data(from: url)
            let decoded = try JSONDecoder().decode(ODSResponse.self, from: data)
            return decoded.results.compactMap { $0.toPartnerItem() }
        } catch {
            print("⚠️ Brisbane events fetch failed: \(error.localizedDescription)")
            return []
        }
    }
}

// MARK: - Response models

private struct ODSResponse: Decodable {
    let results: [ODSEventRecord]
}

private struct ODSEventRecord: Decodable {
    let subject: String?
    let description: String?
    let venue: String?
    let venueaddress: String?
    let startDatetime: String?
    let webLink: String?
    let cost: String?
    let geolocation: ODSGeoLocation?

    enum CodingKeys: String, CodingKey {
        case subject, description, venue, venueaddress, cost, geolocation
        case startDatetime = "start_datetime"
        case webLink = "web_link"
    }

    func toPartnerItem() -> PartnerItem? {
        guard let subject, let geolocation, let webLink, let url = URL(string: webLink) else { return nil }
        let date = startDatetime.flatMap { ISO8601DateFormatter().date(from: $0) }

        return PartnerItem(
            id: "brisbane-\(subject.hashValue)-\(startDatetime ?? "")",
            name: subject,
            organisation: "Brisbane City Council",
            source: .brisbaneEvents,
            latitude: geolocation.lat,
            longitude: geolocation.lon,
            date: date,
            itemDescription: venueaddress ?? venue ?? description,
            externalURL: url
        )
    }
}

private struct ODSGeoLocation: Decodable {
    let lon: Double
    let lat: Double
}
