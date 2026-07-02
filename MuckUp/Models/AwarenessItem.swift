import Foundation
import CoreLocation

// MARK: - AwarenessCategory

enum AwarenessCategory: String {
    case waterwaySafety
    case animalComplaint

    var displayName: String {
        switch self {
        case .waterwaySafety:  return "Waterway Safety"
        case .animalComplaint: return "Animal Complaints"
        }
    }

    var icon: String {
        switch self {
        case .waterwaySafety:  return "drop.triangle.fill"
        case .animalComplaint: return "pawprint.fill"
        }
    }
}

// MARK: - AwarenessSeverity

enum AwarenessSeverity: Int, Comparable {
    case info, caution, warning

    static func < (lhs: AwarenessSeverity, rhs: AwarenessSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var color: String {
        switch self {
        case .info:    return "info"
        case .caution: return "caution"
        case .warning: return "warning"
        }
    }
}

// MARK: - AwarenessItem

/// A "thing to be aware of" in an area — sourced from Brisbane City
/// Council open data. Not a Muck (nothing to clean up) and not a
/// PartnerItem (not an event to join) — a status/context signal shown
/// on the map (when it has real coordinates) and when scheduling events.
struct AwarenessItem: Identifiable {
    let id: String
    let category: AwarenessCategory
    let title: String
    let detail: String
    let severity: AwarenessSeverity
    /// nil when the source data has no coordinates (e.g. suburb-level
    /// aggregate counts) — such items only ever appear in list form,
    /// never plotted on a map.
    let coordinate: CLLocationCoordinate2D?
    let date: Date?
}
