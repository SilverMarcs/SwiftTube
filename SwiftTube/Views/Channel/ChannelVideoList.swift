import SwiftUI
import SwiftData

struct ChannelVideoList: View {
    let channel: Channel
    @Environment(\.modelContext) private var modelContext
    @State private var videos: [Video] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingDetails = false
    
    private var isSavedChannel: Bool {
        let channelId = channel.id
        var descriptor = FetchDescriptor<Channel>(predicate: #Predicate { $0.id == channelId })
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor).first) != nil
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
                ToolbarItem(placement: .title) {
                    Button {
                        showingDetails = true
                    } label: {
                        ChannelRowView(channel: channel)
                            .allowsHitTesting(false)
                    }
                    .frame(maxWidth: 40)
                }
                
                ToolbarItem(placement: .destructiveAction) {
                    if isSavedChannel {
                        Button(role: .confirm) {
                            let channelId = channel.id
                            var descriptor = FetchDescriptor<Channel>(predicate: #Predicate { $0.id == channelId })
                            descriptor.fetchLimit = 1
                            if let channel = try? modelContext.fetch(descriptor).first {
                                modelContext.delete(channel)
                                try? modelContext.save()
                            }
                        } label: {
                            Label("Remove Channel", systemImage: "minus")
                        }
                    } else {
                        Button(role: .confirm) {
                            let newChannel = Channel(
                                id: channel.id,
                                title: channel.title,
                                channelDescription: channel.channelDescription,
                                thumbnailURL: channel.thumbnailURL
                            )
                            modelContext.insert(newChannel)
                            try? modelContext.save()
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
