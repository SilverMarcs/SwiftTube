import Foundation

// MARK: - InnerTubeClients
//
// Single source of truth for YouTube InnerTube client identifiers and versions.
// Used by InnerTubeAPI (request bodies + headers) and YTTVAuthManager (TV context body).

enum InnerTubeClients {

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

    /// Android VR client (Oculus Quest identity) — used as an unauthenticated fallback
    /// for audio-only mode. Per yt-dlp research (May 2026), this client does not require
    /// a Proof-of-Origin (PO) token for adaptive streams. Monitor for future enforcement.
    enum AndroidVR {
        static let name    = "ANDROID_VR"
        static let nameID  = "28"
        static let version = "1.65.10"
        static let userAgent = "com.google.android.apps.youtube.vr.oculus/\(version) (Linux; U; Android 12; Build/SQ3A.220705.001.B1) gzip"
    }

    enum TV {
        static let name      = "TVHTML5"
        static let nameID    = "7"
        static let version   = "7.20260311.12.00"
        static let userAgent = "Mozilla/5.0 (ChromiumStylePlatform) Cobalt/Version"
    }

    /// Maximum number of videos fetched per shelf/related-videos request.
    static let maxVideoResults = 20
}
