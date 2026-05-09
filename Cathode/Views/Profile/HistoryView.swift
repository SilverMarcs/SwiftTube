//
//  HistoryView.swift
//
//  Created by Zabir Raihan on 29/09/2025.
//

import SwiftUI

struct HistoryView: View {
    @Environment(CloudStoreManager.self) private var userDefaults
    @State private var detailedHistoryVideos: [Video] = []

    private var historyVideos: [Video] {
        userDefaults.historyVideos
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
                FullHistoryList(videos: displayedVideos)
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

private struct FullHistoryList: View {
    @Environment(CloudStoreManager.self) private var userDefaults
    let videos: [Video]

    private var displayedVideos: [Video] {
        let ids = Set(userDefaults.historyVideos.map(\.id))
        let filtered = videos.filter { ids.contains($0.id) }
        if filtered.count == ids.count {
            return filtered
        }
        let known = Set(filtered.map(\.id))
        let extras = userDefaults.historyVideos.filter { !known.contains($0.id) }
        return filtered + extras
    }

    var body: some View {
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
    }
}

#Preview {
    HistoryView()
        .environment(CloudStoreManager.shared)
}
