import SwiftUI

struct ChannelVideoList: View {
    let channel: Channel
    @Environment(UserDefaultsManager.self) private var userDefaults
    @State private var videos: [Video] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingDetails = false
    
    private var isSavedChannel: Bool {
        userDefaults.savedChannels.contains { $0.id == channel.id }
    }
    
    var body: some View {
        NavigationStack {
            List(videos) { video in
                VideoCard(video: video)
                    .listRowSeparator(.hidden)
                    .listRowInsets(.vertical, 7)
                    .listRowInsets(.horizontal, 10)
            }
            .listStyle(.plain)
            .overlay {
                if isLoading {
                    UniversalProgressView()
                }
            }
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Button {
                        showingDetails = true
                    } label: {
                        ChannelRowView(channel: channel)
                            .allowsHitTesting(false)
                            .contentShape(.rect)
                    }
                    .frame(maxWidth: 40)
                }
                .sharedBackgroundVisibility(.visible)
                
                ToolbarItem(placement: .destructiveAction) {
                    if isSavedChannel {
                        Button(role: .confirm) {
                            userDefaults.removeChannel(channel)
                        } label: {
                            Label("Remove Channel", systemImage: "minus")
                        }
                    } else {
                        Button(role: .confirm) {
                            userDefaults.addChannel(channel)
                        } label: {
                            Label("Add Channel", systemImage: "plus")
                        }
                    }
                }
            }
            .task {
                if videos.isEmpty {
                    await loadChannelVideos()
                }
            }
            .refreshable {
                await loadChannelVideos()
            }
        }
        .sheet(isPresented: $showingDetails) {
            ChannelDetailView(channel: channel)
        }
    }
    
    private func loadChannelVideos() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let rssData = try await FeedParser.fetchChannelVideosFromRSS(channelId: channel.id)
            videos = rssData.map { data in
                Video(
                    id: data.id,
                    title: data.title,
                    videoDescription: data.videoDescription,
                    thumbnailURL: data.thumbnailURL,
                    publishedAt: data.publishedAt,
                    url: data.url,
                    channel: channel,
                    viewCount: data.viewCount,
                    isShort: data.isShort
                )
            }
        } catch {
            print(error.localizedDescription)
        }
    }
}

#Preview {
    let channel = Channel(
        id: "UCBJycsmduvYEL83R_U4JriQ",
        title: "Marques Brownlee",
        channelDescription: "Technology reviews and discussions",
        thumbnailURL: "https://example.com/thumbnail.jpg"
    )
    
    ChannelVideoList(channel: channel)
}
