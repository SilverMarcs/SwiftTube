import SwiftUI

struct SearchView: View {
    @Environment(LibraryStore.self) private var library

    @State private var searchScope: SearchScope = .bookmark
    @State var searchText: String = ""
    @State private var onlineVideos: [Video] = []
    @State private var onlineNextPageToken: String?
    @State private var onlineChannels: [Channel] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @FocusState private var isSearchFocused: Bool

    private var availableScopes: [SearchScope] {
        [.bookmark, .history, .channel, .video]
    }

    private func filter(_ videos: [Video]) -> [Video] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return videos }
        return videos.filter { video in
            video.title.localizedCaseInsensitiveContains(query)
                || video.channelTitle.localizedCaseInsensitiveContains(query)
        }
    }

    private var filteredBookmarks: [Video] { filter(library.watchLater) }
    private var filteredHistory: [Video] { filter(library.history) }

    private var displayedChannels: [Channel] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        if !onlineChannels.isEmpty { return onlineChannels }
        guard !query.isEmpty else { return library.subscribedChannels }
        return library.subscribedChannels.filter {
            $0.title.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        Group {
            switch searchScope {
            case .bookmark:
                VideoGridView(videos: filteredBookmarks)
            case .history:
                VideoGridView(videos: filteredHistory)
            case .channel:
                List {
                    ForEach(displayedChannels) { channel in
                        ChannelRowView(channel: channel)
                    }
                }
            case .video:
                if onlineVideos.isEmpty && !isLoading {
                    ContentUnavailableView.search
                } else {
                    VideoGridView(
                        videos: onlineVideos,
                        isGuestAllowed: true,
                        onReachEnd: {
                            Task { await loadMore() }
                        },
                        onRefresh: {
                            await performSearch()
                        }
                    )
                }
            }
        }
        .toolbar {
            if searchScope == .video, !onlineVideos.isEmpty {
                Button {
                    onlineVideos = []
                    onlineNextPageToken = nil
                } label: {
                    Label("Clear", systemImage: "eraser")
                        .labelStyle(.titleOnly)
                }
            }
            if searchScope == .channel, !onlineChannels.isEmpty {
                Button {
                    onlineChannels = []
                } label: {
                    Label("Clear", systemImage: "eraser")
                        .labelStyle(.titleOnly)
                }
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
        .task {
            isSearchFocused = true
        }
        #endif
        .searchScopes($searchScope) {
            ForEach(availableScopes) { scope in
                Text(scope.rawValue)
                    .tag(scope)
            }
        }
        .onChange(of: searchScope) {
            onlineChannels = []
            onlineVideos = []
            onlineNextPageToken = nil
        }
        .onSubmit(of: .search) {
            switch searchScope {
            case .video:    Task { await performSearch() }
            case .channel:  Task { await performChannelSearch() }
            default:        break
            }
        }
    }

    private func performSearch() async {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let group = try await InnerTubeAPI.shared.search(query: searchText)
            self.onlineVideos = group.videos.filter { !isChannelEntry($0) }
            self.onlineNextPageToken = group.nextPageToken
        } catch {
            print("Error in SearchView: \(error.localizedDescription)")
        }
    }

    private func performChannelSearch() async {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        do {
            let channels = try await InnerTubeAPI.shared.searchChannels(query: query)
            self.onlineChannels = channels
        } catch {
            print("SearchView channel search: \(error.localizedDescription)")
        }
    }

    private func loadMore() async {
        guard let token = onlineNextPageToken, !isLoadingMore else { return }
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let group = try await InnerTubeAPI.shared.search(
                query: query,
                continuationToken: token,
                filter: .default
            )
            let existing = Set(onlineVideos.map(\.id))
            let newVideos = group.videos.filter { !isChannelEntry($0) && !existing.contains($0.id) }
            onlineVideos.append(contentsOf: newVideos)
            onlineNextPageToken = group.nextPageToken
        } catch {
            print("SearchView loadMore: \(error.localizedDescription)")
        }
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

enum SearchScope: String, Hashable, CaseIterable, Identifiable {
    case bookmark = "Bookmarks"
    case history = "History"
    case channel = "Channels"
    case video = "Videos"
    var id: String { rawValue }
}
