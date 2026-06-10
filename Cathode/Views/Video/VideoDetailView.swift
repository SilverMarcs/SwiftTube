import SwiftUI
import SwiftMediaViewer
import AVKit

struct VideoDetailView: View {
    @Environment(VideoManager.self) var manager
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let video: Video
    @State var showDetail: Bool = false

    var showVideo: Bool = false

    var body: some View {
        NavigationStack {
            #if os(macOS)
            compactBody
            #else
            if horizontalSizeClass == .regular {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 0) {
                        if showVideo {
                            AVPlayerViewIos()
                                .background(.black)
                        }

                        List {
                            VideoDetailsListSection(video: video)
                        }
                    }
                    .containerRelativeFrame(.horizontal, count: 3, span: 2, spacing: 16)

                    List {
                        VideoCommentsView(video: video)
                    }
                    .containerRelativeFrame(.horizontal, count: 3, span: 1, spacing: 16)
                }
            } else {
                compactBody
            }
            #endif
        }
    }

    private var compactBody: some View {
        List {
            VideoDetailsListSection(video: video)
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
