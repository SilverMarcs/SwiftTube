//
//  HistoryView.swift
//
//  Created by Zabir Raihan on 29/09/2025.
//

import SwiftUI

struct HistoryView: View {
    @Environment(UserDefaultsManager.self) private var userDefaults
    @Environment(VideoLoader.self) private var videoLoader
    
    private var historyVideos: [Video] {
        videoLoader.videos.filter { userDefaults.isInHistory($0.id) }
            .sorted {
                let time1 = userDefaults.getWatchTime($0.id) ?? .distantPast
                let time2 = userDefaults.getWatchTime($1.id) ?? .distantPast
                return time1 > time2
            }
    }
    
    var body: some View {
        Section {
            ForEach(Array(historyVideos.prefix(3))) { video in
                CompactVideoCard(video: video)
            }
            
            NavigationLink {
                List {
                    ForEach(historyVideos) { video in
                        CompactVideoCard(video: video)
                            .swipeActions {
                                Button {
                                    userDefaults.removeFromHistory(video.id)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                                .tint(.red)
                            }
                    }
                }
                .navigationTitle("History")
                .toolbarTitleDisplayMode(.inline)
                .contentMargins(.top, 5)
            } label: {
                Text("View full history")
                    .foregroundStyle(.accent)
            }
            .navigationLinkIndicatorVisibility(.hidden)
        } header: {
            Text("History")
        }
    }
}

#Preview {
    HistoryView()
        .environment(UserDefaultsManager.shared)
}
