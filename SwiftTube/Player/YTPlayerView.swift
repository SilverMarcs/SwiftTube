import SwiftUI
import WebKit

/// A SwiftUI view that wraps the YouTube player WebView
struct YTPlayerView: View {
    let player: YTPlayer
    
    var body: some View {
        WebView(player.webPage)
            .webViewBackForwardNavigationGestures(.disabled)
            .webViewMagnificationGestures(.disabled)
            .webViewTextSelection(.disabled)
            .webViewContentBackground(.hidden)
//            .webViewElementFullscreenBehavior(.automatic)
    }
}
