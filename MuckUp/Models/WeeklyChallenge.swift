import Foundation

/// A lightweight, no-backend seasonal layer: a single community goal for
/// the current calendar week, deterministically derived from the week
/// number so every device shows the same challenge without needing a
/// server to coordinate it. Progress counts real, already-loaded muck
/// data (no separate fetch) — this rides on top of the existing type/
/// location filters rather than introducing a new system.
struct WeeklyChallenge {
    let type: MuckType
    let targetCount: Int
    let weekOfYear: Int

    // Hazards are deliberately excluded — they're authority-managed
    // (see ViewMuckView's "Contact your local council or EPA" notice)
    // and "closed" just means someone tapped a button, not that the
    // hazard is actually safe. A weekly goal built on that count would
    // reward marking hazards done instead of reporting and stepping
    // back, so the challenge only ever covers things a person can
    // safely resolve themselves.
    private static let rotation: [(type: MuckType, target: Int)] = [
        (.cleanup, 15),
        (.repair, 6),
    ]

    static func current(referenceDate: Date = .now) -> WeeklyChallenge {
        let week = Calendar.current.component(.weekOfYear, from: referenceDate)
        let pick = rotation[week % rotation.count]
        return WeeklyChallenge(type: pick.type, targetCount: pick.target, weekOfYear: week)
    }

    var title: String {
        switch type {
        case .cleanup: return "Clean up \(targetCount) messes this week"
        case .hazard:  return "Flag \(targetCount) hazards for the council this week"
        case .repair:  return "Fix \(targetCount) things this week"
        }
    }

    /// Start of the current calendar week (Monday, per Calendar's
    /// locale-aware week start) — used to scope "this week" counts.
    static var startOfWeek: Date {
        let cal = Calendar.current
        let now = Date.now
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        return cal.date(from: components) ?? now
    }

    func progress(in mucks: [Muck]) -> Int {
        let start = Self.startOfWeek
        return mucks.filter { muck in
            muck.type == type && muck.isClosed && (muck.closedDate ?? .distantPast) >= start
        }.count
    }
}
