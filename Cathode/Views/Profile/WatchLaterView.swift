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
        userDefaults.watchLaterVideos.reversed()
    }

    var body: some View {
        let displayedVideos = detailedWatchLaterVideos.isEmpty ? watchLaterVideos : detailedWatchLaterVideos

        Section {
            ForEach(Array(displayedVideos.prefix(3))) { video in
                CompactVideoCard(video: video)
                    #if !os(tvOS)
                    .swipeActions {
                        Button {
                            withAnimation {
                                userDefaults.removeFromWatchLater(video.id)
                            }
                        } label: {
                            Label("Remove", systemImage: "bookmark.slash")
                        }
                    }
                    #endif
            }

            NavigationLink {
                WatchLaterFullView()
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

struct WatchLaterFullView: View {
    @Environment(CloudStoreManager.self) private var userDefaults
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var detailedVideos: [Video] = []

    private var rawVideos: [Video] { userDefaults.watchLaterVideos.reversed() }

    private var displayedVideos: [Video] {
        guard !detailedVideos.isEmpty else { return rawVideos }
        let detailed = Dictionary(uniqueKeysWithValues: detailedVideos.map { ($0.id, $0) })
        return rawVideos.map { detailed[$0.id] ?? $0 }
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                VideoGridView(videos: displayedVideos, showsWatchLaterIcon: false)
            } else {
                List {
                    ForEach(displayedVideos) { video in
                        CompactVideoCard(video: video)
                            #if !os(tvOS)
                            .swipeActions {
                                Button {
                                    withAnimation {
                                        userDefaults.removeFromWatchLater(video.id)
                                    }
                                } label: {
                                    Label("Remove", systemImage: "bookmark.slash")
                                }
                            }
                            #endif
                    }
                }
            }
        }
        .navigationTitle("Watch Later")
        .platformNavigationToolbar(titleDisplayMode: .inline)
        .contentMargins(.top, 5)
        .task(id: rawVideos.map(\.id)) {
            await loadDetails(for: rawVideos)
        }
    }

    private func loadDetails(for videos: [Video]) async {
        guard !videos.isEmpty else { detailedVideos = []; return }
        do {
            var mutableVideos = videos
            try await YTService.fetchVideoDetails(for: &mutableVideos)
            detailedVideos = mutableVideos
        } catch {
            detailedVideos = videos
        }
    }
}

#Preview {
    WatchLaterView()
        .environment(CloudStoreManager.shared)
}
