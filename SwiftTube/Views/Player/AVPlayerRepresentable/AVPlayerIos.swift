//
//  AVPlayerIos.swift
//  SwiftJelly
//
//  Created by Zabir Raihan on 10/07/2025.
//

import SwiftUI
import AVKit

struct AVPlayerIos: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.allowsPictureInPicturePlayback = true
        controller.delegate = context.coordinator
        
        // Store reference in coordinator
        context.coordinator.playerViewController = controller
        
        // Add swipe up gesture
        let swipeUp = UISwipeGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleSwipeUp)
        )
        swipeUp.direction = .up
        controller.view.addGestureRecognizer(swipeUp)
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.delegate = context.coordinator
        context.coordinator.playerViewController = uiViewController
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        private var isInFullscreen = false
        weak var playerViewController: AVPlayerViewController?
        
        override init() {
            super.init()
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(appWillEnterForeground),
                name: UIApplication.willEnterForegroundNotification,
                object: nil
            )
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        // MARK: - Swipe Gesture Handler
        @objc func handleSwipeUp() {
            guard let playerViewController = playerViewController,
                  !isInFullscreen else { return }
            
            playerViewController.perform(NSSelectorFromString("enterFullScreenAnimated:completionHandler:"), with: true, with: nil)
        }
        
        func playerViewController(
            _ playerViewController: AVPlayerViewController,
            willBeginFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator
        ) {
            self.playerViewController = playerViewController
            isInFullscreen = true
            
            coordinator.animate(alongsideTransition: nil) { _ in
                OrientationManager.shared.lockOrientation(.landscape, rotateTo: .landscapeRight)
            }
        }
        
        func playerViewController(
            _ playerViewController: AVPlayerViewController,
            willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator
        ) {
            let wasPlaying = playerViewController.player?.timeControlStatus == .playing
            
            coordinator.animate(alongsideTransition: nil) { context in
                if context.isCancelled {
                    // Transition was cancelled - stay in fullscreen, re-lock landscape
                    OrientationManager.shared.lockOrientation(.landscape, rotateTo: .landscapeRight)
                } else {
                    // Transition completed - actually exiting fullscreen
                    self.isInFullscreen = false
                    OrientationManager.shared.lockOrientation(.all, rotateTo: .portrait)
                    if wasPlaying {
                        playerViewController.player?.play()
                    }
                }
            }
        }
        
        // MARK: - Handle foreground return
        @objc private func appWillEnterForeground() {
            guard isInFullscreen else { return }
            
            if let _ = playerViewController {
                OrientationManager.shared.lockOrientation(.landscape, rotateTo: .landscapeRight)
            }
        }
    }
}
