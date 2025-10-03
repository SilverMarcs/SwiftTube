//
//  WatchLaterView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 29/09/2025.
//

import SwiftUI

struct WatchLaterView: View {
    @Environment(UserDefaultsManager.self) private var userDefaults
    @State private var videoLoader = VideoLoader()
    
    private var watchLaterVideos: [Video] {
        videoLoader.videos.filter { userDefaults.isWatchLater($0.id) }
            .sorted { $0.publishedAt > $1.publishedAt }
    }
    
    var body: some View {
        Section {
            ForEach(Array(watchLaterVideos.prefix(3))) { video in
                CompactVideoCard(video: video)
//                                .alignmentGuide(.listRowSeparatorLeading) { _ in
//                                    return 0
//                                }
            }
            
            NavigationLink {
                List {
                    ForEach(watchLaterVideos) { video in
                        CompactVideoCard(video: video)
                            .swipeActions {
                                Button {
                                    userDefaults.removeFromWatchLater(video.id)
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
            }
            .navigationLinkIndicatorVisibility(.hidden)
        } header: {
            Text("Watch Later")
        }
        .task {
            await videoLoader.loadAllChannelVideos()
        }
    }
}

#Preview {
    WatchLaterView()
        .environment(UserDefaultsManager.shared)
}
