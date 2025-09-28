//
//  ShortVideoCard.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 28/09/2025.
//

import SwiftUI
import YouTubePlayerKit

struct ShortVideoCard: View {
    let video: Video
    
    @State private var youTubePlayer: YouTubePlayer?
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let player = youTubePlayer {
                YouTubePlayerView(player) { state in
                    switch state {
                    case .idle:
                        ProgressView()
                            .scaleEffect(1.5)
                    case .ready:
                        EmptyView()
                    case .error(let error):
                        ContentUnavailableView(
                            "Video Unavailable",
                            systemImage: "exclamationmark.triangle.fill",
                            description: Text(error.localizedDescription)
                        )
                    }
                }
                .aspectRatio(9/16, contentMode: .fit) // Vertical aspect ratio for shorts
//                .frame(maxWidth: .infinity, maxHeight: .infinity)
//                .clipped()
            }
            
            if let channel = video.channel {
                ChannelRowView(channel: channel, showSubs: false)
            }
        }
        .onAppear {
            setupPlayer()
        }
    }
    
    private func setupPlayer() {
        youTubePlayer = YouTubePlayer(
            source: .video(id: video.id),
            parameters: .init(
                autoPlay: true,
                showControls: false
            ),
            configuration: .init(
                allowsInlineMediaPlayback: true,
                allowsPictureInPictureMediaPlayback: false
            )
        )
    }
}
