//
//  HistoryView.swift
//
//  Created by Zabir Raihan on 29/09/2025.
//

import SwiftUI

struct HistoryView: View {
    @Environment(CloudStoreManager.self) private var userDefaults
    @Environment(VideoLoader.self) private var videoLoader
    @State private var detailedHistoryVideos: [Video] = []
    
    private var historyVideos: [Video] {
        videoLoader.videos.filter { userDefaults.isInHistory($0.id) }
            .sorted {
                let time1 = userDefaults.getWatchTime($0.id) ?? .distantPast
                let time2 = userDefaults.getWatchTime($1.id) ?? .distantPast
                return time1 > time2
            }
    }
    
    var body: some View {
        let displayedVideos = detailedHistoryVideos.isEmpty ? historyVideos : detailedHistoryVideos

        Section {
            ForEach(Array(displayedVideos.prefix(3))) { video in
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
            
            NavigationLink {
                List {
                    ForEach(displayedVideos) { video in
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
            }
            .navigationLinkIndicatorVisibility(.hidden)
        } header: {
            Text("History")
        }
        .task(id: historyVideos.map(\.id)) {
            await loadHistoryVideoDetails(for: historyVideos)
        }
    }

    private func loadHistoryVideoDetails(for videos: [Video]) async {
        guard !videos.isEmpty else {
            detailedHistoryVideos = []
            return
        }

        do {
            var mutableVideos = videos
            try await YTService.fetchVideoDetails(for: &mutableVideos)
            detailedHistoryVideos = mutableVideos
        } catch {
            detailedHistoryVideos = videos
            print("Error updating history video details: \(error.localizedDescription)")
        }
    }
}

#Preview {
    HistoryView()
        .environment(CloudStoreManager.shared)
}
