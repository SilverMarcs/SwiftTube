import SwiftUI

struct SearchView: View {
    @AppStorage("showGoogleAuth") private var showGoogleAuth = false
    @Environment(CloudStoreManager.self) private var userDefaults

    @State private var searchScope: SearchScope = .bookmark
    @State var searchText: String = ""
    @State private var onlineResults: SearchResults = SearchResults(videos: [], channels: [])
    @State private var isLoading = false
    @FocusState private var isSearchFocused: Bool

    private var availableScopes: [SearchScope] {
        var scopes: [SearchScope] = [.bookmark, .history]
        if showGoogleAuth {
            scopes.append(.video)
            scopes.append(.channel)
        }
        return scopes
    }

    private func filter(_ videos: [Video]) -> [Video] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return videos }
        return videos.filter { video in
            video.title.localizedCaseInsensitiveContains(query)
                || video.channel.title.localizedCaseInsensitiveContains(query)
        }
    }

    private var filteredBookmarks: [Video] { filter(Array(userDefaults.bookmarkedVideos.reversed())) }
    private var filteredHistory: [Video] { filter(userDefaults.historyVideos) }

    var body: some View {
        Group {
            switch searchScope {
            case .bookmark:
                VideoGridView(videos: filteredBookmarks)
            case .history:
                VideoGridView(videos: filteredHistory)
            case .video:
                List {
                    if !onlineResults.videos.isEmpty {
                        Section("Videos") {
                            ForEach(onlineResults.videos) { video in
                                CompactVideoCard(video: video)
                            }
                        }
                    }
                }
            case .channel:
                List {
                    if !onlineResults.channels.isEmpty {
                        Section("Channels") {
                            ForEach(onlineResults.channels) { channel in
                                ChannelRowView(channel: channel)
                            }
                        }
                    }
                }
            }
        }
        .toolbar {
            if isOnlineScope {
                Button {
                    onlineResults = .init(videos: [], channels: [])
                } label: {
                    Label("Clear", systemImage: "eraser")
                        .labelStyle(.titleOnly)
                }
            }
        }
        .navigationTitle("Search")
        .platformNavigationToolbar()
        .overlay {
            if isLoading {
                UniversalProgressView()
            } else if isOnlineScope, onlineResults.isEmpty {
                ContentUnavailableView.search
            }
        }
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
        .onChange(of: showGoogleAuth) { _, newValue in
            if !newValue, isOnlineScope {
                searchScope = .bookmark
            }
        }
        .onSubmit(of: .search) {
            guard isOnlineScope else { return }
            Task { await performSearch() }
        }
    }

    private var isOnlineScope: Bool {
        searchScope == .video || searchScope == .channel
    }

    private func performSearch() async {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let allResults = try await YTService.search(query: searchText)
            var videosWithDetails = allResults.videos
            if !videosWithDetails.isEmpty {
                try await YTService.fetchVideoDetails(for: &videosWithDetails)
            }
            onlineResults = SearchResults(
                videos: videosWithDetails,
                channels: allResults.channels
            )
        } catch {
            print("Error in SearchView: \(error.localizedDescription)")
        }
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
    case video = "Videos"
    case channel = "Channels"
    var id: String { rawValue }
}
