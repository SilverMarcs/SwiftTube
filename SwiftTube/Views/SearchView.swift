import SwiftUI

struct SearchView: View {
    @State private var searchText: String = ""
    @State private var searchScope: SearchScope = .video
    
    @State private var results: SearchResults = SearchResults(videos: [], channels: [])
    @State private var isLoading = false
    
    enum SearchScope: String, Hashable, CaseIterable {
        case video = "Videos"
        case channel = "Channels"
    }
    
    var body: some View {
        NavigationStack {
            List {
                if searchScope == .video {
                    Section("Videos") {
                        ForEach(results.videos) { video in
                            CompactVideoCard(video: video)
                        }
                    }
                } else if searchScope == .channel {
                    Section("Channels") {
                        ForEach(results.channels) { channel in
                            ChannelRowView(channel: channel)
                        }
                    }
                }
            }
            .navigationTitle("Search")
            .toolbarTitleDisplayMode(.inlineLarge)
            .overlay {
                if isLoading {
                    UniversalProgressView()
                }
            }
            #if os(macOS)
            .searchable(text: $searchText, placement: .toolbarPrincipal, prompt: "Search videos or channels")
            #else
            .searchable(text: $searchText, prompt: "Search videos or channels")
            #endif
            .searchScopes($searchScope) {
                Text(SearchScope.video.rawValue).tag(SearchScope.video)
                Text(SearchScope.channel.rawValue).tag(SearchScope.channel)
            }
            .onSubmit(of: .search) {
                Task {
                    await performSearch()
                }
            }
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
}
