import SwiftUI

struct VideoGridView: View {    
    let videos: [Video]
    var showChannelLinkInContextMenu: Bool = true

    private let gridColumns: [GridItem] = [
        GridItem(.adaptive(minimum: 280, maximum: 420), spacing: 16, alignment: .top)
    ]
    
    var body: some View {
        Group {
#if os(macOS)
            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: 16) {
                    ForEach(videos) { video in
                        VideoCard(video: video, showChannelLink: showChannelLinkInContextMenu)
                    }
                }
                .padding(16)
            }
#else
            List(videos) { video in
                VideoCard(video: video, showChannelLink: showChannelLinkInContextMenu)
                    .listRowSeparator(.hidden)
                    .listRowInsets(.vertical, 5)
                    .listRowInsets(.horizontal, 10)
            }
            .listStyle(.plain)
#endif
        }
        .overlay {
            if videos.isEmpty {
                UniversalProgressView()
            }
        }
    }
}
