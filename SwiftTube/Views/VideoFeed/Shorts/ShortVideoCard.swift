//
//  ShortVideoCard.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 23/06/2025.
//

import SwiftUI
import YouTubePlayerKit

struct ShortVideoCard: View {
    // TODO: track watch time but dont start at that position
    let video: Video
    @StateObject private var viewModel: VideoPlayerViewModel

    init(video: Video) {
        self.video = video
        let player = YouTubePlayer(
            // Possible values: .video, .videos, .playlist, .channel
            source: .video(id: video.id),
            // The parameters of the player
            parameters: .init(
                autoPlay: true,
                showControls: true,
                showFullscreenButton: false,
            ),
            // The configuration of the underlying web view
            configuration: .init(
                fullscreenMode: .system,
                allowsInlineMediaPlayback: true,
            ))
        self._viewModel = StateObject(wrappedValue: VideoPlayerViewModel(video: video, youTubePlayer: player))
    }
    
    var youTubePlayer: YouTubePlayer {
        viewModel.youTubePlayer
    }
    
    
    var body: some View {
        YouTubePlayerView(youTubePlayer) { state in
            switch state {
            case .idle:
                Rectangle()
                    .fill(.background.secondary)
                    .overlay {
                        ProgressView()
                    }
            case .ready:
                EmptyView()
            case .error(let error):
                ContentUnavailableView(
                    "Error",
                    systemImage: "exclamationmark.triangle.fill",
                    description: Text("YouTube player couldn't be loaded: \(error.localizedDescription)")
                )
            }
        }
        .aspectRatio(9/16, contentMode: .fit)
        .onDisappear {
            Task {
                try? await youTubePlayer.stop()
            }
        }
    }
}
