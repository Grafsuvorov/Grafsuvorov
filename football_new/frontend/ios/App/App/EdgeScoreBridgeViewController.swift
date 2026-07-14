import UIKit
import Capacitor

final class EdgeScoreBridgeViewController: CAPBridgeViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 4.0 / 255.0, green: 7.0 / 255.0, blue: 18.0 / 255.0, alpha: 1.0)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        .fade
    }
}
