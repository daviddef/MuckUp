import SwiftUI
import SwiftData
import CoreLocation

// MARK: - MuckType

enum MuckType: String, Codable, CaseIterable {
    case cleanup, hazard, repair

    var displayName: String {
        switch self {
        case .cleanup: return "Clean-Up"
        case .hazard:  return "Hazard"
        case .repair:  return "Repair"
        }
    }

    var icon: String {
        switch self {
        case .cleanup: return "arrow.3.trianglepath"
        case .hazard:  return "exclamationmark.triangle.fill"
        case .repair:  return "wrench.and.screwdriver.fill"
        }
    }

    var emoji: String {
        switch self {
        case .cleanup: return "♻️"
        case .hazard:  return "⚠️"
        case .repair:  return "🔧"
        }
    }

    var allowsEvents: Bool { self != .hazard }
}

// MARK: - Muck

@Model
final class Muck {
    @Attribute(.unique) var id: String
    var location: String
    var muckDescription: String
    var typeRaw: String
    var isHazardous: Bool
    var reportedDate: Date
    var latitude: Double
    var longitude: Double
    var votes: Int
    var eventCount: Int
    var isClosed: Bool
    var closedDate: Date?
    @Attribute(.externalStorage) var photoData: Data?
    @Attribute(.externalStorage) var afterPhotoData: Data?

    var type: MuckType {
        get { MuckType(rawValue: typeRaw) ?? .cleanup }
        set { typeRaw = newValue.rawValue }
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(
        id: String = "MK-\(Int.random(in: 1000...9999))",
        location: String,
        description: String,
        type: MuckType,
        isHazardous: Bool = false,
        reportedDate: Date = .now,
        latitude: Double,
        longitude: Double,
        votes: Int = 0,
        eventCount: Int = 0,
        isClosed: Bool = false
    ) {
        self.id = id
        self.location = location
        self.muckDescription = description
        self.typeRaw = type.rawValue
        self.isHazardous = isHazardous
        self.reportedDate = reportedDate
        self.latitude = latitude
        self.longitude = longitude
        self.votes = votes
        self.eventCount = eventCount
        self.isClosed = isClosed
    }

    func distance(from userLocation: CLLocation?) -> String? {
        guard let userLocation else { return nil }
        let muckLocation = CLLocation(latitude: latitude, longitude: longitude)
        let metres = userLocation.distance(from: muckLocation)
        if metres < 1000 {
            return "\(Int(metres))m"
        } else {
            return String(format: "%.1fkm", metres / 1000)
        }
    }
}

// MARK: - Sort Order

enum MuckSortOrder: String, CaseIterable {
    case votes, date

    var displayName: String {
        switch self {
        case .votes: return "🔥 Votes"
        case .date:  return "📅 Date"
        }
    }
}
