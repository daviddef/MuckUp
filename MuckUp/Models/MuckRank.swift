import SwiftUI

/// Turns the raw Muck Points number into a sense of progress — a title,
/// an emoji, and a "points to next rank" so the number means something
/// instead of just going up.
enum MuckRank: Int, CaseIterable, Comparable {
    case seedling, sprout, grower, hero, champion, legend

    static func < (lhs: MuckRank, rhs: MuckRank) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    static func forPoints(_ points: Int) -> MuckRank {
        allCases.last { points >= $0.minPoints } ?? .seedling
    }

    var minPoints: Int {
        switch self {
        case .seedling: return 0
        case .sprout:   return 25
        case .grower:   return 75
        case .hero:     return 200
        case .champion: return 500
        case .legend:   return 1000
        }
    }

    var title: String {
        switch self {
        case .seedling: return "Seedling"
        case .sprout:   return "Sprout"
        case .grower:   return "Grower"
        case .hero:     return "Neighbourhood Hero"
        case .champion: return "Community Champion"
        case .legend:   return "Muck Legend"
        }
    }

    var emoji: String {
        switch self {
        case .seedling: return "🌱"
        case .sprout:   return "🌿"
        case .grower:   return "🌳"
        case .hero:     return "🏆"
        case .champion: return "⭐"
        case .legend:   return "👑"
        }
    }

    var next: MuckRank? {
        let all = Self.allCases
        guard let idx = all.firstIndex(of: self), idx + 1 < all.count else { return nil }
        return all[idx + 1]
    }

    /// Points still needed to reach the next rank — nil once at the top.
    func pointsToNext(from points: Int) -> Int? {
        guard let next else { return nil }
        return max(0, next.minPoints - points)
    }

    /// 0...1 progress toward the next rank, for a progress bar.
    func progress(from points: Int) -> Double {
        guard let next else { return 1 }
        let span = Double(next.minPoints - minPoints)
        guard span > 0 else { return 1 }
        return min(1, max(0, Double(points - minPoints) / span))
    }
}
