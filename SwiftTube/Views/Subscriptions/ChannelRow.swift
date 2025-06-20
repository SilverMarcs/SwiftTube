import SwiftUI

struct ChannelRow: View {
    let channel: Channel
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: channel.thumbnailURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Circle()
                    .fill(.quaternary)
                    .overlay {
                        Image(systemName: "person.circle")
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(channel.name)
                    .font(.headline)
                    .lineLimit(1)
                
                if let subscribersText = channel.subscribersText {
                    Text(subscribersText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Button("Subscribed") {
                // Implementation for unsubscribe
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.vertical, 8)
    }
}
