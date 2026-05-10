
import SwiftUI
import SwiftMediaViewer

struct ChannelRowView: View {
    let channel: Channel

    var body: some View {
        NavigationLink(destination: ChannelVideoList(channel: channel)) {
            HStack(spacing: 14) {
                CachedAsyncImage(url:  URL(string: channel.thumbnailURL), targetSize: 100)
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
                        if channel.subscriberCount == 0 {
                            Text(channel.channelDescription)
                        } else {
                            Text("\(channel.subscriberCount, format: .number.notation(.compactName)) subscribers")
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
