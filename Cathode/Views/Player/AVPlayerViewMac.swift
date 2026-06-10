import SwiftUI
import AVKit
import YouTubePlayerKit

struct AVPlayerViewMac: View {
    // TODO: pass vdieo dirtvy to it rathe rthan videomanager.
    @Environment(VideoManager.self) var videoManager
    @Environment(LibraryStore.self) private var userDefaults
    @Environment(VideoLoader.self) private var videoLoader

    @State private var showDetail = false

    var body: some View {
        Group {
            if let iframe = videoManager.iframePlayer {
                YouTubePlayerView(iframe) { state in
                    switch state {
                    case .idle:
                        UniversalProgressView()
                    case .ready:
                        EmptyView()
                    case .error(let error):
                        ContentUnavailableView(
                            "Playback Error",
                            systemImage: "exclamationmark.triangle.fill",
                            description: Text(error.localizedDescription)
                        )
                    }
                }
                .id(videoManager.currentVideo?.id ?? "iframe")
            } else if videoManager.isSetting {
                UniversalProgressView()
                    .background(.black)
            } else if let error = videoManager.playbackError {
                ContentUnavailableView {
                    Label("Can't Play This Video", systemImage: "exclamationmark.triangle.fill")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") {
                        videoManager.retryPlayback()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if let player = videoManager.player {
                AVPlayerMac(player: player)
                    .task(id: player.timeControlStatus) {
                        videoManager.persistCurrentTime()
                    }
                    .onDisappear {
                        videoManager.persistCurrentTime()
                        videoManager.player?.pause()
                        if let mostRecent = videoLoader.getMostRecentHistoryVideo() {
                            videoManager.setVideo(mostRecent, autoPlay: false)
                        }
                    }
            }
        }
        .overlay {
            SponsorSkipOverlay()
        }
        .ignoresSafeArea()
        .windowFullScreenBehavior(.disabled)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .gesture(WindowDragGesture())
        .navigationTitle(videoManager.currentVideo?.title ?? "Loading")
        .navigationSubtitle(videoManager.currentVideo?.channelTitle ?? "Channel")
        .preferredColorScheme(.dark)
        .inspector(isPresented: $showDetail) {
            if let video = videoManager.currentVideo {
                VideoDetailView(video: video)
                    .id(video.id)
                    .toolbar {
                        VideoActionsToolbarContent(video: video)

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
