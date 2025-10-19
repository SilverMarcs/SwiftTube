import SwiftUI
import SwiftMediaViewer
import AVKit
import YouTubeKit

struct VideoDetailView: View {
    @Environment(UserDefaultsManager.self) private var userDefaults
    @Environment(VideoManager.self) var manager
    @Environment(\.colorScheme) var colorScheme
    
    @State var video: Video
    @State var showDetail: Bool = false
    
    var body: some View {
        List {
            Section(video.title) {
                // Video Stats (Views, Likes, Published)
                HStack(spacing: 5) {
                    Label(video.viewCount.formatNumber(), systemImage: "eye")
                        .labelIconToTitleSpacing(3)
                    
                    Text("•")
                    
                    Text(video.publishedAt, style: .date)
                    
                    Spacer()
                    
                    if let likesText = video.likeCount?.formatNumber() {
                        Label(likesText, systemImage: "hand.thumbsup")
                            .labelIconToTitleSpacing(3)
                    }
                }
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
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
            #if !os(macOS)
            .listSectionMargins(.top, 0)
            #endif
            
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
        #if !os(macOS)
        .statusBar(hidden: false)
        #endif
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
            .menuIndicator(.hidden)
            .padding()
            .ignoresSafeArea()
        }
        .formStyle(.grouped)
    }
}
