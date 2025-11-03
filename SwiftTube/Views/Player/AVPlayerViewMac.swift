import SwiftUI
import AVKit

struct AVPlayerViewMac: View {
    // TODO: pass vdieo dirtvy to it rathe rthan videomanager.
    @Environment(VideoManager.self) var videoManager
    @Environment(CloudStoreManager.self) private var userDefaults
    
    @State private var showDetail = false
    
    var body: some View {
        Group {
            if videoManager.isSetting {
                UniversalProgressView()
                    .background(.black)
            } else if let player = videoManager.player {
                AVPlayerMac(player: player)
                    .task(id: player.timeControlStatus) {
                        videoManager.persistCurrentTime()
                    }
                    .onDisappear {
                        videoManager.persistCurrentTime()
                        videoManager.player?.pause()
                    }
            }
        }
        .ignoresSafeArea()
        .windowFullScreenBehavior(.disabled)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .gesture(WindowDragGesture())
        .navigationTitle(videoManager.currentVideo?.title ?? "Loading")
        .navigationSubtitle(videoManager.currentVideo?.channel.title ?? "Channel")
        .preferredColorScheme(.dark)
        .inspector(isPresented: $showDetail) {
            if let video = videoManager.currentVideo {
                VideoDetailView(video: video)
                    .id(video.id)
                    .toolbar {
                        ToolbarItemGroup(placement: .primaryAction) {
                            if let video = videoManager.currentVideo {
                                ShareLink(item: URL(string: video.url)!) {
                                    Label("Share Video", systemImage: "square.and.arrow.up")
                                }
                                
                                Button {
                                    userDefaults.toggleWatchLater(video.id)
                                } label: {
                                    Label(
                                        userDefaults.isWatchLater(video.id) ? "Remove from Watch Later" : "Add to Watch Later",
                                        systemImage: userDefaults.isWatchLater(video.id) ? "bookmark.fill" : "bookmark"
                                    )
                                }
                            }
                        }
                        
                        ToolbarSpacer()
                        
                        ToolbarItem {
                            Button {
                                showDetail.toggle()
                            } label: {
                                Image(systemName: "info")
                            }
                        }
                    }
            }
        }
        .onAppear {
            if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "media-player" }) {
                window.aspectRatio = NSSize(width: 16, height: 9)
                window.setContentSize(NSSize(width: 1024, height: 576))
            }
        }
    }
}
