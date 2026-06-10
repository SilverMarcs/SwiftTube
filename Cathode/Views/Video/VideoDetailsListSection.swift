import SwiftUI

struct VideoDetailsListSection: View {
    let video: Video

    var body: some View {
        #if os(iOS) || os(visionOS)
        VideoTitleSection(video: video)
        #endif
        VideoChannelSection(video: video)
        VideoDescriptionSection(video: video)
    }
}
