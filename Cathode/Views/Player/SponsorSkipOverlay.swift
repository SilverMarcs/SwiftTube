#if !os(tvOS)
import SwiftUI

struct SponsorSkipOverlay: View {
    @Environment(VideoManager.self) private var videoManager

    private var isInSponsor: Bool { videoManager.currentSponsorSegment != nil }

    var body: some View {
        VStack {
            Spacer()
            HStack {
                if isInSponsor {
                    Button("Skip Sponsor", systemImage: "forward.end") {
                        videoManager.skipCurrentSponsorSegment()
                    }
                }
                Spacer()
            }
            .buttonStyle(.glass)
            .padding()
            #if os(macOS)
            .controlSize(.large)
            #endif
        }
        .allowsHitTesting(isInSponsor)
    }
}
#endif
