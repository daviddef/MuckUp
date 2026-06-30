import Foundation

struct AppUser: Codable {
    var id: String
    var email: String
    var displayName: String
    var points: Int

    static let guest = AppUser(id: "guest", email: "", displayName: "Guest", points: 0)
}

enum PointAction {
    case raiseMuck       // +1
    case participate     // +5
    case closeMuck       // +10

    var value: Int {
        switch self {
        case .raiseMuck:   return 1
        case .participate: return 5
        case .closeMuck:   return 10
        }
    }
}
