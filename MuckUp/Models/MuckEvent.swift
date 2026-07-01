import SwiftData
import Foundation

// Note: no @Attribute(.unique) on `id` — CloudKit-backed SwiftData does not
// support unique constraints. Every stored property has an inline default
// so the CloudKit schema can be created without requiring all fields.
@Model
final class MuckEvent {
    var id: Int = Int.random(in: 10000...99999)
    var title: String = ""
    var location: String = ""
    var meetupLatitude: Double = 0
    var meetupLongitude: Double = 0
    var eventDate: Date = Date.now
    var eventDescription: String = ""
    var muckIds: [String] = []
    var participants: Int = 0
    var isAttending: Bool = false
    var isFavourite: Bool = false
    // Live session
    var bagCount: Int = 0
    var checkedInCount: Int = 0
    var isLive: Bool = false
    var endedDate: Date?
    // Impact
    var estimatedKg: Double = 0
    @Attribute(.externalStorage) var impactCardData: Data?
    // Organiser's stable ID (Sign in with Apple identifier).
    var ownerId: String = ""

    init(
        id: Int = Int.random(in: 10000...99999),
        title: String,
        location: String,
        date: Date,
        description: String,
        muckIds: [String] = [],
        participants: Int = 0,
        isAttending: Bool = false,
        isFavourite: Bool = false,
        meetupLatitude: Double = 0,
        meetupLongitude: Double = 0,
        ownerId: String = ""
    ) {
        self.id = id
        self.title = title
        self.location = location
        self.eventDate = date
        self.eventDescription = description
        self.muckIds = muckIds
        self.participants = participants
        self.isAttending = isAttending
        self.isFavourite = isFavourite
        self.meetupLatitude = meetupLatitude
        self.meetupLongitude = meetupLongitude
        self.bagCount = 0
        self.checkedInCount = 0
        self.isLive = false
        self.estimatedKg = 0
        self.ownerId = ownerId
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(eventDate)
    }

    var isPast: Bool {
        eventDate < .now && !isLive
    }

    var estimatedKgDisplay: String {
        estimatedKg > 0 ? String(format: "%.0f kg", estimatedKg) : "—"
    }
}
