//
//  ShortVideoCard.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 23/06/2025.
//

import SwiftUI
import YouTubePlayerKit

struct ShortVideoCard: View {
    let video: Video
    
    var youTubePlayer: YouTubePlayer { YouTubePlayer(
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
