import SwiftData
import Foundation

@Model
final class MuckEvent {
    @Attribute(.unique) var id: Int
    var title: String
    var location: String
    var eventDate: Date
    var eventDescription: String
    var muckIds: [String]
    var participants: Int
    var isAttending: Bool
    var isFavourite: Bool

    init(
        id: Int = Int.random(in: 10000...99999),
        title: String,
        location: String,
        date: Date,
        description: String,
        muckIds: [String] = [],
        participants: Int = 0,
        isAttending: Bool = false,
        isFavourite: Bool = false
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
    }
}
