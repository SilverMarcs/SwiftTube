import SwiftUI
import SwiftMediaViewer

struct ChannelRowView: View {
    let channel: Channel

    var body: some View {
        NavigationLink(destination: ChannelVideoList(channelId: channel.id, title: channel.title)) {
            HStack(spacing: 14) {
                CachedAsyncImage(url: channel.thumbnailURL, targetSize: 100)
                    #if os(tvOS)
                    .frame(width: 70, height: 70)
                    #else
                    .frame(width: 40, height: 40)
                    #endif
                    .clipShape(.circle)

                VStack(alignment: .leading) {
                    Text(channel.title)
                        #if os(tvOS)
                        .font(.subheadline.weight(.semibold))
                        #else
                        .font(.headline)
                        #endif

                    Group {
                        if let subs = channel.subscriberCount, !subs.isEmpty {
                            Text(subs)
                        } else if let desc = channel.description, !desc.isEmpty {
                            Text(desc)
                        }
                    }
                    #if os(tvOS)
                    .font(.caption)
                    #else
                    .font(.subheadline)
                    #endif
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
                Spacer()
            }
        }
    }
}
