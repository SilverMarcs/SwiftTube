import SwiftUI
import SwiftMediaViewer
import AVKit

struct ShortsView: View {
    @Environment(VideoLoader.self) private var videoLoader
    @Environment(VideoManager.self) var videoManager

    @State private var currentIndex = 0
    @State private var shortsPlayer = AVPlayer() // Single shared player

    var body: some View {
        NavigationStack {
            TabView(selection: $currentIndex) {
                ForEach(Array(videoLoader.shortVideos.enumerated()), id: \.element.id) { index, video in
                    ShortVideoCard(
                        video: video,
                        isActive: currentIndex == index,
                        player: shortsPlayer // Pass shared player
                    )
                    .tag(index)
                }
            }
            .background(.black)
            #if !os(macOS)
            .statusBarHidden(false)
            .tabViewStyle(.page(indexDisplayMode: .never))
            #endif
            .onAppear {
                DispatchQueue.main.async {
                    videoManager.isMiniPlayerVisible = false
                }
                videoManager.player?.pause()
            }
            .onDisappear {
                DispatchQueue.main.async {
                    videoManager.isMiniPlayerVisible = true
                }
                // Clean up shorts player
                shortsPlayer.pause()
                shortsPlayer.replaceCurrentItem(with: nil)
            }
            .ignoresSafeArea()
        }
    }
}
