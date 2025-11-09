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
        weak var playerViewController: AVPlayerViewController?
        
        // MARK: - Swipe Gesture Handler
        @objc func handleSwipeUp() {
            guard let playerViewController = playerViewController else { return }
            
            playerViewController.perform(NSSelectorFromString("enterFullScreenAnimated:completionHandler:"), with: true, with: nil)
        }
        
        func playerViewController(
            _ playerViewController: AVPlayerViewController,
            willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator
        ) {
            let wasPlaying = playerViewController.player?.timeControlStatus == .playing
            
            coordinator.animate(alongsideTransition: nil) { context in
                if !context.isCancelled {
                    if wasPlaying {
                        playerViewController.player?.play()
                    }
                }
            }
        }
    }
}
