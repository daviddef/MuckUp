import SwiftUI
import SwiftData
import CoreLocation

// MARK: - HelpCategory

enum HelpCategory: String, Codable, CaseIterable {
    case yardWork, moving, repairs, companionship, other

    var displayName: String {
        switch self {
        case .yardWork:       return "Yard Work"
        case .moving:         return "Moving / Lifting"
        case .repairs:        return "Repairs"
        case .companionship:  return "Companionship"
        case .other:          return "Other"
        }
    }

    var icon: String {
        switch self {
        case .yardWork:       return "leaf.fill"
        case .moving:         return "shippingbox.fill"
        case .repairs:        return "hammer.fill"
        case .companionship:  return "person.2.fill"
        case .other:          return "hand.raised.fill"
        }
    }
}

// MARK: - HelpRequestStatus

enum HelpRequestStatus: String, Codable {
    case open, matched, completed
}

// MARK: - HelpRequest

// Note: no @Attribute(.unique) on `id` — CloudKit-backed SwiftData does not
// support unique constraints. Every stored property has an inline default
// so the CloudKit schema can be created without requiring all fields.
@Model
final class HelpRequest {
    var id: String = "HLP-\(Int.random(in: 1000...9999))"
    var title: String = ""
    var requestDescription: String = ""
    var categoryRaw: String = HelpCategory.other.rawValue
    var preferredDate: Date = Date.now
    var createdDate: Date = Date.now
    var statusRaw: String = HelpRequestStatus.open.rawValue

    // Exact location — private, never shown to other users directly.
    // Only used for real-world coordination once a helper is matched.
    var exactLatitude: Double = 0
    var exactLongitude: Double = 0

    // Stable jittered offset (metres, bearing) applied to the exact
    // coordinate to produce the public-facing blurred location.
    var blurOffsetMetres: Double = 250
    var blurBearingDegrees: Double = 0
    var blurRadiusMetres: Double = 400

    var requesterId: String = ""
    var helperIds: [String] = []

    @Attribute(.externalStorage) var photoData: Data?

    init(
        id: String = "HLP-\(Int.random(in: 1000...9999))",
        title: String,
        description: String,
        category: HelpCategory,
        preferredDate: Date,
        exactLatitude: Double,
        exactLongitude: Double,
        requesterId: String,
        blurRadiusMetres: Double = 400
    ) {
        self.id = id
        self.title = title
        self.requestDescription = description
        self.categoryRaw = category.rawValue
        self.preferredDate = preferredDate
        self.createdDate = .now
        self.statusRaw = HelpRequestStatus.open.rawValue
        self.exactLatitude = exactLatitude
        self.exactLongitude = exactLongitude
        self.requesterId = requesterId
        self.helperIds = []
        self.blurRadiusMetres = blurRadiusMetres

        // Deterministic jitter derived from the id, so the blurred pin
        // doesn't jump around on every render but still hides the real spot.
        var hasher = Hasher()
        hasher.combine(id)
        let seed = abs(hasher.finalize())
        self.blurOffsetMetres = Double(seed % 250) + 150   // 150–400m off-centre
        self.blurBearingDegrees = Double((seed / 250) % 360)
    }

    var category: HelpCategory {
        get { HelpCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var status: HelpRequestStatus {
        get { HelpRequestStatus(rawValue: statusRaw) ?? .open }
        set { statusRaw = newValue.rawValue }
    }

    var exactCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: exactLatitude, longitude: exactLongitude)
    }

    /// Approximate, publicly-visible coordinate — offset from the real
    /// location by blurOffsetMetres along blurBearingDegrees.
    var blurredCoordinate: CLLocationCoordinate2D {
        let earthRadius = 6_371_000.0
        let bearingRad = blurBearingDegrees * .pi / 180
        let latRad = exactLatitude * .pi / 180
        let lonRad = exactLongitude * .pi / 180

        let newLatRad = asin(
            sin(latRad) * cos(blurOffsetMetres / earthRadius) +
            cos(latRad) * sin(blurOffsetMetres / earthRadius) * cos(bearingRad)
        )
        let newLonRad = lonRad + atan2(
            sin(bearingRad) * sin(blurOffsetMetres / earthRadius) * cos(latRad),
            cos(blurOffsetMetres / earthRadius) - sin(latRad) * sin(newLatRad)
        )

        return CLLocationCoordinate2D(
            latitude: newLatRad * 180 / .pi,
            longitude: newLonRad * 180 / .pi
        )
    }

    func distanceLabel(from userLocation: CLLocation?) -> String? {
        guard let userLocation else { return nil }
        let blurred = blurredCoordinate
        let loc = CLLocation(latitude: blurred.latitude, longitude: blurred.longitude)
        let metres = userLocation.distance(from: loc)
        return metres < 1000 ? "~\(Int(metres))m" : String(format: "~%.1fkm", metres / 1000)
    }
}
