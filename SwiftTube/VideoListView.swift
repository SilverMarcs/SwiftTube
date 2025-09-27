// VideoListView.swift
import SwiftUI

struct VideoListView: View {
    @Environment(\.channelStore) var channelStore
    
    var body: some View {
        List(channelStore.videos) { video in
            VideoRowView(video: video)
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
