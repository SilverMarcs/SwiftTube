import UIKit

/// Hosts the app-wide `AVPlayerViewController` for one SwiftUI presentation of
/// the player, without owning it.
final class PlayerContainerViewController: UIViewController {
    private let host: PlayerViewControllerHost

    init(host: PlayerViewControllerHost) {
        self.host = host
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        host.embed(in: self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        host.embed(in: self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        host.containerDidAppear(self)
    }

    #if os(tvOS)
    override var preferredFocusEnvironments: [any UIFocusEnvironment] {
        [host.playerViewController]
    }
    #endif

    func releasePlayerViewController() {
        host.detach(from: self)
    }
}
