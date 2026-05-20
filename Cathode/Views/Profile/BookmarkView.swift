//
//  BookmarkView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 29/09/2025.
//

import SwiftUI

struct BookmarkView: View {
    @Environment(CloudStoreManager.self) private var userDefaults
    @State private var detailedBookmarkedVideos: [Video] = []

    private var bookmarkedVideos: [Video] {
        userDefaults.bookmarkedVideos.reversed()
    }

    var body: some View {
        let displayedVideos = detailedBookmarkedVideos.isEmpty ? bookmarkedVideos : detailedBookmarkedVideos

        Section {
            ForEach(Array(displayedVideos.prefix(3))) { video in
                CompactVideoCard(video: video)
                    #if !os(tvOS)
                    .swipeActions {
                        Button {
                            withAnimation {
                                userDefaults.removeBookmark(video.id)
                            }
                        } label: {
                            Label("Remove", systemImage: "bookmark.slash")
                        }
                    }
                    #endif
            }

            NavigationLink {
                BookmarkFullView()
            } label: {
                Text("View all bookmarked videos")
                    .foregroundStyle(.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
            }
            .navigationLinkIndicatorVisibility(.hidden)
        } header: {
            Text("Bookmarks")
        }
        .task(id: bookmarkedVideos.map(\.id)) {
            await loadBookmarkedVideoDetails(for: bookmarkedVideos)
        }
    }

    private func loadBookmarkedVideoDetails(for videos: [Video]) async {
        guard !videos.isEmpty else {
            detailedBookmarkedVideos = []
            return
        }

        do {
            var mutableVideos = videos
            try await YTService.fetchVideoDetails(for: &mutableVideos)
            detailedBookmarkedVideos = mutableVideos
        } catch {
            detailedBookmarkedVideos = videos
            print("Error updating bookmarked video details: \(error.localizedDescription)")
        }
    }
}

struct BookmarkFullView: View {
    @Environment(CloudStoreManager.self) private var userDefaults
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var detailedVideos: [Video] = []

    private var rawVideos: [Video] { userDefaults.bookmarkedVideos.reversed() }

    private var displayedVideos: [Video] {
        guard !detailedVideos.isEmpty else { return rawVideos }
        let detailed = Dictionary(uniqueKeysWithValues: detailedVideos.map { ($0.id, $0) })
        return rawVideos.map { detailed[$0.id] ?? $0 }
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                VideoGridView(videos: displayedVideos, showsBookmarkIcon: false)
            } else {
                List {
                    ForEach(displayedVideos) { video in
                        CompactVideoCard(video: video)
                            #if !os(tvOS)
                            .swipeActions {
                                Button {
                                    withAnimation {
                                        userDefaults.removeBookmark(video.id)
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
        .navigationTitle("Bookmarks")
        .platformNavigationToolbar(titleDisplayMode: .inline)
        .contentMargins(.top, 5)
        #if !os(tvOS)
        .refreshable {
            CloudStoreManager.shared.refreshFromYouTube()
        }
        #endif
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
    BookmarkView()
        .environment(CloudStoreManager.shared)
}
