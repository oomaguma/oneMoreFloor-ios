import UIKit
import SwiftUI
import GoogleMobileAds
import UserMessagingPlatform
import AppTrackingTransparency

class GameViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Show the game immediately; ads initialize after consent is resolved.
        let vc = UIHostingController(rootView: ContentView())
        addChild(vc)
        vc.view.frame = view.bounds
        vc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(vc.view)
        vc.didMove(toParent: self)

        requestConsentThenStartAds()
    }

    private func requestConsentThenStartAds() {
        ConsentInformation.shared.requestConsentInfoUpdate(with: nil) { [weak self] error in
            guard let self, error == nil else {
                // UMP failed — still need to handle ATT before starting ads.
                self?.requestATTIfNeeded { MobileAds.shared.start() }
                return
            }
            // UMP 3.x requests ATT automatically for non-EEA users when
            // NSUserTrackingUsageDescription is present, but we add an explicit
            // fallback so ads always start even if UMP skips the ATT prompt.
            ConsentForm.loadAndPresentIfRequired(from: self) { [weak self] _ in
                self?.requestATTIfNeeded { MobileAds.shared.start() }
            }
        }
    }

    private func requestATTIfNeeded(then completion: @escaping () -> Void) {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            completion()
            return
        }
        ATTrackingManager.requestTrackingAuthorization { _ in
            DispatchQueue.main.async { completion() }
        }
    }

    override var prefersStatusBarHidden: Bool { true }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .phone ? .portrait : .all
    }
}
