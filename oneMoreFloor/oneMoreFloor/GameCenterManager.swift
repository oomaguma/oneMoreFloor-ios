import GameKit
import UIKit

// MARK: - Leaderboard ID Constants
// These must match the IDs you create in App Store Connect → Game Center → Leaderboards

enum GCLeaderboard {
    static let deepestFloor  = "com.oneMoreFloor.leaderboard.deepestFloor"
    static let soulShards    = "com.oneMoreFloor.leaderboard.soulShards"
    static let prestigeCount = "com.oneMoreFloor.leaderboard.prestigeCount"
}

// MARK: - Achievement ID Constants
// These must match the IDs you create in App Store Connect → Game Center → Achievements

enum GCAchievement {
    // Floor milestones
    static let floor10  = "com.oneMoreFloor.achievement.floor10"
    static let floor25  = "com.oneMoreFloor.achievement.floor25"
    static let floor50  = "com.oneMoreFloor.achievement.floor50"
    static let floor100 = "com.oneMoreFloor.achievement.floor100"
    // Prestige milestones
    static let firstPrestige = "com.oneMoreFloor.achievement.firstPrestige"
    static let prestige5     = "com.oneMoreFloor.achievement.prestige5"
    static let prestige10    = "com.oneMoreFloor.achievement.prestige10"
    // Equipment
    static let firstEquip = "com.oneMoreFloor.achievement.firstEquip"
    static let allSlots   = "com.oneMoreFloor.achievement.allSlots"
    // Exploration
    static let firstZone = "com.oneMoreFloor.achievement.firstZone"
}

// MARK: - Manager

@Observable
final class GameCenterManager: NSObject {
    static let shared = GameCenterManager()
    private override init() {}

    private(set) var isAuthenticated = false

    // MARK: - Authentication

    /// Call once on app launch. Handles the login prompt automatically if needed.
    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, _ in
            DispatchQueue.main.async {
                if let vc = viewController {
                    // GK needs to show its own login UI — present from root view controller
                    UIApplication.shared.connectedScenes
                        .compactMap { $0 as? UIWindowScene }
                        .first?.windows.first?.rootViewController?
                        .present(vc, animated: true)
                }
                self?.isAuthenticated = GKLocalPlayer.local.isAuthenticated
            }
        }
    }

    // MARK: - Leaderboards

    func submitScore(_ score: Int, to leaderboardID: String) {
        guard isAuthenticated else { return }
        GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local,
                                  leaderboardIDs: [leaderboardID]) { _ in }
    }

    // MARK: - Achievements

    /// Reports 100% completion. Game Center ignores duplicate reports, so this is safe to call repeatedly.
    func reportAchievement(_ id: String) {
        guard isAuthenticated else { return }
        let achievement = GKAchievement(identifier: id)
        achievement.percentComplete = 100
        achievement.showsCompletionBanner = true
        GKAchievement.report([achievement]) { _ in }
    }

    // MARK: - Dashboard

    func showDashboard() {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first?.rootViewController else { return }
        let vc = GKGameCenterViewController(state: .default)
        vc.gameCenterDelegate = self
        root.present(vc, animated: true)
    }
}

// MARK: - GKGameCenterControllerDelegate

extension GameCenterManager: GKGameCenterControllerDelegate {
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}
