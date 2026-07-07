import Foundation

/// A personal, no-backend weekly goal — how many mucks *this user* has
/// cleared this week, against a target that starts at "your first one"
/// and climbs gradually as their own lifetime count grows. Originally
/// this counted every muck closed by anyone nearby, which produced
/// targets like "clear 15 this week" for a single person — a mismatch
/// between a community-wide number and an individual ask. Scoped to one
/// person's own pace, it stays achievable at every stage.
struct WeeklyChallenge {
    let targetCount: Int
    let isFirstEver: Bool

    /// `lifetimeClosedCount` is this user's total mucks cleared, ever —
    /// used only to pick a realistic target, never to gate anything.
    static func current(lifetimeClosedCount: Int) -> WeeklyChallenge {
        if lifetimeClosedCount == 0 {
            return WeeklyChallenge(targetCount: 1, isFirstEver: true)
        }
        let target: Int
        switch lifetimeClosedCount {
        case 1..<5:   target = 2
        case 5..<15:  target = 3
        default:      target = 5
        }
        return WeeklyChallenge(targetCount: target, isFirstEver: false)
    }

    var title: String {
        if isFirstEver { return "Let's get started on your first clean-up!" }
        return "Clear \(targetCount) muck\(targetCount == 1 ? "" : "s") this week"
    }

    /// Start of the current calendar week (Monday, per Calendar's
    /// locale-aware week start) — used to scope "this week" counts.
    static var startOfWeek: Date {
        let cal = Calendar.current
        let now = Date.now
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        return cal.date(from: components) ?? now
    }

    /// How many of *this user's own* closed mucks fall within the
    /// current week — pass only the mucks they personally closed
    /// (MuckViewModel.closedMuckIds), not the whole community feed.
    func progress(myClosedMucks: [Muck]) -> Int {
        let start = Self.startOfWeek
        return myClosedMucks.filter { ($0.closedDate ?? .distantPast) >= start }.count
    }
}
