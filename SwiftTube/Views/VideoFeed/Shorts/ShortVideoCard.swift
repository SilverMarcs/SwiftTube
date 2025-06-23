//
//  ShortVideoCard.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 23/06/2025.
//

import SwiftUI
import Kingfisher

struct ShortVideoCard: View {
    // TODO: track watch time but dont start at that position
    let video: Video
    @State private var videoDetail: VideoDetail?
    @State private var isLoading = true
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let streams = videoDetail?.videoStreams {
                CustomVideoPlayerView(videoStream: streams.first { $0.videoOnly == false } ?? streams.last!, isShort: true)
                    .aspectRatio(9/16, contentMode: .fit)
            } else {
                ProgressView()
                    .controlSize(.large)
            }
            
            if let detail = videoDetail {
                ChannelInfoRow(videoDetail: detail)
                    .padding()
            }
        }
        .task {
            await loadVideoDetails()
        }
    }
    
    private func loadVideoDetails() async {
        isLoading = true
        let detail = await PipedAPI.shared.fetchVideoDetail(videoId: video.id)
        self.videoDetail = detail
        isLoading = false
    }
}
