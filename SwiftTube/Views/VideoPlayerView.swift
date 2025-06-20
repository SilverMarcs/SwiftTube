//
//  VideoPlayerView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 20/06/2025.
//

import SwiftUI
import YouTubePlayerKit

struct VideoPlayerView: View {
    let video: Video

    var youTubePlayer: YouTubePlayer { YouTubePlayer(
        // Possible values: .video, .videos, .playlist, .channel
        source: .video(id: video.id),
        // The parameters of the player
        parameters: .init(
            autoPlay: true,
            showControls: true,
        ),
        // The configuration of the underlying web view
        configuration: .init(
            fullscreenMode: .system,
            allowsInlineMediaPlayback: true,
        ))
    }
    
    
    var body: some View {
        ScrollView {
            YouTubePlayerView(youTubePlayer)
                .frame(height: 400)
            
            Text(video.title)
                .font(.title)
                .padding()
            
            Spacer()
        }
        .toolbarTitleDisplayMode(.inline)
    }
}

