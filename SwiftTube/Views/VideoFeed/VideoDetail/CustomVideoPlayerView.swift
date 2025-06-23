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
    let video: Video
    let playerViewModel: VideoPlayerViewModel
    var isShort: Bool = false
    
    @State private var isLoading = true
    @State private var hasLoaded = false
    
    init(videoStream: VideoStreamResponse, video: Video, playerViewModel: VideoPlayerViewModel, isShort: Bool = false) {
        self.videoStream = videoStream
        self.video = video
        self.playerViewModel = playerViewModel
        self.isShort = isShort
    }
    
    var body: some View {
        VideoPlayerView(player: playerViewModel.player, isShort: isShort)
            .onAppear {
                if !hasLoaded {
                    loadStream(videoStream)
                    hasLoaded = true
                }
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
        
        playerViewModel.player.replaceCurrentItem(with: playerItem)
        playerViewModel.player.actionAtItemEnd = .none
        playerViewModel.player.automaticallyWaitsToMinimizeStalling = true
        
        playerViewModel.player.play()
        
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
        
        // Ensure player stays connected during fullscreen transitions
        controller.updatesNowPlayingInfoCenter = true
        
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // Only update player if it's different to avoid unnecessary player replacements
        if uiViewController.player !== player {
            uiViewController.player = player
        }
    }
}
