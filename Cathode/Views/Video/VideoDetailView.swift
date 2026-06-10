import SwiftUI
import SwiftMediaViewer
import AVKit

struct VideoDetailView: View {
    @Environment(VideoManager.self) var manager
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    let video: Video
    @State var showDetail: Bool = false

    var showVideo: Bool = false

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
                            
                    ToolbarItem {
                        DownloadMenuButton(video: video)
                    }
                    
                    ToolbarSpacer(.fixed)        
                    #endif
                    
                    VideoActionsToolbarContent(video: video)
                }
            #endif
        }
    }

    private var content: some View {
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
        List {
            VideoDetailsListSection(video: video)
            VideoCommentsView(video: video)
        }
        #endif
    }
}
