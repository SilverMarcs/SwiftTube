import SwiftUI
import SwiftMediaViewer
import AVKit

struct VideoDetailView: View {
    @Environment(CloudStoreManager.self) private var userDefaults
    @Environment(VideoManager.self) var manager
    @Environment(\.colorScheme) var colorScheme
    
    let video: Video
    @State var showDetail: Bool = false
    
    var showVideo: Bool = false
    
    var body: some View {
        NavigationStack {
            List {
                #if os(iOS) || os(visionOS)
                Section(video.title) {
                    // Video Stats (Views, Likes, Published)
                    HStack(spacing: 5) {
                        if let viewCount = video.viewCountValue {
                            Text("\(viewCount, format: .number.notation(.compactName)) views")
                        }

                        Text("•")

                        Text(video.publishedAt, style: .date)

                        Spacer()

                        if let likeCount = video.likeCountValue {
                            Text("\(likeCount, format: .number.notation(.compactName)) likes")
                        }

                        menu
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .listRowSeparator(.hidden, edges: .bottom)
                    .listRowInsets([.vertical], 0)
                }
                .headerProminence(.increased)
                .listRowBackground(Color.clear)
                .listSectionMargins(.all, 0)
                #endif
                
                // Channel Info
                Section {
                    ChannelRowView(channel: video.channel)
                    #if os(macOS)
                        .padding(8)
                        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 15))
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                    #endif
                }
                #if os(iOS) || os(visionOS)
                .listSectionMargins(.top, 0)
                #endif

                // Description
                if !video.videoDescription.isEmpty {

                Section("Description") {
                    ExpandableText(text: video.videoDescription, maxCharacters: 200)
                        .font(.subheadline)
                        #if os(macOS)
                        .listRowSeparator(.hidden, edges: .bottom)
                        #endif
                    }
                }
                 
                // Comments Section
                VideoCommentsView(video: video)
            }
            #if os(iOS) || os(visionOS)
            .statusBar(hidden: false)
            .safeAreaBar(edge: .top) {
                if showVideo {
                    AVPlayerViewIos()
                        .background(.bar)
                }
            }
            #endif
        }
    }
    
    var menu: some View {
        Menu {
            #if !os(tvOS)
            ShareLink(item: URL(string: video.url)!) {
                Label("Share Video", systemImage: "square.and.arrow.up")
            }
            .tint(.primary)
            #endif

            Button {
                userDefaults.toggleBookmark(video)
            } label: {
                Label(
                    userDefaults.isBookmarked(video.id) ? "Remove Bookmark" : "Add Bookmark",
                    systemImage: userDefaults.isBookmarked(video.id) ? "bookmark.fill" : "bookmark"
                )
            }
            .tint(.primary)

            #if os(iOS)
            Divider()

            DownloadMenuButton(video: video)
                .tint(.primary)
            #endif
        } label: {
            Image(systemName: "ellipsis")
                .padding(10)
        }
        .glassEffect()
    }
}
