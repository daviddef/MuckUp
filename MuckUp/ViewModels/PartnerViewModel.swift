import SwiftUI
import CoreLocation

@MainActor
final class PartnerViewModel: ObservableObject {
    @Published var items: [PartnerItem] = []
    @Published var enabledSources: Set<PartnerSource> = Set(PartnerSource.allCases)
    @Published var isLoading = false
    @Published var sourceFilter: PartnerSource? = nil
    // Whether external/partner items (from Find) should also surface on
    // the Home screen's mini map and "Events near you" section — on by
    // default, toggled off via the icon filter in Home's filter bar.
    @Published var showOnHome: Bool = true

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
        // Everything else here is a live feed, fetched concurrently and
        // merged in alongside the mock items.
        loadMockData()
        async let councilEvents = BrisbaneEventsService.shared.fetchNearby(location)
        async let greenEvents = GreenEventsService.shared.fetchNearby(location)
        async let parksEvents = ParksEventsService.shared.fetchNearby(location)
        async let goldEvents = GoldEventsService.shared.fetchNearby(location)
        async let compostingHubs = WasteResourceLocationsService.shared.fetchCompostingHubs()
        async let transferStations = WasteResourceLocationsService.shared.fetchWasteTransferStations()

        items.append(contentsOf: await councilEvents)
        items.append(contentsOf: await greenEvents)
        items.append(contentsOf: await parksEvents)
        items.append(contentsOf: await goldEvents)
        items.append(contentsOf: await compostingHubs)
        items.append(contentsOf: await transferStations)
    }

    func toggleSource(_ source: PartnerSource) {
        if enabledSources.contains(source) {
            enabledSources.remove(source)
        } else {
            enabledSources.insert(source)
        }
    }
}
