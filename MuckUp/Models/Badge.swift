import Foundation

/// Real, checkable milestones instead of the 3 hardcoded ones
/// StampBadgeView used to have — every case here maps to something a
/// user actually did, so the collection grows as a real record of
/// activity rather than decoration.
enum Badge: String, CaseIterable {
    case firstSteps
    case ecoWarrior
    case hazardHunter
    case fixerUpper
    case goodNeighbour
    case onFire
    case squadPlayer
    case risingStar
    case legend

    var emoji: String {
        switch self {
        case .firstSteps:    return "👣"
        case .ecoWarrior:    return "🌍"
        case .hazardHunter:  return "🦺"
        case .fixerUpper:    return "🔧"
        case .goodNeighbour: return "🤝"
        case .onFire:        return "🔥"
        case .squadPlayer:   return "👥"
        case .risingStar:    return "⭐"
        case .legend:        return "👑"
        }
    }

    var label: String {
        switch self {
        case .firstSteps:    return "First Steps"
        case .ecoWarrior:    return "Eco Warrior"
        case .hazardHunter:  return "Hazard Hunter"
        case .fixerUpper:    return "Fixer Upper"
        case .goodNeighbour: return "Good Neighbour"
        case .onFire:        return "On Fire"
        case .squadPlayer:   return "Squad Player"
        case .risingStar:    return "Rising Star"
        case .legend:        return "Muck Legend"
        }
    }

    struct Context {
        let raisedCount: Int
        let closedCount: Int
        let closedHazards: Int
        let closedRepairs: Int
        let offeredHelpCount: Int
        let streak: Int
        let isInSquad: Bool
        let rank: MuckRank
    }

    func isUnlocked(_ ctx: Context) -> Bool {
        switch self {
        case .firstSteps:    return ctx.raisedCount >= 1
        case .ecoWarrior:    return ctx.closedCount >= 5
        case .hazardHunter:  return ctx.closedHazards >= 3
        case .fixerUpper:    return ctx.closedRepairs >= 3
        case .goodNeighbour: return ctx.offeredHelpCount >= 3
        case .onFire:        return ctx.streak >= 7
        case .squadPlayer:   return ctx.isInSquad
        case .risingStar:    return ctx.rank >= .hero
        case .legend:        return ctx.rank == .legend
        }
    }
}
