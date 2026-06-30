import SwiftUI
import Foundation

// MARK: - PartnerSource

enum PartnerSource: String, CaseIterable, Identifiable {
    case trashmob, wcd, justserve, volunteerconnector, openlittermap, epa

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .trashmob:           return "TrashMob"
        case .wcd:                return "World Cleanup"
        case .justserve:          return "JustServe"
        case .volunteerconnector: return "VolConnector"
        case .openlittermap:      return "Litter Map"
        case .epa:                return "EPA"
        }
    }

    var emoji: String {
        switch self {
        case .trashmob:           return "🤝"
        case .wcd:                return "🌍"
        case .justserve:          return "⚜️"
        case .volunteerconnector: return "🙌"
        case .openlittermap:      return "🗑️"
        case .epa:                return "☢️"
        }
    }

    // Whether items from this source get a "Create Muck" CTA (vs a Join link)
    var promptsCreateMuck: Bool {
        switch self {
        case .openlittermap, .epa, .wcd, .justserve, .volunteerconnector: return true
        case .trashmob: return false
        }
    }
}

// MARK: - PartnerItem

struct PartnerItem: Identifiable {
    let id: String
    var name: String
    var organisation: String?
    var source: PartnerSource
    var latitude: Double
    var longitude: Double
    var date: Date?
    var itemDescription: String?
    var externalURL: URL
    var litterType: String?
    var attendees: Int?
    var weatherEmoji: String?

    // Convenience
    var displayDate: String? {
        guard let date else { return nil }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }
}
