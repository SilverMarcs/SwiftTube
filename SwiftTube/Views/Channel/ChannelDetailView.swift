import SwiftUI
import SwiftData

struct ChannelDetailView: View {
    let channelItem: ChannelDisplayable
    @Environment(\.modelContext) private var modelContext
    @State private var videos: [Video] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    private var isSavedChannel: Bool {
        let channelId = channelItem.id
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
            .navigationTitle(channelItem.title)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .destructiveAction) {
                    if isSavedChannel {
                        Button(role: .confirm) {
                            let channelId = channelItem.id
                            var descriptor = FetchDescriptor<Channel>(predicate: #Predicate { $0.id == channelId })
                            descriptor.fetchLimit = 1
                            if let channel = try? modelContext.fetch(descriptor).first {
                                modelContext.delete(channel)
                                try? modelContext.save()
                            }
                        } label: {
                            Label("Remove Channel", systemImage: "minus")
                        }
//                        .tint(.red)
                    } else {
                        Button(role: .confirm) {
                            let channel = Channel(
                                id: channelItem.id,
                                title: channelItem.title,
                                channelDescription: channelItem is Subscription ? (channelItem as! Subscription).description : "",
                                thumbnailURL: channelItem.thumbnailURL
                            )
                            modelContext.insert(channel)
                            try? modelContext.save()
                        } label: {
                            Label("Add Channel", systemImage: "plus")
                        }
//                        .tint(.red)
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
    }
    
    private func loadChannelVideos() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            videos = try await FeedParser.fetchChannelVideosFromRSS(channelId: channelItem.id, maxResults: 20)
        } catch {
            print(error.localizedDescription)
        }
    }
}

#Preview {
    let subscription = Subscription(
        id: "UCBJycsmduvYEL83R_U4JriQ",
        title: "Marques Brownlee",
        description: "Technology reviews and discussions",
        thumbnailURL: "https://example.com/thumbnail.jpg"
    )
    
    ChannelDetailView(channelItem: subscription)
}
