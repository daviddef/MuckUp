import Foundation

// Handles per-user private data: favourites, votes cast.
// Votes counts themselves are shared (CloudKit stub — local for now).
final class StorageService {
    static let shared = StorageService()
    private let defaults = UserDefaults.standard
    private init() {}

    // MARK: - Favourites

    func saveFavouriteMucks(_ ids: [String], for userId: String) {
        defaults.set(ids, forKey: "favourites_mucks_\(userId)")
    }

    func loadFavouriteMucks(for userId: String) -> [String] {
        defaults.array(forKey: "favourites_mucks_\(userId)") as? [String] ?? []
    }

    func saveFavouriteEvents(_ ids: [Int], for userId: String) {
        defaults.set(ids, forKey: "favourites_events_\(userId)")
    }

    func loadFavouriteEvents(for userId: String) -> [Int] {
        defaults.array(forKey: "favourites_events_\(userId)") as? [Int] ?? []
    }

    // MARK: - Votes

    func hasVoted(muckId: String, userId: String) -> Bool {
        let voted = defaults.array(forKey: "voted_\(userId)") as? [String] ?? []
        return voted.contains(muckId)
    }

    func recordVoteLocally(muckId: String, userId: String) {
        var voted = defaults.array(forKey: "voted_\(userId)") as? [String] ?? []
        if !voted.contains(muckId) {
            voted.append(muckId)
            defaults.set(voted, forKey: "voted_\(userId)")
        }
    }

    // MARK: - Points

    func loadPoints(for userId: String) -> Int {
        defaults.integer(forKey: "points_\(userId)")
    }

    func addPoints(_ amount: Int, for userId: String) {
        let current = loadPoints(for: userId)
        defaults.set(current + amount, forKey: "points_\(userId)")
    }
}
