import SwiftUI
import SwiftMediaViewer
import AVKit

struct VideoDetailView<Header: View>: View {
    @Environment(VideoManager.self) var manager
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    let video: Video
    @ViewBuilder var header: Header

    var body: some View {
        NavigationStack {
            content
            #if !os(macOS)
                .toolbar { 
                    #if os(iOS)
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                    }
                    #endif

                    VideoActionsToolbarContent(video: video)
                }
            #endif
        }
    }

    private var content: some View {
        #if os(iOS) || os(visionOS)
        VStack(spacing: 0) {
            header
            List {
                VideoDetailsListSection(video: video)
                VideoCommentsView(video: video)
            }
        }
        #else
        List {
            VideoDetailsListSection(video: video)
            VideoCommentsView(video: video)
        }
        #endif
    }
}

extension VideoDetailView where Header == EmptyView {
    init(video: Video) {
        self.init(video: video) { EmptyView() }
    }
}
