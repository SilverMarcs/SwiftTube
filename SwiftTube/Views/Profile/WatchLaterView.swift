//
//  WatchLaterView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 29/09/2025.
//

import SwiftUI
import SwiftData

struct WatchLaterView: View {
    @Query(
        filter: #Predicate<Video> { $0.isWatchLater == true },
        sort: \Video.publishedAt,
        order: .reverse
    ) private var watchLaterVideos: [Video]
    
    @State private var showingAllVideos = false
    
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
                                    video.isWatchLater = false
                                } label: {
                                    Label("Remove from Watch Later", systemImage: "bookmark.slash")
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
    }
}

#Preview {
    WatchLaterView()
}
