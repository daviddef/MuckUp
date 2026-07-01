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

    // MARK: - Personal history (mucks raised / closed, events attended)

    func recordRaisedMuck(_ id: String, for userId: String) {
        appendUnique(id, key: "raised_\(userId)")
    }

    func loadRaisedMuckIds(for userId: String) -> [String] {
        defaults.array(forKey: "raised_\(userId)") as? [String] ?? []
    }

    func recordClosedMuck(_ id: String, for userId: String) {
        appendUnique(id, key: "closed_\(userId)")
    }

    func loadClosedMuckIds(for userId: String) -> [String] {
        defaults.array(forKey: "closed_\(userId)") as? [String] ?? []
    }

    func recordAttendedEvent(_ id: Int, for userId: String) {
        var ids = defaults.array(forKey: "attended_\(userId)") as? [Int] ?? []
        if !ids.contains(id) {
            ids.append(id)
            defaults.set(ids, forKey: "attended_\(userId)")
        }
    }

    func loadAttendedEventIds(for userId: String) -> [Int] {
        defaults.array(forKey: "attended_\(userId)") as? [Int] ?? []
    }

    private func appendUnique(_ id: String, key: String) {
        var ids = defaults.array(forKey: key) as? [String] ?? []
        if !ids.contains(id) {
            ids.append(id)
            defaults.set(ids, forKey: key)
        }
    }

    // MARK: - Activity streak

    /// Call whenever the user does something meaningful (raise, close, attend).
    /// Tracks which calendar days had activity so we can compute a streak.
    func recordActivityToday(for userId: String) {
        let key = "activityDays_\(userId)"
        var days = Set(defaults.array(forKey: key) as? [String] ?? [])
        days.insert(Self.dayKey(for: .now))
        defaults.set(Array(days), forKey: key)
    }

    /// Consecutive days of activity ending today (0 if nothing today).
    func currentStreak(for userId: String) -> Int {
        let key = "activityDays_\(userId)"
        let days = Set(defaults.array(forKey: key) as? [String] ?? [])
        guard days.contains(Self.dayKey(for: .now)) else { return 0 }
        var streak = 0
        var cursor = Date.now
        while days.contains(Self.dayKey(for: cursor)) {
            streak += 1
            cursor = Calendar.current.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        return streak
    }

    private static func dayKey(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    // MARK: - Onboarding

    func hasSeenOnboarding() -> Bool {
        defaults.bool(forKey: "hasSeenOnboarding")
    }

    func setHasSeenOnboarding() {
        defaults.set(true, forKey: "hasSeenOnboarding")
    }
}
