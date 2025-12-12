import SwiftUI

struct SearchView: View {
    @State private var searchScope: SearchScope = .video
    @State var searchText: String = ""
    @State private var results: SearchResults = SearchResults(videos: [], channels: [])
    @State private var isLoading = false
    
    var body: some View {
        List {
            if searchScope == .video && !results.videos.isEmpty {
                Section("Videos") {
                    ForEach(results.videos) { video in
                        CompactVideoCard(video: video)
                    }
                }
            } else if searchScope == .channel && !results.channels.isEmpty {
                Section("Channels") {
                    ForEach(results.channels) { channel in
                        ChannelRowView(channel: channel)
                    }
                }
            }
        }
        .toolbar {
            Button {
                results = .init(videos: [], channels: [])
            } label: {
                Label("Clear", systemImage: "eraser")
                    .labelStyle(.titleOnly)
            }
        }
        .navigationTitle("Search")
        .toolbarTitleDisplayMode(.inlineLarge)
        .overlay {
            if isLoading {
                UniversalProgressView()
            } else if results.isEmpty {
                ContentUnavailableView.search
            }
        }
        .searchable(text: $searchText, placement: placement, prompt: "Search videos or channels")
        .searchPresentationToolbarBehavior(.avoidHidingContent)
        .searchScopes($searchScope) {
            ForEach(SearchScope.allCases) { scope in
                Text(scope.rawValue)
                    .tag(scope)
            }
        }
        .onSubmit(of: .search) {
            Task { await performSearch() }
        }
    }
    
    private func performSearch() async {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let allResults = try await YTService.search(query: searchText)
            results = SearchResults(
                videos: allResults.videos,
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
    case video = "Videos"
    case channel = "Channels"
    var id: String { rawValue }
}
