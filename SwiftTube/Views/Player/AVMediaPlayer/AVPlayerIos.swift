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
        
        // Delegate + notifications to detect fullscreen reliably
        controller.delegate = context.coordinator
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.delegate = context.coordinator
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        private var isInFullscreen = false
        private weak var playerViewController: AVPlayerViewController?
        
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
            isInFullscreen = false
            
            let wasPlaying = playerViewController.player?.timeControlStatus == .playing
            coordinator.animate(alongsideTransition: nil) { _ in
                OrientationManager.shared.lockOrientation(.all, rotateTo: .portrait)
                if wasPlaying {
                    playerViewController.player?.play()
                }
            }
        }
        
        // MARK: - Handle foreground return
        @objc private func appWillEnterForeground() {
            guard isInFullscreen else { return }
            
            // Ensure playerViewController reference still valid
            if let _ = playerViewController {
                OrientationManager.shared.lockOrientation(.landscape, rotateTo: .landscapeRight)
            }
        }
    }
}
