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

    enum iOS {
        static let name      = "iOS"
        static let nameID    = "5"
        static let version   = "21.02.3"
        /// Returns the running iOS version formatted as "MAJOR_MINOR_PATCH" (or "MAJOR_MINOR"
        /// when the patch is 0). Dynamically derived from ProcessInfo so the User-Agent always
        /// reflects the actual device OS — prevents YouTube from rejecting requests sent from
        /// devices running iOS versions newer than the hardcoded string.
        static var currentOSVersionString: String {
            let v = ProcessInfo.processInfo.operatingSystemVersion
            return v.patchVersion == 0
                ? "\(v.majorVersion)_\(v.minorVersion)"
                : "\(v.majorVersion)_\(v.minorVersion)_\(v.patchVersion)"
        }
        static var userAgent: String {
            "com.google.ios.youtube/\(version) (iPhone16,2; U; CPU iOS \(currentOSVersionString) like Mac OS X;)"
        }
    }

    /// Android client — used exclusively for downloads.
    /// CDN URLs signed by the Android client are reliably downloadable using just
    /// the Android UA; no session cookies or PO tokens required.
    /// Exact params from yt-dlp to avoid YouTube bot detection / HTTP 400.
    enum Android {
        static let name            = "ANDROID"
        static let nameID          = "3"
        static let version         = "21.02.35"
        static let androidSdkVersion = 30  // Android 11
        static let userAgent       = "com.google.android.youtube/\(version) (Linux; U; Android 11) gzip"
    }

    /// visionOS is the primary adaptive playback identity. Unlike the retired
    /// Android VR client, its current direct video and audio URLs permit range
    /// access throughout the media without a GVS PO token.
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
