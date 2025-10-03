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
            VideoGridView(videos: videos, showChannelLinkInContextMenu: false)
            .navigationTitle(channel.title)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
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
            .refreshable {
                await loadChannelVideos()
            }
            .task {
                if videos.isEmpty {
                    await loadChannelVideos()
                }
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
            videos = try await FeedParser.fetchChannelVideosFromRSS(channel: channel)
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
