#if os(iOS)
import SwiftUI

/// The current Short's loading and error states, which also activate its playback.
struct ShortsPageOverlay: View {
    let video: Video
    let feed: ShortsFeed

    var body: some View {
        let playback = feed.playback(for: video.id)

        Group {
            if let error = playback?.error {
                VStack {
                    Text(error)
                        .multilineTextAlignment(.center)
                    Button("Retry playback", systemImage: "arrow.clockwise") {
                        Task { await playback?.retry(videoID: video.id) }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else if playback?.source == nil {
                UniversalProgressView()
                    .allowsHitTesting(false)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: video.id) {
            await feed.activate(video)
        }
    }
}
#endif
