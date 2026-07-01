import SwiftUI
import SwiftData

@MainActor
final class EventViewModel: ObservableObject {
    @Published var showAttendingOnly = false
    private let storage = StorageService.shared
    var userId: String = AppUser.guest.id

    func isFavourite(eventId: Int) -> Bool {
        storage.loadFavouriteEvents(for: userId).contains(eventId)
    }

    func toggleFavourite(eventId: Int) {
        var favs = storage.loadFavouriteEvents(for: userId)
        if let idx = favs.firstIndex(of: eventId) {
            favs.remove(at: idx)
        } else {
            favs.append(eventId)
        }
        storage.saveFavouriteEvents(favs, for: userId)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        objectWillChange.send()
    }

    func filtered(_ events: [MuckEvent]) -> [MuckEvent] {
        showAttendingOnly ? events.filter { $0.isAttending } : events
    }

    // MARK: - Personal history

    func recordAttended(_ eventId: Int) {
        storage.recordAttendedEvent(eventId, for: userId)
        storage.recordActivityToday(for: userId)
    }

    var attendedEventIds: [Int] { storage.loadAttendedEventIds(for: userId) }
}
