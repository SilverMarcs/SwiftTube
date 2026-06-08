import SwiftUI

struct SearchView: View {
    @Environment(LibraryStore.self) private var library

    @State private var searchScope: SearchScope = .video
    @State var searchText: String = ""

    @State private var displayedVideos: [Video] = []
    @State private var displayedChannels: [Channel] = []
    @State private var displayedBookmarks: [Video] = []
    @State private var displayedHistory: [Video] = []
    @State private var nextPageToken: String?

    @State private var isLoading = false
    @State private var isLoadingMore = false
    @FocusState private var isSearchFocused: Bool

    private var availableScopes: [SearchScope] { [.video, .channel, .bookmark, .history] }

    // Combined ID — changing either text or scope cancels and restarts the task.
    private var searchQuery: SearchQuery {
        SearchQuery(text: searchText, scope: searchScope)
    }

    private var query: String { searchText.trimmingCharacters(in: .whitespaces) }

    private var currentResultsEmpty: Bool {
        switch searchScope {
        case .video:    return displayedVideos.isEmpty
        case .channel:  return displayedChannels.isEmpty
        case .bookmark: return displayedBookmarks.isEmpty
        case .history:  return displayedHistory.isEmpty
        }
    }

    private func clearResults() {
        displayedVideos = []
        displayedChannels = []
        displayedBookmarks = []
        displayedHistory = []
        nextPageToken = nil
    }

    // MARK: - Body

    var body: some View {
        Group {
            switch searchScope {
            case .video:    videoContent
            case .channel:  channelContent
            case .bookmark: bookmarkContent
            case .history:  historyContent
            }
        }
        .navigationTitle("Search")
        .platformNavigationToolbar()
        .searchable(text: $searchText, placement: placement, prompt: "Search…")
        #if !os(tvOS)
        .searchFocused($isSearchFocused)
        #endif
        .searchPresentationToolbarBehavior(.avoidHidingContent)
        #if os(macOS)
        .task { isSearchFocused = true }
        #endif
        .searchScopes($searchScope) {
            ForEach(availableScopes) { scope in
                Text(scope.rawValue).tag(scope)
            }
        }
        .task(id: searchQuery) {
            clearResults()
            guard !query.isEmpty else { return }
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            await performSearch()
        }
    }

    // MARK: - Scope Content Views

    private var videoContent: some View {
        scopeContent(results: displayedVideos) {
            VideoGridView(
                videos: displayedVideos,
                isGuestAllowed: true,
                onReachEnd: { Task { await loadMore() } },
                onRefresh: { await performSearch() }
            )
        }
    }

    private var channelContent: some View {
        scopeContent(results: displayedChannels) {
            List {
                ForEach(displayedChannels) { channel in
                    ChannelRowView(channel: channel)
                }
            }
        }
    }

    private var bookmarkContent: some View {
        scopeContent(results: displayedBookmarks) {
            VideoGridView(videos: displayedBookmarks)
        }
    }

    private var historyContent: some View {
        scopeContent(results: displayedHistory) {
            VideoGridView(videos: displayedHistory)
        }
    }

    @ViewBuilder
    private func scopeContent<Results, Content: View>(
        results: [Results],
        @ViewBuilder content: () -> Content
    ) -> some View {
        if isLoading {
            UniversalProgressView()
        } else if results.isEmpty {
            if query.isEmpty {
                ContentUnavailableView(
                    "Search \(searchScope.rawValue)",
                    systemImage: "magnifyingglass",
                    description: Text("Type to search \(searchScope.rawValue.lowercased()).")
                )
            } else {
                ContentUnavailableView.search(text: query)
            }
        } else {
            content()
        }
    }

    // MARK: - Data Fetching

    private func performSearch() async {
        guard !query.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        switch searchScope {
        case .video:
            do {
                let group = try await InnerTubeAPI.shared.search(query: query)
                displayedVideos = group.videos.filter { !isChannelEntry($0) }
                nextPageToken = group.nextPageToken
            } catch {
                print("SearchView video: \(error.localizedDescription)")
            }
        case .channel:
            do {
                displayedChannels = try await InnerTubeAPI.shared.searchChannels(query: query)
            } catch {
                print("SearchView channel: \(error.localizedDescription)")
            }
        case .bookmark:
            displayedBookmarks = library.watchLater.filter { matchesQuery($0) }
        case .history:
            displayedHistory = library.history.filter { matchesQuery($0) }
        }
    }

    private func loadMore() async {
        guard let token = nextPageToken, !isLoadingMore, !query.isEmpty else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let group = try await InnerTubeAPI.shared.search(
                query: query,
                continuationToken: token,
                filter: .default
            )
            let existing = Set(displayedVideos.map(\.id))
            let newVideos = group.videos.filter { !isChannelEntry($0) && !existing.contains($0.id) }
            displayedVideos.append(contentsOf: newVideos)
            nextPageToken = group.nextPageToken
        } catch {
            print("SearchView loadMore: \(error.localizedDescription)")
        }
    }

    private func matchesQuery(_ video: Video) -> Bool {
        video.title.localizedStandardContains(query)
            || video.channelTitle.localizedStandardContains(query)
    }

    private func isChannelEntry(_ v: Video) -> Bool {
        v.id.hasPrefix("UC") && v.id.count > 11 && v.duration == nil
    }

    private var placement: SearchFieldPlacement {
        #if os(tvOS)
        .automatic
        #else
        .toolbarPrincipal
        #endif
    }
}

// MARK: - Supporting Types

private struct SearchQuery: Equatable, Hashable {
    let text: String
    let scope: SearchScope
}

enum SearchScope: String, Hashable, CaseIterable, Identifiable {
    case video    = "Videos"
    case channel  = "Channels"
    case bookmark = "Bookmarks"
    case history  = "History"
    var id: String { rawValue }
}
