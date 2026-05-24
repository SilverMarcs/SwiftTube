import SwiftUI
import AVFoundation

struct ShortsView: View {
    @Environment(VideoLoader.self) private var videoLoader
    @Environment(VideoManager.self) var videoManager

    @State private var activeVideoId: String?


    var body: some View {
        Group {
#if os(macOS)
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(videoLoader.shortVideos) { video in
                        ShortVideoCard(
                            video: video,
                            isActive: video.id == activeVideoId
                        )
                        .id(video.id)
                        .containerRelativeFrame([.vertical])
                    }
                }
                .scrollTargetLayout()
            }
            .navigationTitle("Shorts")
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $activeVideoId)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(.background)
                    .frame(height: 51)
                    .frame(maxWidth: .infinity)
                    .ignoresSafeArea()
            }
#else
            TabView(selection: $activeVideoId) {
                ForEach(videoLoader.shortVideos) { video in
                    ShortVideoCard(
                        video: video,
                        isActive: video.id == activeVideoId
                    )
                    .tag(video.id)
                }
            }
            .background(.black)
            .statusBarHidden(false)
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
#endif
        }
        .onAppear {
            videoManager.player?.pause()
            if activeVideoId == nil {
                activeVideoId = videoLoader.shortVideos.first?.id
            }
        }
    }
}
