import Foundation

struct AppUser: Codable {
    var id: String
    var email: String
    var displayName: String
    var points: Int

    static let guest = AppUser(id: "guest", email: "", displayName: "Guest", points: 0)
}

enum PointAction {
    case raiseMuck       // +1  — Help the World
    case participate     // +5  — Help the World
    case closeMuck       // +10 — Help the World
    case askForHelp       // +1  — Help Me
    case offerHelp         // +3  — Help Me
    case helpCompleted     // +8  — Help Me (awarded to the helper)
    case requestResolved   // +5  — Help Me (awarded to the requester)

    var value: Int {
        switch self {
        case .raiseMuck:        return 1
        case .participate:      return 5
        case .closeMuck:        return 10
        case .askForHelp:       return 1
        case .offerHelp:        return 3
        case .helpCompleted:    return 8
        case .requestResolved:  return 5
        }
    }
}
