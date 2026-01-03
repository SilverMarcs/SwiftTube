import SwiftUI

struct PlayVideoButton<Label: View>: View {
    @Environment(VideoManager.self) var manager
    @Environment(\.requestVideoPresentation) private var requestVideoPresentation
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    let video: Video
    let label: Label
    
    init(video: Video, @ViewBuilder label: () -> Label) {
        self.video = video
        self.label = label()
    }
    
    var body: some View {
        Button {
            manager.setVideo(video)
            requestVideoPresentation()
            #if os(macOS)
            openWindow(id: "media-player")
            #endif
        } label: {
            label
        }
        .buttonStyle(.plain)
    }
}
