import GoogleMobileAds
import UIKit

@Observable
@MainActor
final class AdManager {
    private(set) var isOfflineAdReady = false
    private(set) var isReviveAdReady  = false

    private var offlineAd: RewardedAd?
    private var reviveAd:  RewardedAd?

    // Google's test IDs are used in debug builds so ads always load during development.
    // Release builds use the real AdMob ad unit IDs.
    #if DEBUG
    private static let offlineAdUnitID = "ca-app-pub-3940256099942544/1712485313"
    private static let reviveAdUnitID  = "ca-app-pub-3940256099942544/1712485313"
    #else
    private static let offlineAdUnitID = "ca-app-pub-2071020921604740/4000392120"
    private static let reviveAdUnitID  = "ca-app-pub-2071020921604740/4054712530"
    #endif

    init() {
        guard !UserDefaults.standard.bool(forKey: "com.oneMoreFloor.removeAds") else { return }
        Task { await loadOfflineAd() }
        Task { await loadReviveAd() }
    }

    private func loadOfflineAd() async {
        do {
            offlineAd = try await RewardedAd.load(
                with: Self.offlineAdUnitID, request: Request())
            isOfflineAdReady = true
        } catch {
            isOfflineAdReady = false
        }
    }

    private func loadReviveAd() async {
        do {
            reviveAd = try await RewardedAd.load(
                with: Self.reviveAdUnitID, request: Request())
            isReviveAdReady = true
        } catch {
            isReviveAdReady = false
        }
    }

    func showOfflineAd(onReward: @escaping () -> Void) {
        guard let ad = offlineAd, let vc = rootViewController else { return }
        isOfflineAdReady = false
        offlineAd = nil
        ad.present(from: vc, userDidEarnRewardHandler: onReward)
        Task { await loadOfflineAd() }
    }

    func showReviveAd(onReward: @escaping () -> Void) {
        guard let ad = reviveAd, let vc = rootViewController else { return }
        isReviveAdReady = false
        reviveAd = nil
        ad.present(from: vc, userDidEarnRewardHandler: onReward)
        Task { await loadReviveAd() }
    }

    private var rootViewController: UIViewController? {
        UIApplication.shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}
