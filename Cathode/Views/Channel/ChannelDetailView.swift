import SwiftUI

struct ChannelDetailView: View {
    let channel: Channel
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Channel thumbnail
                    AsyncImage(url: URL(string: channel.thumbnailURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray.opacity(0.3)
                    }
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Channel title
                    Text(channel.title)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    // Subscriber count if available
                    if channel.subscriberCount > 0 {
                        Text("\(Int(channel.subscriberCount).formatted()) subscribers")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Channel description
                    if !channel.channelDescription.isEmpty {
                        Text(LocalizedStringKey(channel.channelDescription))
                            .font(.body)
                            .foregroundStyle(.primary)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Channel Details")
            .toolbarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    let channel = Channel(
        id: "UCBJycsmduvYEL83R_U4JriQ",
        title: "Marques Brownlee",
        channelDescription: "Technology reviews and discussions covering the latest gadgets, smartphones, and consumer electronics.",
        thumbnailURL: "https://example.com/thumbnail.jpg",
        subscriberCount: 15000000
    )
    
    ChannelDetailView(channel: channel)
}
