//
//  BookmarkView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 29/09/2025.
//

import SwiftUI

struct BookmarkView: View {
    @Environment(LibraryStore.self) private var library

    var body: some View {
        Section {
            ForEach(Array(library.watchLater.prefix(3))) { video in
                CompactVideoCard(video: video)
                    #if !os(tvOS)
                    .swipeActions {
                        Button {
                            withAnimation {
                                library.removeBookmark(video.id)
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
    }
}

struct BookmarkFullView: View {
    @Environment(LibraryStore.self) private var library

    private var videos: [Video] { library.watchLater }

    var body: some View {
        VideoGridView(
            videos: videos,
            showsBookmarkIcon: false,
            onReachEnd: {
                Task { await LibraryStore.shared.loadMoreWatchLater() }
            },
            onRefresh: {
                await LibraryStore.shared.refresh()
            }
        )
        .platformTopBar("Bookmarks") {
            RefreshButton { await LibraryStore.shared.refresh() }
        }
        .contentMargins(.top, 5)
        .task { await LibraryStore.shared.refresh() }
    }
}
