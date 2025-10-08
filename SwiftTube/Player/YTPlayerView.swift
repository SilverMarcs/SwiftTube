import SwiftUI
import WebKit

/// A SwiftUI view that wraps the YouTube player WebView
struct YTPlayerView<Overlay: View>: View {
    let player: YTPlayer
    let overlayView: Overlay
    @Environment(\.scenePhase) private var scenePhase
    
    init(player: YTPlayer, @ViewBuilder overlayView: () -> Overlay = { EmptyView() }) {
        self.player = player
        self.overlayView = overlayView()
    }
    
    var body: some View {
        WebView(player.webPage)
            .webViewBackForwardNavigationGestures(.disabled)
            .webViewMagnificationGestures(.disabled)
            .webViewTextSelection(.disabled)
            .webViewContentBackground(.hidden)
//            .webViewElementFullscreenBehavior(.enabled)
            .overlay {
                switch player.state {
                case .idle:
                    ProgressView().controlSize(.large)
                case .ready:
                    overlayView
                case .error(_):
                    ContentUnavailableView {
                        Label("Error", systemImage: "exclamationmark.triangle.fill")
                    } description: {
                        Text("YouTube player couldn't be loaded")
                    } actions: {
                        Button("Retry") {
                            Task {
                                try? await player.retry()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            #if !os(macOS)
            // When the view re-appears (e.g., after background) attempt a lightweight restore.
            .task {
                await player.restoreIfNeeded()
            }
            // Also monitor scene/app foreground transitions.
//            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
//                Task { await player.restoreIfNeeded() }
//            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    Task { await player.restoreIfNeeded() }
                }
            }
            #endif
    }
}
