import Foundation

/// Reads Brisbane City Council's animal-related complaints dataset —
/// individual complaint records (unregistered dogs, attacks, off-leash
/// reports, etc.) tagged only with a suburb name, no coordinates.
///
/// Because there's no lat/lon in this dataset at all, results can never
/// be plotted as map pins — they only ever show up as a suburb-matched
/// summary in the "Things to be aware of" list when scheduling an event,
/// matched against the reverse-geocoded suburb of the meetup point.
final class AnimalComplaintsService {
    static let shared = AnimalComplaintsService()
    private init() {}

    private let baseURL = "https://data.brisbane.qld.gov.au/api/explore/v2.1/catalog/datasets/animal-related-complaints/records"

    /// Fetches the most recent quarter's complaints for the given suburb
    /// and summarises them into a single awareness item (nil if none).
    func fetchSummary(suburb: String) async -> AwarenessItem? {
        let normalized = suburb.uppercased()
        guard let quarter = await latestQuarter() else { return nil }

        guard var components = URLComponents(string: baseURL) else { return nil }
        components.queryItems = [
            URLQueryItem(name: "where", value: #"location_suburb="\#(normalized)" and quarter="\#(quarter)""#),
            URLQueryItem(name: "limit", value: "100"),
        ]
        guard let url = components.url else { return nil }

        do {
            let (data, _) = try await URLSession.grubData.data(from: url)
            let decoded = try JSONDecoder().decode(ODSComplaintsResponse.self, from: data)
            guard !decoded.results.isEmpty else { return nil }

            var counts: [String: Int] = [:]
            var hasAttack = false
            for record in decoded.results {
                counts[record.categoryType, default: 0] += 1
                if record.categoryNature.localizedCaseInsensitiveContains("attack") {
                    hasAttack = true
                }
            }

            let topLines = counts.sorted { $0.value > $1.value }
                .prefix(4)
                .map { "\($0.value) \($0.key.lowercased())" }
                .joined(separator: ", ")

            return AwarenessItem(
                id: "animal-\(normalized)-\(quarter)",
                category: .animalComplaint,
                title: "Animal complaints in \(suburb.capitalized)",
                detail: "\(decoded.results.count) complaints this quarter (\(quarter)): \(topLines).",
                severity: hasAttack ? .warning : (decoded.results.count > 10 ? .caution : .info),
                coordinate: nil,
                date: nil
            )
        } catch {
            print("⚠️ Animal complaints fetch failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func latestQuarter() async -> String? {
        guard var components = URLComponents(string: baseURL) else { return nil }
        components.queryItems = [
            URLQueryItem(name: "order_by", value: "quarter desc"),
            URLQueryItem(name: "limit", value: "1"),
        ]
        guard let url = components.url else { return nil }
        do {
            let (data, _) = try await URLSession.grubData.data(from: url)
            let decoded = try JSONDecoder().decode(ODSComplaintsResponse.self, from: data)
            return decoded.results.first?.quarter
        } catch {
            return nil
        }
    }
}

// MARK: - Response models

private struct ODSComplaintsResponse: Decodable {
    let results: [ODSComplaintRecord]
}

private struct ODSComplaintRecord: Decodable {
    let quarter: String
    let categoryType: String
    let categoryNature: String

    enum CodingKeys: String, CodingKey {
        case quarter
        case categoryType = "category_type"
        case categoryNature = "category_nature"
    }
}
