//
//  WatchLaterView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 29/09/2025.
//

import SwiftUI

struct WatchLaterView: View {
    @Environment(CloudStoreManager.self) private var userDefaults
    @State private var detailedWatchLaterVideos: [Video] = []

    private var watchLaterVideos: [Video] {
        userDefaults.watchLaterVideos
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
                FullWatchLaterList(videos: displayedVideos)
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

private struct FullWatchLaterList: View {
    @Environment(CloudStoreManager.self) private var userDefaults
    let videos: [Video]

    private var displayedVideos: [Video] {
        let ids = Set(userDefaults.watchLaterVideos.map(\.id))
        let filtered = videos.filter { ids.contains($0.id) }
        if filtered.count == ids.count {
            return filtered
        }
        let known = Set(filtered.map(\.id))
        let extras = userDefaults.watchLaterVideos.filter { !known.contains($0.id) }
        return filtered + extras
    }

    var body: some View {
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
    }
}

#Preview {
    WatchLaterView()
        .environment(CloudStoreManager.shared)
}
