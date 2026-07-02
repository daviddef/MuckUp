import Foundation

/// Shared decode shape for Brisbane City Council's Trumba-sourced event
/// datasets (parks events, gold/seniors events, and others with the same
/// field layout as green-events/brisbane-city-council-events).
struct ODSGenericEventsResponse: Decodable {
    let results: [ODSGenericEventRecord]
}

struct ODSGenericEventRecord: Decodable {
    let subject: String?
    let description: String?
    let venue: String?
    let venueaddress: String?
    let startDatetime: String?
    let webLink: String?
    let cost: String?
    let geolocation: ODSGenericGeoLocation?

    enum CodingKeys: String, CodingKey {
        case subject, description, venue, venueaddress, cost, geolocation
        case startDatetime = "start_datetime"
        case webLink = "web_link"
    }

    func toPartnerItem(source: PartnerSource, idPrefix: String) -> PartnerItem? {
        guard let subject, let geolocation, let webLink, let url = URL(string: webLink) else { return nil }
        let date = startDatetime.flatMap { ISO8601DateFormatter().date(from: $0) }

        return PartnerItem(
            id: "\(idPrefix)-\(subject.hashValue)-\(startDatetime ?? "")",
            name: subject,
            organisation: "Brisbane City Council",
            source: source,
            latitude: geolocation.lat,
            longitude: geolocation.lon,
            date: date,
            itemDescription: venueaddress ?? venue ?? description,
            externalURL: url
        )
    }
}

struct ODSGenericGeoLocation: Decodable {
    let lon: Double
    let lat: Double
}
