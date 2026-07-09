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

    var body: some View {
        // History is a single mixed stream; `VideoGridView` pulls Shorts into a
        // rail on top and lists everything else. Both page the same `history`
        // array via `onReachEnd`.
        VideoGridView(
            videos: library.history,
            onReachEnd: {
                Task { await LibraryStore.shared.loadMoreHistory() }
            },
            onRefresh: {
                await LibraryStore.shared.refresh()
            }
        )
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
        // A shorts-heavy first page can leave the vertical list empty. Keep paging
        // until non-Shorts surface (or the stream ends) so the grid fills too.
        .task(id: library.history.count) {
            if !library.history.contains(where: { !$0.isShort }) && library.canLoadMoreHistory {
                await LibraryStore.shared.loadMoreHistory()
            }
        }
    }
}
