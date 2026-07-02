import Foundation
import CoreLocation

/// Fetches two small, static Brisbane City Council location datasets —
/// community composting hubs (24 sites) and resource recovery / waste
/// transfer stations (4 sites). Neither dataset has a date field (these
/// are permanent facilities, not events) or a per-item web link, so a
/// generic council waste-services page is used as the fallback URL.
final class WasteResourceLocationsService {
    static let shared = WasteResourceLocationsService()
    private init() {}

    private let compostingURL = "https://data.brisbane.qld.gov.au/api/explore/v2.1/catalog/datasets/community-composting-hub-locations/records"
    private let transferStationURL = "https://data.brisbane.qld.gov.au/api/explore/v2.1/catalog/datasets/waste-transfer-stations/records"
    private let fallbackLink = URL(string: "https://www.brisbane.qld.gov.au/clean-and-green/rubbish-and-recycling")!

    func fetchCompostingHubs() async -> [PartnerItem] {
        guard let url = URL(string: compostingURL + "?limit=50") else { return [] }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(CompostingResponse.self, from: data)
            return decoded.results.compactMap { record in
                guard let name = record.name else { return nil }
                return PartnerItem(
                    id: "compost-\(name.hashValue)",
                    name: name,
                    organisation: "Brisbane City Council",
                    source: .compostingHub,
                    latitude: record.latitude,
                    longitude: record.longitude,
                    date: nil,
                    itemDescription: [record.location, record.suburb].compactMap { $0 }.joined(separator: ", "),
                    externalURL: fallbackLink
                )
            }
        } catch {
            print("⚠️ Composting hub fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    func fetchWasteTransferStations() async -> [PartnerItem] {
        guard let url = URL(string: transferStationURL + "?limit=20") else { return [] }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(TransferStationResponse.self, from: data)
            return decoded.results.compactMap { record in
                guard let name = record.name else { return nil }
                var detail = record.address ?? ""
                if let hours = record.openingHours { detail += detail.isEmpty ? hours : " · \(hours)" }
                return PartnerItem(
                    id: "waste-\(name.hashValue)",
                    name: "\(name) Resource Recovery Centre",
                    organisation: "Brisbane City Council",
                    source: .wasteTransferStation,
                    latitude: record.latitude,
                    longitude: record.longitude,
                    date: nil,
                    itemDescription: detail,
                    externalURL: fallbackLink
                )
            }
        } catch {
            print("⚠️ Waste transfer station fetch failed: \(error.localizedDescription)")
            return []
        }
    }
}

// MARK: - Response models

private struct CompostingResponse: Decodable {
    let results: [CompostingRecord]
}

private struct CompostingRecord: Decodable {
    let name: String?
    let location: String?
    let suburb: String?
    let latitude: Double
    let longitude: Double
}

private struct TransferStationResponse: Decodable {
    let results: [TransferStationRecord]
}

private struct TransferStationRecord: Decodable {
    let name: String?
    let address: String?
    let latitude: Double
    let longitude: Double
    let openingHours: String?

    enum CodingKeys: String, CodingKey {
        case name, address, latitude, longitude
        case openingHours = "opening_hours"
    }
}
