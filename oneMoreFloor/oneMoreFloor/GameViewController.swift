import UIKit
import SwiftUI
import GoogleMobileAds
import UserMessagingPlatform

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
                MobileAds.shared.start()
                return
            }
            ConsentForm.loadAndPresentIfRequired(from: self) { _ in
                MobileAds.shared.start()
            }
        }
    }

    override var prefersStatusBarHidden: Bool { true }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .phone ? .portrait : .all
    }
}
