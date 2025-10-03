import WebKit

/// A minimal YouTube player using WebPage and WebView APIs
@Observable
final class YTPlayer {
    
    // MARK: - Types
    
    enum State {
        case idle
        case ready
        case error(Error)
    }
    
    enum PlaybackState: Int {
        case unstarted = -1
        case ended = 0
        case playing = 1
        case paused = 2
        case buffering = 3
        case cued = 5
    }
    
    struct Configuration {
        var autoPlay: Bool = true
        var showControls: Bool = true
        var loop: Bool = false
        
        static let `default` = Configuration()
        static let shorts = Configuration(autoPlay: true, showControls: false, loop: true)
    }
    
    // MARK: - Properties
    
    var state: State = .idle
    /// Local source of truth for fullscreen state - toggles whenever YouTube sends a fullscreen change event
    var isFullscreen: Bool = false
    private(set) var webPage: WebPage

    /// Get playback state as an async computed property
    var playbackState: PlaybackState {
        get async throws {
            let result = try await webPage.callJavaScript("return player.getPlayerState();")
            guard let stateValue = result as? Int,
                  let state = PlaybackState(rawValue: stateValue) else {
                throw YTPlayerError.invalidResponse
            }
            return state
        }
    }
    /// Get current playback time
    var currentPlaybackTime: TimeInterval {
        get async throws {
            let result = try await webPage.callJavaScript("return player.getCurrentTime();")
            guard let time = result as? Double else {
                throw YTPlayerError.invalidResponse
            }
            return time
        }
    }
    /// Get video duration
    var duration: TimeInterval {
        get async throws {
            let result = try await webPage.callJavaScript("return player.getDuration();")
            guard let time = result as? Double else {
                throw YTPlayerError.invalidResponse
            }
            return time
        }
    }
    private var videoId: String?
    private let configuration: Configuration
    
    // MARK: - Initialization
    
    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        
        var config = WebPage.Configuration()
        #if !os(macOS)
        config.mediaPlaybackBehavior = .allowsInlinePlayback
        #endif
        config.allowsAirPlayForMediaPlayback = true
        config.websiteDataStore = .default()
        
        // Set up message handler for fullscreen changes
        let handler = FullscreenMessageHandler(onChange: {})
        config.userContentController.add(handler, name: "fullscreenChange")
        
        self.webPage = WebPage(configuration: config)
        self.webPage.isInspectable = false
        
        // Set the callback after self is fully initialized
        handler.onChange = { self.isFullscreen.toggle() }
    }
    
    // MARK: - Public API
    
    /// Load a video by ID with optional start time
    func load(videoId: String, startTime: TimeInterval? = nil) async throws {
        self.videoId = videoId
        
        // If already initialized, just change the video instead of reloading HTML
        if case .ready = state {
            try await changeVideo(videoId: videoId, startTime: startTime)
            return
        }
        
        let html = buildHTML(videoId: videoId, startTime: startTime)
        
        // Load the HTML
        for try await event in webPage.load(html: html, baseURL: URL(string: "https://www.youtube.com")!) {
            // Track navigation events
            switch event {
            case .finished:
                state = .ready
                if configuration.autoPlay {
                    try? await play()
                }
            default:
                break
            }
        }
    }
    
    /// Change video without reloading the entire WebPage (more efficient)
    private func changeVideo(videoId: String, startTime: TimeInterval?) async throws {
        let startParam = startTime.map { ", \(Int($0))" } ?? ""
        let script = """
        if (player && player.loadVideoById) {
            player.loadVideoById('\(videoId)'\(startParam));
        }
        """
        _ = try await webPage.callJavaScript(script)
        self.videoId = videoId
    }
    
    /// Play the video
    func play() async throws {
        try await executePlayerCommand("playVideo()")
    }
    
    /// Pause the video
    func pause() async throws {
        try await executePlayerCommand("pauseVideo()")
    }
    
    /// Seek to a specific time
    func seek(to time: TimeInterval) async throws {
        try await executePlayerCommand("seekTo(\(time), true)")
    }
    
    /// Retry loading the current video
    func retry() async throws {
        guard let videoId else { throw YTPlayerError.playerNotReady }
        try await load(videoId: videoId)
    }
    
    // MARK: - Private Methods
    
    private func executePlayerCommand(_ command: String) async throws {
        _ = try await webPage.callJavaScript("player.\(command);")
    }
    
    private func buildHTML(videoId: String, startTime: TimeInterval?) -> String {
        let startParam = startTime.map { ",\n                start: \(Int($0))" } ?? ""
        let loopParam = configuration.loop ? ",\n                loop: 1,\n                playlist: '\(videoId)'" : ""
        let autoplayParam = configuration.autoPlay ? 1 : 0
        let controlsParam = configuration.showControls ? 1 : 0
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, minimum-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                body, html {
                    margin: 0;
                    padding: 0;
                    width: 100%;
                    height: 100%;
                    overflow: hidden;
                }
                #player {
                    position: absolute;
                    top: 0;
                    left: 0;
                    width: 100%;
                    height: 100%;
                }
            </style>
        </head>
        <body>
            <div id="player"></div>
            
            <script src="https://www.youtube.com/iframe_api"></script>
            <script>
                var player;
                
                function onYouTubeIframeAPIReady() {
                    player = new YT.Player('player', {
                        videoId: '\(videoId)',
                        playerVars: {
                            autoplay: \(autoplayParam),
                            controls: \(controlsParam),
                            playsinline: 1,
                            modestbranding: 1,
                            rel: 0\(startParam)\(loopParam)
                        },
                        events: {
                            'onReady': onPlayerReady,
                            'onStateChange': onPlayerStateChange,
                            'onError': onPlayerError,
                            'onFullscreenChange': onFullscreenChange
                        }
                    });
                }
                
                function onPlayerReady(event) {
                    // Player is ready
                }
                
                function onPlayerStateChange(event) {
                    // State changed
                }
                
                function onPlayerError(event) {
                    // Error occurred
                }
                
                function onFullscreenChange(event) {
                    const isFullscreen = event.data === 1;
                    window.webkit.messageHandlers.fullscreenChange.postMessage({
                        fullscreen: isFullscreen
                    });
                }
            </script>
        </body>
        </html>
        """
    }
}

// MARK: - Error

enum YTPlayerError: Error {
    case invalidResponse
    case playerNotReady
}

// MARK: - Fullscreen Message Handler

private class FullscreenMessageHandler: NSObject, WKScriptMessageHandler {
    var onChange: (() -> Void)
    
    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // Call the callback on fullscreen change
        onChange()
    }
}
