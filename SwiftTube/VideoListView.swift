// VideoListView.swift
import SwiftUI

struct VideoListView: View {
    let channelStore: ChannelStore
    
    var body: some View {
        List(channelStore.videos) { video in
            VideoRowView(video: video, channelStore: channelStore) // Pass channelStore
        }
        .refreshable {
            await channelStore.fetchAllVideos()
        }
        .overlay {
            if channelStore.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
    }
}