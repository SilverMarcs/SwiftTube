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
    let namespace: Namespace.ID

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
        VStack {
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
            .navigationTransition(.zoom(sourceID: "video-\(video.id)", in: namespace))
            .aspectRatio(16/9, contentMode: .fit)
                     
            ScrollView {
                Text(video.title)
                    .font(.headline)
   
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        
    }
}

