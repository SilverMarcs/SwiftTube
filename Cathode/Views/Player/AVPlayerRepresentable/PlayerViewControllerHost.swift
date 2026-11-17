import AVKit
import UIKit

/// Owns the single `AVPlayerViewController` used for long-form playback.
///
/// Picture in Picture, Now Playing, and lock-screen controls all belong to the
/// `AVPlayerViewController`, but SwiftUI tears a representable's controller
/// down whenever the player UI is dismissed. A long-lived controller lets those
/// survive collapsing the player, and it keeps presentation transitions from
/// attaching several controllers to the same `AVPlayer` (which leaves AVKit
/// unable to decide which one may start Picture in Picture).
final class PlayerViewControllerHost: NSObject {
    /// Created on first use so AVKit isn't loaded while the app is launching.
    private(set) lazy var playerViewController = makePlayerViewController()

    /// True from the moment Picture in Picture starts until it fully stops.
    private(set) var isPictureInPictureActive = false

    /// Asks the app to show (`true`) or hide (`false`) the full player UI.
    var onPresentationRequest: ((Bool) -> Void)?

    #if os(tvOS)
    /// Receives the tvOS content proposal ("Up Next") delegate callbacks.
    weak var contentProposalDelegate: AVPlayerViewControllerDelegate?
    #endif

    private var pendingRestoreCompletion: ((Bool) -> Void)?
    private var restoreTimeoutTask: Task<Void, Never>?

    private func makePlayerViewController() -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.delegate = self
        controller.allowsPictureInPicturePlayback = true
        #if os(tvOS)
        controller.transportBarIncludesTitleView = true
        controller.speeds = [
            AVPlaybackSpeed(rate: 0.5, localizedName: "0.5×"),
            AVPlaybackSpeed(rate: 1.0, localizedName: "1×"),
            AVPlaybackSpeed(rate: 1.25, localizedName: "1.25×"),
            AVPlaybackSpeed(rate: 1.5, localizedName: "1.5×"),
            AVPlaybackSpeed(rate: 2.0, localizedName: "2×")
        ]
        #else
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.updatesNowPlayingInfoCenter = true
        let swipeUp = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeUp))
        swipeUp.direction = .up
        controller.view.addGestureRecognizer(swipeUp)
        #endif
        return controller
    }

    func setPlayer(_ player: AVPlayer?) {
        guard playerViewController.player !== player else { return }
        playerViewController.player = player
    }

    // MARK: - Embedding

    func embed(in container: UIViewController) {
        let controller = playerViewController
        guard controller.parent !== container else { return }
        if controller.parent != nil {
            removeFromCurrentParent()
        }
        container.addChild(controller)
        controller.view.frame = container.view.bounds
        controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.view.addSubview(controller.view)
        controller.didMove(toParent: container)
    }

    /// Only the container currently holding the controller may remove it; an
    /// outgoing presentation must not steal it back from an incoming one.
    func detach(from container: UIViewController) {
        guard playerViewController.parent === container else { return }
        removeFromCurrentParent()
    }

    func containerDidAppear(_ container: UIViewController) {
        guard playerViewController.parent === container else { return }
        if pendingRestoreCompletion != nil {
            finishPendingRestore(restored: true)
        } else if isPictureInPictureActive {
            // The player UI was opened from inside the app (a new video, or the
            // mini player) while the video floats. Bring it back inline instead
            // of showing AVKit's "playing in Picture in Picture" placeholder.
            stopPictureInPicture()
        }
    }

    private func removeFromCurrentParent() {
        let controller = playerViewController
        controller.willMove(toParent: nil)
        controller.view.removeFromSuperview()
        controller.removeFromParent()
    }

    /// AVPlayerViewController has no public stop API; detaching the player
    /// ends Picture in Picture without pausing playback.
    private func stopPictureInPicture() {
        guard let player = playerViewController.player else { return }
        let wasPlaying = player.rate > 0
        playerViewController.player = nil
        Task { @MainActor [weak self] in
            guard let self, self.playerViewController.player == nil else { return }
            self.playerViewController.player = player
            if wasPlaying, player.rate == 0 {
                player.play()
            }
        }
    }

    private func finishPendingRestore(restored: Bool) {
        restoreTimeoutTask?.cancel()
        restoreTimeoutTask = nil
        guard let completion = pendingRestoreCompletion else { return }
        pendingRestoreCompletion = nil
        completion(restored)
    }

    #if !os(tvOS)
    @objc private func handleSwipeUp() {
        playerViewController.perform(
            NSSelectorFromString("enterFullScreenAnimated:completionHandler:"),
            with: true,
            with: nil
        )
    }
    #endif
}

extension PlayerViewControllerHost: AVPlayerViewControllerDelegate {
    func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        isPictureInPictureActive = true
    }

    func playerViewControllerDidStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        // Collapse the player so the rest of the app is usable while the video
        // floats. On iOS, PiP that started because the app went to the
        // background keeps the player expanded so returning restores in place.
        #if os(tvOS)
        onPresentationRequest?(false)
        #else
        if playerViewController.view.window?.windowScene?.activationState == .foregroundActive {
            onPresentationRequest?(false)
        }
        #endif
    }

    func playerViewController(
        _ playerViewController: AVPlayerViewController,
        failedToStartPictureInPictureWithError error: any Error
    ) {
        print("Picture in Picture failed to start: \(error.localizedDescription)")
        isPictureInPictureActive = false
    }

    func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        isPictureInPictureActive = false
        finishPendingRestore(restored: playerViewController.view.window != nil)
    }

    func playerViewController(
        _ playerViewController: AVPlayerViewController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        if playerViewController.view.window != nil {
            completionHandler(true)
            return
        }
        finishPendingRestore(restored: false)
        pendingRestoreCompletion = completionHandler
        onPresentationRequest?(true)
        restoreTimeoutTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            guard let self else { return }
            self.finishPendingRestore(restored: self.playerViewController.view.window != nil)
        }
    }

    #if os(tvOS)
    func playerViewController(
        _ playerViewController: AVPlayerViewController,
        shouldPresent proposal: AVContentProposal
    ) -> Bool {
        contentProposalDelegate?.playerViewController?(playerViewController, shouldPresent: proposal) ?? false
    }

    func playerViewController(
        _ playerViewController: AVPlayerViewController,
        didAccept proposal: AVContentProposal
    ) {
        contentProposalDelegate?.playerViewController?(playerViewController, didAccept: proposal)
    }

    func playerViewController(
        _ playerViewController: AVPlayerViewController,
        didReject proposal: AVContentProposal
    ) {
        contentProposalDelegate?.playerViewController?(playerViewController, didReject: proposal)
    }
    #else
    #if os(iOS)
    func playerViewController(
        _ playerViewController: AVPlayerViewController,
        willBeginFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator
    ) {
        coordinator.animate(alongsideTransition: nil) { context in
            guard !context.isCancelled else { return }
            AppDelegate.setFullScreenLandscape(true, in: playerViewController.view.window?.windowScene)
        }
    }
    #endif

    func playerViewController(
        _ playerViewController: AVPlayerViewController,
        willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator
    ) {
        let wasPlaying = playerViewController.player?.timeControlStatus == .playing
        coordinator.animate(alongsideTransition: nil) { context in
            guard !context.isCancelled else { return }
            #if os(iOS)
            AppDelegate.setFullScreenLandscape(false, in: playerViewController.view.window?.windowScene)
            #endif
            if wasPlaying {
                playerViewController.player?.play()
            }
        }
    }
    #endif
}
