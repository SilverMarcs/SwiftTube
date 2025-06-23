//
//  ShortVideoCard.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 23/06/2025.
//

import SwiftUI
import Kingfisher
import AVKit

struct ShortVideoCard: View {
    // Watch time is tracked but playback doesn't resume to last position for shorts
    let video: Video
    @State private var videoDetail: VideoDetail?
    @State private var isLoading = true
    @StateObject private var playerViewModel: VideoPlayerViewModel
    
    init(video: Video) {
        self.video = video
        // For shorts, we track watch time but don't resume playback
        self._playerViewModel = StateObject(wrappedValue: VideoPlayerViewModel(video: video, player: AVPlayer(), shouldResume: false))
    }
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let streams = videoDetail?.videoStreams {
                CustomVideoPlayerView(
                    videoStream: streams.first { $0.videoOnly == false } ?? streams.last!,
                    video: video,
                    playerViewModel: playerViewModel,
                    isShort: true
                )
                .aspectRatio(9/16, contentMode: .fit)
                .onDisappear {
                    playerViewModel.player.pause()
                    // cleanup fully
                    playerViewModel.player.replaceCurrentItem(with: nil)
                }
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
