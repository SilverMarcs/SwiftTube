//
//  VideoDetailView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 21/06/2025.
//

import SwiftUI
import Kingfisher

struct VideoDetailView: View {
    let video: Video
    
    @Environment(\.videoNameSpace) private var namespace
//    @StateObject private var viewModel: VideoPlayerViewModel
    
    @State private var videoDetail: VideoDetail?
    @State private var isLoading = true
    @State private var isDescriptionExpanded = false
    
    var body: some View {
        VStack(alignment: .leading) {
            if isLoading {
                ProgressView()
                    .padding(20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let videoDetail = videoDetail {
                // Custom Video Player View
                if let streams = videoDetail.videoStreams {
                    CustomVideoPlayerView(videoStream: streams.first { $0.videoOnly == false } ?? streams.last!)
//                        .navigationTransition(.zoom(sourceID: "video-\(video.id)", in: namespace ?? Namespace().wrappedValue))
                        .aspectRatio(16/9, contentMode: .fit)

                } else {
                    ProgressView()
                        .controlSize(.large)
                }

                ScrollView {
                    // Video Info View with video details
                    // TODO: dont pass video id
                    VideoInfoView(video: video, videoDetail: videoDetail)
                        .frame(maxWidth: .infinity, alignment: .leading) // Add this line
                        .padding(.horizontal)
//                        .padding(.vertical, 12)
//                        .padding(.horizontal, 12)
                }
            } else {
                ContentUnavailableView(
                    "Unable to load video details",
                    systemImage: "exclamationmark.triangle"
                )
            }
        }
        .navigationTransition(.zoom(sourceID: "video-\(video.id)", in: namespace ?? Namespace().wrappedValue))
        #if !os(macOS)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        #endif
        .task {
            await loadVideoDetails()
        }
    }
    
    private func loadVideoDetails() async {
        isLoading = true
        let detail = await PipedAPI.shared.fetchVideoDetail(videoId: video.id)
        self.videoDetail = detail
        self.isLoading = false
    }
}
