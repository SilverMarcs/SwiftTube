//
//  WatchLaterView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 29/09/2025.
//

import SwiftUI

struct WatchLaterView: View {
    @Environment(VideoLoader.self) private var videoLoader
    @Environment(CloudStoreManager.self) private var userDefaults
    @State private var detailedWatchLaterVideos: [Video] = []
    
    private var watchLaterVideos: [Video] {
        videoLoader.videos.filter { userDefaults.isWatchLater($0.id) }
            .sorted { $0.publishedAt > $1.publishedAt }
    }
    
    var body: some View {
        let displayedVideos = detailedWatchLaterVideos.isEmpty ? watchLaterVideos : detailedWatchLaterVideos

        Section {
            ForEach(Array(displayedVideos.prefix(3))) { video in
                CompactVideoCard(video: video)
                    .swipeActions {
                        Button {
                            withAnimation {
                                userDefaults.removeFromWatchLater(video.id)
                            }
                        } label: {
                            Label("Remove", systemImage: "bookmark.slash")
                        }
                    }
            }
            
            NavigationLink {
                List {
                    ForEach(displayedVideos) { video in
                        CompactVideoCard(video: video)
                            .swipeActions {
                                Button {
                                    withAnimation {
                                        userDefaults.removeFromWatchLater(video.id)
                                    }
                                } label: {
                                    Label("Remove", systemImage: "bookmark.slash")
                                }
                            }
                    }
                }
                .navigationTitle("Watch Later")
                .toolbarTitleDisplayMode(.inline)
                .contentMargins(.top, 5)
            } label: {
                Text("View all Watch Later videos")
                    .foregroundStyle(.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
            }
            .navigationLinkIndicatorVisibility(.hidden)
        } header: {
            Text("Watch Later")
        }
        .task(id: watchLaterVideos.map(\.id)) {
            await loadWatchLaterVideoDetails(for: watchLaterVideos)
        }
    }

    private func loadWatchLaterVideoDetails(for videos: [Video]) async {
        guard !videos.isEmpty else {
            detailedWatchLaterVideos = []
            return
        }

        do {
            var mutableVideos = videos
            try await YTService.fetchVideoDetails(for: &mutableVideos)
            detailedWatchLaterVideos = mutableVideos
        } catch {
            detailedWatchLaterVideos = videos
            print("Error updating watch later video details: \(error.localizedDescription)")
        }
    }
}

#Preview {
    WatchLaterView()
        .environment(CloudStoreManager.shared)
}
