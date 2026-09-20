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
        .task { await library.refreshHistory() }
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
                await library.refreshHistory()
            }
        )
        .platformTopBar("History") {
            RefreshButton { await library.refreshHistory() }
        }
        .contentMargins(.top, 5)
        .task { await library.refreshHistory() }
        // A shorts-heavy first page can leave the vertical list empty. Keep paging
        // until non-Shorts surface (or the stream ends) so the grid fills too.
        .task(id: library.history.count) {
            if !library.history.contains(where: { !$0.isShort }) && library.canLoadMoreHistory {
                await LibraryStore.shared.loadMoreHistory()
            }
        }
    }
}
