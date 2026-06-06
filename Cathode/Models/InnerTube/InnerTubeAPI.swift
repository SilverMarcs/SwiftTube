import Foundation
import Network
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - InnerTubeAPI
//
// Implements a subset of the unofficial YouTube InnerTube API used by
// the Android SmartTube client (MediaServiceCore). This layer replaces
// the Java-based youtubeapi module.
//
// References:
//   https://github.com/LuanRT/YouTube.js/blob/main/src/core/clients/Web.ts
//   https://github.com/TeamNewPipe/NewPipeExtractor

public actor InnerTubeAPI {

    /// Shared singleton — used as the foundation facade by Cathode.
    /// Token observation pushes the latest OAuth bearer in via `setAuthToken`
    /// from `YTTVAuthManager`.
    public static let shared = InnerTubeAPI()

    // MARK: - Configuration

    let session: URLSession
    var visitorData: String?
    var authToken: String?

    // MARK: - poToken storage (Step 1)
    //
    // Populated by a PoTokenProvider when configured; nil until then (zero behaviour change).
    // All injection points are gated on `poToken != nil`.
    var poToken: String?
    var poTokenVideoId: String?
    var poTokenExpiry: Date?

    // MARK: - PoTokenProvider
    let poTokenProvider: (any PoTokenProvider)?

    // MARK: - Network path monitoring
    //
    // Resets `visitorData` when the network path changes (VPN connect/disconnect,
    // WiFi switch, cellular handover). A fresh visitorData is issued on the next
    // browse request and is tied to the new IP context, avoiding UNPLAYABLE responses
    // caused by session/IP mismatch after a network transition.
    nonisolated private let pathMonitor = NWPathMonitor()
    private var lastPathStatus: NWPath.Status? = nil

    /// The web client context used to fetch home/search/channel feeds.
    let webClientContext: [String: Any] = [
        "client": [
            "hl": "en",
            "gl": "US",
            "clientName": InnerTubeClients.Web.name,
            "clientVersion": InnerTubeClients.Web.version,
        ]
    ]

    /// The iOS client context used for stream URL retrieval.
    /// Returns c=iOS URLs and an HLS manifest, both playable natively by AVPlayer.
    /// `osVersion` is derived at runtime from ProcessInfo so requests reflect the
    /// actual device OS and are not rejected by YouTube's version validation.
    var iosClientContext: [String: Any] {
        let osVer = InnerTubeClients.iOS.currentOSVersionString.replacingOccurrences(of: "_", with: ".")
        return [
            "client": [
                "hl": "en",
                "gl": "US",
                "clientName": InnerTubeClients.iOS.name,
                "clientVersion": InnerTubeClients.iOS.version,
                "deviceMake": "Apple",
                "deviceModel": "iPhone16,2",
                "osName": "iPhone",
                "osVersion": osVer,
                "clientScreen": "WATCH",
            ]
        ]
    }
    let iosUserAgent = InnerTubeClients.iOS.userAgent

    /// The Android client context used for download URL retrieval.
    /// Exact params match yt-dlp's android client to avoid HTTP 400.
    let androidClientContext: [String: Any] = [
        "client": [
            "hl": "en",
            "gl": "US",
            "clientName": InnerTubeClients.Android.name,
            "clientVersion": InnerTubeClients.Android.version,
            "androidSdkVersion": InnerTubeClients.Android.androidSdkVersion,
            "osName": "Android",
            "osVersion": "11",
        ]
    ]

    /// The TVHTML5 client context required for all authenticated InnerTube requests
    /// (subscriptions, history, playlists, personalised home).
    /// The OAuth token issued by the TV device-code flow is bound to this client.
    /// The WEB client on www.youtube.com rejects Bearer tokens and returns 400.
    let tvClientContext: [String: Any] = [
        "client": [
            "hl": "en",
            "gl": "US",
            "clientName": InnerTubeClients.TV.name,
            "clientVersion": InnerTubeClients.TV.version,
        ]
    ]

    /// The Android VR (Oculus Quest) client context used for audio-only fallback.
    /// Per yt-dlp research (May 2026), this client does not require a PO token for
    /// adaptive audio streams. Used exclusively by `fetchPlayerInfoAndroidVR`.
    let androidVRClientContext: [String: Any] = [
        "client": [
            "hl": "en",
            "gl": "US",
            "clientName": InnerTubeClients.AndroidVR.name,
            "clientVersion": InnerTubeClients.AndroidVR.version,
            "osName": "Android",
            "osVersion": "12",
        ]
    ]

    let baseURL = URL(string: "https://www.youtube.com/youtubei/v1")!
    let playerBaseURL = URL(string: "https://youtubei.googleapis.com/youtubei/v1")!
    // Public InnerTube API key embedded in YouTube's own web client JS — not a developer secret.
    // nosec: false positive — this key is published by Google in youtube.com/s/player JS.
    // Used only for unauthenticated requests (aligned to Android RetrofitOkHttpHelper pattern).
    let apiKey = "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8" // gitleaks:allow
    // Note: TV key (AIzaSyDCU8...) is defined in Android as API_KEY_OLD and never used.

    /// Request timeout for all InnerTube API calls (NW-4-FIX).
    /// Set to 30 s to fail fast on slow/throttled youtubei.googleapis.com requests.
    /// Firebase issue 709b3e91 showed a 2m48s hang when this was left at the OS default.
    static let requestTimeoutInterval: TimeInterval = 30

    public init(authToken: String? = nil, poTokenProvider: (any PoTokenProvider)? = nil) {
        let config = URLSessionConfiguration.default
        // NW-4-FIX: 30 s request timeout. Slow/throttled youtubei.googleapis.com requests
        // previously hung for over 2 minutes (Firebase issue 709b3e91) because the OS default
        // (60 s) was too permissive. 30 s is a good balance between fast failure on truly
        // stuck requests and tolerance for temporarily slow cellular connections.
        config.timeoutIntervalForRequest = Self.requestTimeoutInterval
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
        self.authToken = authToken
        self.poTokenProvider = poTokenProvider
        // Start observing network path changes so visitorData is cleared on network transitions.
        // Callbacks arrive on pathMonitor's private queue; actor re-entry via Task is safe.
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { await self?.handlePathUpdate(path) }
        }
        pathMonitor.start(queue: .global(qos: .background))
    }

    /// Package-internal initializer for testing only.
    /// Accepts a custom `URLSession` so tests can inject a mock via `URLProtocol`.
    init(authToken: String?, session: URLSession) {
        self.session = session
        self.authToken = authToken
        self.poTokenProvider = nil
    }

    // MARK: - Private: Network path handler

    private func handlePathUpdate(_ path: NWPath) {
        // Only reset visitorData when transitioning between satisfied states
        // (e.g. VPN connect, WiFi switch). Ignore transient unsatisfied -> satisfied
        // on first start by comparing to the previously recorded status.
        let prev = lastPathStatus
        lastPathStatus = path.status
        guard path.status == .satisfied, prev == .satisfied else { return }
        visitorData = nil
    }

    // MARK: - Auth

    public func setAuthToken(_ token: String?) {
        self.authToken = token
    }

    // MARK: - Visitor data

    /// Clears the stored per-device `visitorData` token.
    /// Called when the user disables "Per-Device Recommendations" in Settings so
    /// the next home-feed request uses YouTube's default shared recommendation algorithm.
    public func resetVisitorData() {
        visitorData = nil
    }
}
