import Foundation
import CoreLocation

/// Reads Brisbane City Council's recreational enterococci monitoring
/// dataset — river/creek bacterial safety readings at fixed sites.
///
/// This dataset is unusually shaped: each test date is its own column
/// (e.g. "18_07_2025"), not a row, so the column names change every time
/// a new sample is taken. We can't model that with Codable field names —
/// instead we decode each record as a raw JSON dictionary and pick out
/// whichever keys look like dates, then take the most recent non-blank
/// reading.
///
/// The dataset ID itself is year-versioned by Brisbane City Council
/// (rolls over every July) — hardcoded to the current year below.
/// NEEDS A MANUAL UPDATE around July each year when the council
/// publishes the next one.
final class WaterwaySafetyService {
    static let shared = WaterwaySafetyService()
    private init() {}

    private let datasetURL = "https://data.brisbane.qld.gov.au/api/explore/v2.1/catalog/datasets/waterway-health-recreational-enterococci-monitoring-results-2025-2026/records"

    // NHMRC-style single-sample recreational water guideline thresholds
    // for enterococci (CFU/100mL). Approximate general guidance, not an
    // official real-time regulatory determination — always defer to
    // council signage for actual swim/fish advisories.
    private let cautionThreshold = 41.0
    private let warningThreshold = 280.0

    func fetchAll() async -> [AwarenessItem] {
        guard var components = URLComponents(string: datasetURL) else { return [] }
        components.queryItems = [URLQueryItem(name: "limit", value: "50")]
        guard let url = components.url else { return [] }

        do {
            let (data, _) = try await URLSession.grubData.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]] else { return [] }
            return results.compactMap { parseRecord($0) }
        } catch {
            print("⚠️ Waterway safety fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    private func parseRecord(_ record: [String: Any]) -> AwarenessItem? {
        guard let siteName = record["site_name"] as? String,
              let lat = record["lat"] as? Double,
              let lon = record["lon"] as? Double else { return nil }

        let description = record["location_description"] as? String ?? siteName

        // Date-shaped keys look like "18_07_2025" — dd_MM_yyyy.
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd_MM_yyyy"

        let readings: [(date: Date, value: Double)] = record.compactMap { key, value in
            guard let date = dateFormatter.date(from: key) else { return nil }
            guard let stringValue = value as? String else { return nil }
            // "NA" (not analysed) / "NT" (no test) aren't numeric readings.
            let cleaned = stringValue.replacingOccurrences(of: ",", with: "")
            guard let numeric = Double(cleaned) else { return nil }
            return (date, numeric)
        }

        guard let latest = readings.max(by: { $0.date < $1.date }) else {
            // Site exists but has no usable reading this season yet.
            return AwarenessItem(
                id: "waterway-\(siteName)",
                category: .waterwaySafety,
                title: siteName,
                detail: "\(description) — no recent reading available.",
                severity: .info,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                date: nil
            )
        }

        let severity: AwarenessSeverity
        let statusText: String
        if latest.value > warningThreshold {
            severity = .warning
            statusText = "Poor — avoid primary contact (swimming, wading)"
        } else if latest.value > cautionThreshold {
            severity = .caution
            statusText = "Fair — use caution after recent rain"
        } else {
            severity = .info
            statusText = "Good — within safe guideline levels"
        }

        return AwarenessItem(
            id: "waterway-\(siteName)",
            category: .waterwaySafety,
            title: siteName,
            detail: "\(description). Latest enterococci reading: \(Int(latest.value)) CFU/100mL. \(statusText).",
            severity: severity,
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            date: latest.date
        )
    }
}
