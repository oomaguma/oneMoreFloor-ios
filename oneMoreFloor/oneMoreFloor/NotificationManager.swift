import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    private let deathNotificationID = "hero.death"

    private init() {}

    func requestPermission() {
        // The only caller is the NOTIFY ME soft ask, so the answer to iOS's
        // dialog tells us whether the soft ask actually converts.
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            Analytics.notificationAskAnswered(granted: granted)
        }
    }

    /// True while iOS has never asked for notification permission. iOS shows its
    /// system dialog only once per install, so we only offer our own soft ask
    /// ("Want a heads-up next time?") while a "yes" can still reach that dialog.
    func canAskForPermission() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .notDetermined
    }

    func scheduleDeathNotification(in seconds: Double, characterName: String) {
        guard seconds > 1 else { return }

        let content = UNMutableNotificationContent()
        // Informative, not guilt-tripping: say what happened and that their
        // banked progress is safe (the engagement chart's "guilt mechanics" row).
        content.title = "\(characterName) fell in the dungeon"
        content.body = "Banked gold and upgrades are safe. Jump back in whenever you're ready."
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
