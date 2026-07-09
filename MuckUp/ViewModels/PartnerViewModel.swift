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
        // Items arrive from 6+ independently-fetched sources appended one
        // after another (council events, then green events, then parks,
        // then gold, then composting hubs, ...) with no shared ordering —
        // left as-is this reads as a random shuffle. Sort chronologically
        // instead, soonest-upcoming first (same "what's next" rule as
        // Home's activity feed): upcoming dated items ascending, then
        // undated items (permanent locations like composting hubs), then
        // anything with a date already in the past.
        let now = Date.now
        return result.sorted { a, b in
            let aBucket = bucket(for: a.date, now: now)
            let bBucket = bucket(for: b.date, now: now)
            if aBucket != bBucket { return aBucket < bBucket }
            switch (a.date, b.date) {
            case let (da?, db?): return aBucket == 0 ? da < db : da > db
            default: return false
            }
        }
    }

    /// 0 = upcoming (sorts soonest-first), 1 = undated, 2 = past (sorts
    /// most-recent-first) — keeps "what's next" at the top without
    /// burying permanent locations behind a stale one-off event.
    private func bucket(for date: Date?, now: Date) -> Int {
        guard let date else { return 1 }
        return date >= now ? 0 : 2
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
