//
//  CustomVideoPlayerView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 22/06/2025.
//

import SwiftUI
import AVKit

struct CustomVideoPlayerView: View {
    let videoStream: VideoStreamResponse
    var isShort: Bool = false
    
    @State private var player = AVPlayer()
    @State private var isLoading = true
    
    var body: some View {
        VideoPlayerView(player: player, isShort: isShort)
            .onAppear {
                loadStream(videoStream)
            }
            .onDisappear {
                cleanup()
            }
    }
    
    // MARK: - Private Methods
    private func loadStream(_ stream: VideoStreamResponse) {
        guard let urlString = stream.url,
              let streamURL = URL(string: urlString) else { return }
        
        isLoading = true
        
        // Create AVURLAsset with proper configuration for Piped
        let asset = createNonProxiedAsset(from: streamURL)
        let playerItem = AVPlayerItem(asset: asset)
        
        playerItem.preferredForwardBufferDuration = 5
        playerItem.preferredPeakBitRate = Double(stream.bitrate ?? 1000000)
        
        player.replaceCurrentItem(with: playerItem)
        player.actionAtItemEnd = .none
        player.automaticallyWaitsToMinimizeStalling = true
        
        player.play()
        
        isLoading = false
    }
    
    private func createNonProxiedAsset(from url: URL) -> AVURLAsset {
        guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return AVURLAsset(url: url)
        }
        guard let hostItem = urlComponents.queryItems?.first(where: { $0.name == "host" }),
              let hostValue = hostItem.value else {
            return AVURLAsset(url: url)
        }
        urlComponents.host = hostValue
        if let directURL = urlComponents.url {
            return AVURLAsset(url: directURL)
        }
        return AVURLAsset(url: url)
    }
    
    private func cleanup() {
        player.pause()
        player.replaceCurrentItem(with: nil)
    }
}

// MARK: - VideoPlayerView

struct VideoPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer
    let isShort: Bool

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = !isShort
        controller.videoGravity = .resizeAspect
        controller.allowsPictureInPicturePlayback = !isShort
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}
