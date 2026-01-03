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
    
    private var watchLaterVideos: [Video] {
        videoLoader.videos.filter { userDefaults.isWatchLater($0.id) }
            .sorted { $0.publishedAt > $1.publishedAt }
    }
    
    var body: some View {
        Section {
            ForEach(Array(watchLaterVideos.prefix(3))) { video in
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
                    ForEach(watchLaterVideos) { video in
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
    }
}

#Preview {
    WatchLaterView()
        .environment(CloudStoreManager.shared)
}
