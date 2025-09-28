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
    let isActive: Bool
    
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
                .aspectRatio(9/16, contentMode: .fit)
            }
            
            if let channel = video.channel {
                ChannelRowView(channel: channel, showSubs: false)
                    .padding()
            }
        }
        .task(id: isActive) {
            if isActive {
                setupPlayer()
            } else {
                youTubePlayer = nil
            }
        }
    }
    
    private func setupPlayer() {
        youTubePlayer = YouTubePlayer(
            source: .video(id: video.id),
            parameters: .init(
                autoPlay: true,
                loopEnabled: true,
                showControls: false
            ),
            configuration: .init(
                allowsInlineMediaPlayback: true,
                allowsPictureInPictureMediaPlayback: false,
            )
        )
    }
}
