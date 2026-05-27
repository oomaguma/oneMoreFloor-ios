import UIKit

enum Haptics {
    private static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "com.oneMoreFloor.hapticsEnabled") as? Bool ?? true
    }

    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
