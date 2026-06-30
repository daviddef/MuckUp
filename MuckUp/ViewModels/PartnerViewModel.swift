import SwiftUI
import CoreLocation

@MainActor
final class PartnerViewModel: ObservableObject {
    @Published var items: [PartnerItem] = []
    @Published var enabledSources: Set<PartnerSource> = Set(PartnerSource.allCases)
    @Published var isLoading = false
    @Published var sourceFilter: PartnerSource? = nil

    var filteredItems: [PartnerItem] {
        var result = items.filter { enabledSources.contains($0.source) }
        if let filter = sourceFilter {
            result = result.filter { $0.source == filter }
        }
        return result
    }

    func loadMockData() {
        items = PartnerItem.mockData
    }

    func fetchAll(near location: CLLocation) async {
        isLoading = true
        defer { isLoading = false }
        // Live fetches will go here — mock for now
        loadMockData()
    }

    func toggleSource(_ source: PartnerSource) {
        if enabledSources.contains(source) {
            enabledSources.remove(source)
        } else {
            enabledSources.insert(source)
        }
    }
}
