//
//  HistoryView.swift
//
//  Created by Zabir Raihan on 29/09/2025.
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(
        filter: #Predicate<Video> { $0.lastWatchedAt != nil },
        sort: \Video.lastWatchedAt,
        order: .reverse
    ) private var historyVideos: [Video]
    
    var body: some View {
        ForEach(Array(historyVideos.prefix(3))) { video in
            CompactVideoCard(video: video)
        }
        
        NavigationLink {
            List {
                ForEach(historyVideos) { video in
                    CompactVideoCard(video: video)
                        .swipeActions {
                            Button {
                                video.lastWatchedAt = nil
                            } label: {
                                Label("Remove from History", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                }
            }
            .navigationTitle("History")
            .toolbarTitleDisplayMode(.inline)
            .contentMargins(.top, 5)
        } label: {
            Text("View All")
                .foregroundStyle(.accent)
        }
        .navigationLinkIndicatorVisibility(.hidden)
    }
}

#Preview {
    HistoryView()
}
