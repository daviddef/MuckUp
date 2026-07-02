import SwiftUI
import Foundation

// MARK: - PartnerSource

enum PartnerSource: String, CaseIterable, Identifiable {
    case trashmob, wcd, justserve, volunteerconnector, openlittermap, epa
    case brisbaneEvents, greenEvents, parksEvents, goldEvents
    case compostingHub, wasteTransferStation

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .trashmob:            return "TrashMob"
        case .wcd:                 return "World Cleanup"
        case .justserve:           return "JustServe"
        case .volunteerconnector:  return "VolConnector"
        case .openlittermap:       return "Litter Map"
        case .epa:                 return "EPA"
        case .brisbaneEvents:      return "Council Events"
        case .greenEvents:         return "Green Events"
        case .parksEvents:         return "Parks Events"
        case .goldEvents:          return "Seniors' Programs"
        case .compostingHub:       return "Composting Hub"
        case .wasteTransferStation: return "Resource Recovery"
        }
    }

    var emoji: String {
        switch self {
        case .trashmob:            return "🤝"
        case .wcd:                 return "🌍"
        case .justserve:           return "⚜️"
        case .volunteerconnector:  return "🙌"
        case .openlittermap:       return "🗑️"
        case .epa:                 return "☢️"
        case .brisbaneEvents:      return "🏛️"
        case .greenEvents:         return "🌱"
        case .parksEvents:         return "🌳"
        case .goldEvents:          return "👴"
        case .compostingHub:       return "🪱"
        case .wasteTransferStation: return "♻️"
        }
    }

    // Whether items from this source get a "Create Muck" CTA (vs a link-out only).
    // Litter Map reports are raw litter sightings — a natural 1:1 match for a Muck.
    // Everything else (organised events, official hazard reports) sends users
    // straight to the partner rather than letting them spin up a duplicate Muck.
    var promptsCreateMuck: Bool {
        self == .openlittermap
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
