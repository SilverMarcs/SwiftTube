//
//  HistoryView.swift
//
//  Created by Zabir Raihan on 29/09/2025.
//

import SwiftUI

struct HistoryView: View {
    @Environment(LibraryStore.self) private var library

    var body: some View {
        Section {
            ForEach(Array(library.history.prefix(3))) { video in
                CompactVideoCard(video: video)
            }

            NavigationLink {
                HistoryFullView()
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
    }
}

struct HistoryFullView: View {
    @Environment(LibraryStore.self) private var library

    /// History is a single mixed stream from YouTube. We split it into a Shorts
    /// rail up top and a vertical list of everything else. Both are views of the
    /// same `history` array, so vertical scroll-to-end paging fills both.
    private var shorts: [Video] { library.history.filter(\.isShort) }
    private var videos: [Video] { library.history.filter { !$0.isShort } }

    var body: some View {
        VideoGridView(
            videos: videos,
            onReachEnd: {
                Task { await LibraryStore.shared.loadMoreHistory() }
            },
            onRefresh: {
                await LibraryStore.shared.refresh()
            }
        ) {
            #if !os(tvOS)
            if !shorts.isEmpty {
                ShortsRail(shorts: shorts, onReachEnd: {
                    Task { await LibraryStore.shared.loadMoreHistory() }
                })
            }
            #endif
        }
        .platformTopBar("History") {
            RefreshButton { await LibraryStore.shared.refresh() }
        }
        .contentMargins(.top, 5)
        // History is already refreshed at app launch. Only fetch on appear if it
        // hasn't loaded yet — re-fetching replaces the array and flashes the list.
        // Pull-to-refresh and the toolbar button still force a full refresh.
        .task {
            if library.history.isEmpty { await LibraryStore.shared.refresh() }
        }
        // A shorts-heavy first page can leave the video list empty. Keep paging
        // until real videos surface (or the stream ends) so both lists fill.
        .task(id: library.history.count) {
            if videos.isEmpty && library.canLoadMoreHistory {
                await LibraryStore.shared.loadMoreHistory()
            }
        }
    }
}

/// Horizontal rail of Shorts shown atop the History list. Reaching the last card
/// pages the underlying history stream (best-effort — a page may add no Shorts).
private struct ShortsRail: View {
    let shorts: [Video]
    let onReachEnd: () -> Void

    var body: some View {
        HorizontalShelf(spacing: 12) {
            ForEach(shorts) { video in
                ShortRailCard(video: video)
                    .task {
                        if video.id == shorts.last?.id { onReachEnd() }
                    }
            }
        }
        .padding(.bottom, 20)
    }
}
