import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    private let deathNotificationID = "hero.death"

    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func scheduleDeathNotification(in seconds: Double, characterName: String) {
        guard seconds > 1 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Your hero has fallen!"
        content.body = "\(characterName) has met their end in the dungeon. Return to fight again."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: deathNotificationID, content: content, trigger: trigger)

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [deathNotificationID])
        center.add(request)
    }

    func cancelDeathNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [deathNotificationID])
    }
}
