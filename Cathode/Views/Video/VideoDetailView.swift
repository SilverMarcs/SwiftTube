import SwiftUI
import SwiftMediaViewer
import AVKit

struct VideoDetailView: View {
    @Environment(VideoManager.self) var manager
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let video: Video
    @State var showDetail: Bool = false

    var showVideo: Bool = false

    var body: some View {
        NavigationStack {
            layoutBody
            // macOS attaches the same actions externally via the player's
            // inspector toolbar, so VideoDetailView only owns its toolbar here.
            #if !os(macOS)
                .toolbar { detailToolbar }
            #endif
        }
    }

    @ViewBuilder
    private var layoutBody: some View {
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

    #if !os(macOS)
    @ToolbarContentBuilder
    private var detailToolbar: some ToolbarContent {
        #if os(iOS)
        ToolbarItem(placement: .topBarLeading) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
            }
        }
                
        ToolbarItem {
            DownloadMenuButton(video: video)
        }
        
        ToolbarSpacer(.fixed)        
        #endif
        
        VideoActionsToolbarContent(video: video)
    }
    #endif

    private var compactBody: some View {
        #if os(iOS) || os(visionOS)
        VStack(spacing: 0) {
            if showVideo {
                AVPlayerViewIos()
            }
            List {
                VideoDetailsListSection(video: video)
                VideoCommentsView(video: video)
            }
        }
        #else
        // macOS never shows the player here — VideoDetailView is the inspector
        // pane and `showVideo` is left at its `false` default.
        List {
            VideoDetailsListSection(video: video)
            VideoCommentsView(video: video)
        }
        #endif
    }
}
