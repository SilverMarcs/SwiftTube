import SwiftUI
import SwiftMediaViewer
import AVKit
import YouTubeKit

struct VideoDetailView: View {
    @Environment(UserDefaultsManager.self) private var userDefaults
    @Environment(NativeVideoManager.self) var manager
    @Environment(\.colorScheme) var colorScheme
    
    @State var video: Video
    @State var showDetail: Bool = false
    
    var showVideo: Bool = false
    
    var body: some View {
        NavigationStack {
            List {
                Section(video.title) {
                    // Video Stats (Views, Likes, Published)
                    HStack(spacing: 5) {
                        Label(video.viewCount.formatNumber(), systemImage: "eye")
                            .labelIconToTitleSpacing(3)
                            .font(.system(size: 11))
                        
                        Text("•")
                        Text(video.publishedAt, style: .date)
                        
                        Spacer()
                        
                        if let likesText = video.likeCount?.formatNumber() {
                            Label(likesText, systemImage: "hand.thumbsup.fill")
                                .labelIconToTitleSpacing(3)
                                .font(.system(size: 11))
                        }
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
//                    .listRowSeparator(.hidden)
                    .listRowSeparator(.hidden, edges: .bottom)
                    .listRowInsets([.vertical], 0)
                }
                .headerProminence(.increased)
                .listRowBackground(Color.clear)
                #if !os(macOS)
                .listSectionMargins(.all, 0)
                #endif
                
                // Channel Info
                Section {
                    ChannelRowView(channel: video.channel)
                }
                .listSectionMargins(.top, 0)
                
                // Description
                if !video.videoDescription.isEmpty {

                Section("Description") {
                    ExpandableText(text: video.videoDescription, maxCharacters: 200)
                        .font(.subheadline)
                    }
                }
                 
                // Comments Section
                Section("Comments") {
                    VideoCommentsView(video: video)
                }
            }
           // Explicitly show the status bar
            .overlay(alignment: .bottomTrailing) {
                Menu {
                    ShareLink(item: URL(string: video.url)!) {
                        Label("Share Video", systemImage: "square.and.arrow.up")
                    }
                    .tint(.primary)
                    
                    Button {
                        userDefaults.toggleWatchLater(video.id)
                    } label: {
                        Label(
                            userDefaults.isWatchLater(video.id) ? "Remove from Watch Later" : "Add to Watch Later",
                            systemImage: userDefaults.isWatchLater(video.id) ? "bookmark.fill" : "bookmark"
                        )
                    }
                    .tint(.primary)
                } label: {
                    Image(systemName: "shippingbox.fill")
                }
                .tint(Color.accentColor.secondary)
                .menuStyle(.button)
                .controlSize(.extraLarge)
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .padding()
                .ignoresSafeArea()
            }
            #if !os(macOS)
            .statusBar(hidden: false)
            .safeAreaBar(edge: .top) {
                if showVideo {
                    NativeVideoPlayerView()
                }
            }
            #endif
            .formStyle(.grouped)
        }
    }
}
