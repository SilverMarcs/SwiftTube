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
        ForEach(Array(watchLaterVideos.prefix(3))) { video in
            WatchLaterVideoCard(video: video)
//                .alignmentGuide(.listRowSeparatorLeading) { _ in
//                    return 0
//                }
        }
        
        if watchLaterVideos.count > 3 {
            NavigationLink {
                List {
                    ForEach(watchLaterVideos) { video in
                        WatchLaterVideoCard(video: video)
                    }
                }
                .navigationTitle("Watch Later")
                .toolbarTitleDisplayMode(.inline)
            } label: {
                Text("View All")
                    .foregroundStyle(.accent)
            }
            .navigationLinkIndicatorVisibility(.hidden)
        }
    }
}

#Preview {
    WatchLaterView()
}
