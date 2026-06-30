import UserNotifications
import Foundation

@MainActor
final class NotificationService: ObservableObject {
    static let shared = NotificationService()

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func scheduleEventReminders(for event: MuckEvent) {
        let center = UNUserNotificationCenter.current()

        // Day-before reminder at 6 pm
        if let dayBefore = Calendar.current.date(byAdding: .day, value: -1, to: event.eventDate) {
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: dayBefore)
            comps.hour = 18; comps.minute = 0
            schedule(
                id: "event-\(event.id)-dayBefore",
                title: "Tomorrow: \(event.title)",
                body: "\(event.participants) people going. Meet at \(event.location).",
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false),
                center: center
            )
        }

        // Day-of reminder 30 min before
        if let thirtyBefore = Calendar.current.date(byAdding: .minute, value: -30, to: event.eventDate) {
            guard thirtyBefore > .now else { return }
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: thirtyBefore)
            schedule(
                id: "event-\(event.id)-soon",
                title: "\(event.title) starts in 30 min",
                body: "Time to gear up. Head to \(event.location).",
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false),
                center: center
            )
        }
    }

    func cancelEventReminders(for eventId: Int) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            "event-\(eventId)-dayBefore",
            "event-\(eventId)-soon"
        ])
    }

    func scheduleNearbyMuckAlert(muckId: String, location: String) {
        let content = UNMutableNotificationContent()
        content.title = "New muck near you"
        content.body = location
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let req = UNNotificationRequest(identifier: "nearbyMuck-\(muckId)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    private func schedule(id: String, title: String, body: String,
                          trigger: UNNotificationTrigger, center: UNUserNotificationCenter) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(req)
    }
}
