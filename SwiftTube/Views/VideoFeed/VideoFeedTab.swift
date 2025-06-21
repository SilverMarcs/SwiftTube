import SwiftUI

enum FeedType: String, CaseIterable {
    case regular = "Videos"
    case shorts = "Shorts"
}

struct VideoFeedTab: View {
    @State private var videos: [Video] = []
    @State private var isLoading = false
    @State private var showSettings = false
    @State private var selectedFeedType: FeedType = .regular
    
    var body: some View {
        NavigationStack {
            Group {
                if selectedFeedType == .regular {
                    regularVideosView
                } else {
                    shortsView
                }
            }
            .toolbar {
                ToolbarItem(placement: .title) {
                    Picker("Feed Type", selection: $selectedFeedType) {
                        ForEach(FeedType.allCases, id: \.self) { type in
                            Text(type.rawValue)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .controlSize(.large)
                    .frame(width: 200)
                }
            }
            .settingsToolbar(showSettings: $showSettings)
            .navigationDestinations()
//            .navigationTitle("Feed")
//            .toolbarTitleDisplayMode(.inlineLarge)
            .task {
                await loadFeed()
            }
            .refreshable {
                await loadFeed()
            }
        }
        .navigationLinkIndicatorVisibility(.hidden)
    }
    
    private var filteredVideos: [Video] {
        switch selectedFeedType {
        case .regular:
            return videos.filter { !$0.isShort }
        case .shorts:
            return videos.filter { $0.isShort }
        }
    }
    
    private var regularVideosView: some View {
        List {
            ForEach(filteredVideos) { video in
                VideoRow(video: video)
                    .listRowInsets(.vertical, 7)
                    .listRowInsets(.horizontal, 10)
                    .listRowSeparator(.hidden)
            }
            
            if isLoading {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
    }
    
    private var shortsView: some View {
        Group {
            if filteredVideos.isEmpty && !isLoading {
                ContentUnavailableView(
                    "No Shorts Available",
                    systemImage: "video.slash",
                    description: Text("There are no shorts in your feed right now.")
                )
            } else if !filteredVideos.isEmpty {
                ShortsView(videos: filteredVideos)
            } else if isLoading {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private func loadFeed() async {
        guard !isLoading && videos.isEmpty else { return }
        
        isLoading = true
        let feedVideos = await PipedAPI.shared.fetchSubscribedFeed()
        videos = feedVideos
        isLoading = false
    }
}
