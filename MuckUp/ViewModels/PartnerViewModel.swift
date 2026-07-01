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

        // Mock data stands in for the other partner sources for now.
        // Brisbane City Council Events is the first genuinely live feed —
        // fetched in parallel and merged in alongside the mock items.
        loadMockData()
        let liveEvents = await BrisbaneEventsService.shared.fetchNearby(location)
        if !liveEvents.isEmpty {
            items.append(contentsOf: liveEvents)
        }
    }

    func toggleSource(_ source: PartnerSource) {
        if enabledSources.contains(source) {
            enabledSources.remove(source)
        } else {
            enabledSources.insert(source)
        }
    }
}
