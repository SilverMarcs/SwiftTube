import Foundation

// MARK: - InnerTubeClients
//
// Single source of truth for YouTube InnerTube client identifiers and versions.
// Used by InnerTubeAPI (request bodies + headers) and YTTVAuthManager (TV context body).

nonisolated enum InnerTubeClients {

    /// Public InnerTube key shipped in YouTube's own web client. This is an
    /// application identifier, not a developer secret.
    static let apiKey = "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8" // gitleaks:allow

    enum Web {
        static let name      = "WEB"
        static let nameID    = "1"
        static let version   = "2.20260206.01.00"
        /// Browser UA used by the YouTube web client.
        static let userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    }

    /// visionOS is the primary adaptive playback identity. Unlike the retired
    /// Android VR client, its current direct video and audio URLs permit range
    /// access throughout the media using the anonymous playback context.
    enum VisionOS {
        static let name = "VISIONOS"
        static let nameID = "101"
        static let version = "1.02"
        static let deviceMake = "Apple"
        static let deviceModel = "RealityDevice17,1"
        static let osName = "visionOS"
        static let osVersion = "26.5.23O471"
        static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15"
    }

    enum TV {
        static let name      = "TVHTML5"
        static let nameID    = "7"
        static let version   = "7.20260311.12.00"
        static let userAgent = "Mozilla/5.0 (ChromiumStylePlatform) Cobalt/Version"
    }

    /// Older authenticated TV player identity retained as a compatibility
    /// candidate. Returned media URLs are always preflighted before playback.
    enum TVDowngraded {
        static let name = "TVHTML5"
        static let nameID = "7"
        static let version = "5.20260707"
        static let userAgent = "Mozilla/5.0 (ChromiumStylePlatform) Cobalt/Version"
    }

    /// Current cookie-capable TV player identity. Kept separate from `TV`
    /// because browse/device-auth traffic and media extraction have different
    /// compatibility requirements.
    enum TVPlayback {
        static let name = "TVHTML5"
        static let nameID = "7"
        static let version = "7.20260707.07.00"
        static let userAgent = "Mozilla/5.0 (ChromiumStylePlatform) Cobalt/25.lts.30.1034943-gold (unlike Gecko), Unknown_TV_Unknown_0/Unknown (Unknown, Unknown)"
    }

    enum WebSafari {
        static let name = "WEB"
        static let nameID = "1"
        static let version = "2.20260114.08.00"
        static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.5 Safari/605.1.15,gzip(gfe)"
    }

    /// Maximum number of videos fetched per shelf/related-videos request.
    static let maxVideoResults = 20
}
