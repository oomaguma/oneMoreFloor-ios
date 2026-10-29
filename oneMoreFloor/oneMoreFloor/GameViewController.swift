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

        // Ad consent + the tracking (ATT) prompt wait until the first-session
        // tutorial is done: two system dialogs before the player has tapped
        // anything is a fast way to lose them. No ads are shown during the
        // tutorial anyway. Returning players (tutorial done, or saw the old
        // intro) go straight through.
        let returning = TutorialStep.current == .done
            || UserDefaults.standard.bool(forKey: "com.oneMoreFloor.seenIntro")
        if returning {
            requestConsentThenStartAds()
        } else {
            tutorialObserver = NotificationCenter.default.addObserver(
                forName: .tutorialFinished, object: nil, queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                if let observer = self.tutorialObserver {
                    NotificationCenter.default.removeObserver(observer)
                    self.tutorialObserver = nil
                }
                self.requestConsentThenStartAds()
            }
        }
    }

    /// Waits for the tutorial to finish (first launch only).
    private var tutorialObserver: NSObjectProtocol?

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
