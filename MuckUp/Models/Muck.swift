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

// Note: no @Attribute(.unique) on `id` — CloudKit-backed SwiftData does not
// support unique constraints. Every stored property has an inline default
// so the CloudKit schema can be created without requiring all fields.
@Model
final class Muck {
    var id: String = "MK-\(Int.random(in: 1000...9999))"
    var location: String = ""
    var muckDescription: String = ""
    var typeRaw: String = MuckType.cleanup.rawValue
    var isHazardous: Bool = false
    var reportedDate: Date = Date.now
    var latitude: Double = 0
    var longitude: Double = 0
    var votes: Int = 0
    var eventCount: Int = 0
    var isClosed: Bool = false
    var closedDate: Date?
    @Attribute(.externalStorage) var photoData: Data?
    @Attribute(.externalStorage) var afterPhotoData: Data?
    // Owning user's stable ID (Sign in with Apple identifier). Used to
    // scope "my mucks" once accounts exist; not enforced server-side yet.
    var ownerId: String = ""
    // Community moderation on the shared public database — anyone can
    // write a muck, so anyone can flag one. Auto-hidden once enough
    // people agree something's wrong with it (spam, abuse, duplicate).
    var flagCount: Int = 0

    static let hiddenFlagThreshold = 3
    var isHiddenByFlags: Bool { flagCount >= Muck.hiddenFlagThreshold }

    // True once this device has confirmed the CloudKit public-database
    // upload succeeded. A report made offline (or during an outage)
    // stays false so a later retry pass knows to push it again — the
    // local SwiftData row is always saved regardless, this only tracks
    // whether other users can see it yet.
    var syncedToCloud: Bool = false

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
        isClosed: Bool = false,
        ownerId: String = "",
        flagCount: Int = 0
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
        self.ownerId = ownerId
        self.flagCount = flagCount
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

    var icon: String {
        switch self {
        case .votes: return "flame.fill"
        case .date:  return "calendar"
        }
    }
}
