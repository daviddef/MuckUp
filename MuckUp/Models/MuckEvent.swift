import SwiftData
import Foundation

@Model
final class MuckEvent {
    @Attribute(.unique) var id: Int
    var title: String
    var location: String
    var meetupLatitude: Double
    var meetupLongitude: Double
    var eventDate: Date
    var eventDescription: String
    var muckIds: [String]
    var participants: Int
    var isAttending: Bool
    var isFavourite: Bool
    // Live session
    var bagCount: Int
    var checkedInCount: Int
    var isLive: Bool
    var endedDate: Date?
    // Impact
    var estimatedKg: Double
    @Attribute(.externalStorage) var impactCardData: Data?

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
        meetupLongitude: Double = 0
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
