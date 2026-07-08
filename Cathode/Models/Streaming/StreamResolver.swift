import Foundation
@preconcurrency import YouTubeKit

/// Resolves YouTube video IDs to AVPlayer-friendly URLs.
///
/// Extraction runs on-device via YouTubeKit's `.local` method (JavaScriptCore
/// cipher solving). The hosted `.remote` server was returning only itag 18
/// (360p muxed) and dropping every adaptive format, which starved the HLS-proxy
/// path; `.local` surfaces the full AVC1 + AAC adaptive set the proxy needs.
enum StreamResolver {

    /// A playable URL plus the moment its underlying googlevideo URLs stop
    /// being servable. googlevideo grants ~6h per extraction; a player item
    /// built from this is dead after `expiresAt` even though AVPlayer still
    /// reports it ready, so callers must re-resolve rather than replay it.
    struct Resolved {
        let url: URL
        let expiresAt: Date
    }

    /// Itags we play (video-only + audio-only AVC1/AAC) for HLS stitching.
    private static let playbackItags: Set<Int> = [
        134, 135, 136, 137, // AVC1 video-only 30fps: 360p, 480p, 720p, 1080p
        298, 299,           // AVC1 video-only 60fps: 720p60, 1080p60 — 60fps
                            // videos publish NO 136/137, so without these a
                            // 60fps clip caps at itag 135 (480p).
        139, 140,           // AAC audio-only: 48k, 128k
    ]

    /// Single proxy server instance reused across every playback. Its
    /// listener socket dies on app suspension (see HLSProxyServer), so every
    /// resolve health-checks it via `ensureProxy` and restarts it when dead —
    /// the old started-once flag left a defunct socket serving nothing, and
    /// every post-suspension playback spun forever until app relaunch.
    private static let proxy = HLSProxyServer()
    private static var proxyStart: Task<Bool, Never>?

    /// Runs `body` with the user's YouTube/Google auth cookies temporarily
    /// removed from `HTTPCookieStorage.shared`, then restores them.
    ///
    /// YouTubeKit extracts via `URLSession.shared`, which reads the shared
    /// cookie store. On a signed-in device (tvOS injects the iCloud cookie set
    /// into `HTTPCookieStorage.shared` for SAPISIDHASH auth) those login cookies
    /// ride along on the extraction requests; YouTube then serves ciphered `web`
    /// formats whose signature this YouTubeKit build can't decode, failing with
    /// `regexMatchError`. Anonymous extraction returns the androidVR plain-URL
    /// adaptive set the proxy needs.
    /// `internal`, not `private`: `DownloadManager` reuses this to strip login
    /// cookies before its own muxed-stream extraction.
    static func withAnonymousCookies<T>(_ body: () async throws -> T) async rethrows -> T {
        let storage = HTTPCookieStorage.shared
        let ytCookies = (storage.cookies ?? []).filter {
            let d = $0.domain.trimmingCharacters(in: .init(charactersIn: "."))
            return d.hasSuffix("youtube.com") || d.hasSuffix("google.com")
        }
        ytCookies.forEach { storage.deleteCookie($0) }
        defer { ytCookies.forEach { storage.setCookie($0) } }
        return try await body()
    }

    /// Resolves the stream based on the selected PlaybackMode.
    static func resolve(id: String) async -> Resolved? {
        let rawMode = UserDefaults.standard.string(forKey: "playbackMode") ?? ""
        let mode = PlaybackMode(rawValue: rawMode) ?? .remote
        return await resolve(id: id, mode: mode)
    }

    static func resolve(id: String, mode: PlaybackMode) async -> Resolved? {
        switch mode {
        case .remote:
            return await resolveRemoteHLS(id: id)
        #if !os(tvOS)
        case .iframe:
            // The iframe player does not go through StreamResolver's resolve path;
            // fall back to the HLS proxy if it ever reaches here.
            return await resolveRemoteHLS(id: id)
        #endif
        }
    }

    /// Returns a localhost HLS URL that AVPlayer can stream — up to 1080p AVC1
    /// via separate video+audio renditions stitched in a sidx-derived
    /// byte-range HLS manifest.
    static func resolveRemoteHLS(id: String) async -> Resolved? {
        do {
            let yt = YouTube(videoID: id, methods: [.local])
            yt.itagFilter = { playbackItags.contains($0) }
            // The user tapped a video from a feed, so it's known playable — skip
            // the watchHTML availability fetch (~0.7-1s) and rely on the persisted
            // js/ytcfg cache. On failure the streams getter retries cold with the
            // availability check, so private/age-restricted errors still surface.
            yt.skipAvailabilityCheck = true
            let streams = try await withAnonymousCookies { try await yt.streams }

            guard let video = streams
                .filterVideoOnly()
                .filter({ $0.videoCodec?.isNativelyPlayable == true })
                .highestResolutionStream()
            else {
                return nil
            }

            // Pick the highest-bitrate AAC-LC track (itag 140, 128k) — matches the
            // "mp4a.40.2" codec declared in the master playlist below.
            guard let audio = streams
                .filterAudioOnly()
                .filter({ $0.audioCodec == .mp4a })
                .highestAudioBitrateStream()
            else {
                return nil
            }

            async let videoInfo = FMP4Parser.parse(url: video.url)
            async let audioInfo = FMP4Parser.parse(url: audio.url)
            let (vInfo, aInfo) = try await (videoInfo, audioInfo)

            guard let proxy = await ensureProxy() else { return nil }
            proxy.configure(
                videoURL: video.url,
                videoInfo: vInfo,
                videoCodec: codecString(for: video) ?? "avc1.4d4028",
                videoBandwidth: video.bitrate ?? 2_000_000,
                audioURL: audio.url,
                audioInfo: aInfo,
                audioCodec: "mp4a.40.2"
            )
            guard let url = URL(string: "http://127.0.0.1:\(proxy.boundPort)/master.m3u8?id=\(id)") else {
                return nil
            }
            return Resolved(url: url, expiresAt: expiry(of: video.url, audio.url))
        } catch {
            print("StreamResolver.resolveRemoteHLS(\(id)) failed: \(error)")
            return nil
        }
    }

    /// Resolves a direct googlevideo **muxed** (video+audio in one progressive
    /// stream) URL that AVPlayer can play with no HLS proxy — the fastest path
    /// to first frame. Picks the **highest-resolution** muxed format: itag 22
    /// (720p) when the video publishes it, else itag 18 (360p). Muxed tops out
    /// at 720p on YouTube; higher resolutions are adaptive-only and need the HLS
    /// proxy. Used by the shorts feed. `.local` on-device extraction only, login
    /// cookies stripped (see `withAnonymousCookies`) so YouTube serves plain
    /// non-ciphered URLs.
    static func resolveMuxed(id: String) async -> URL? {
        do {
            let yt = YouTube(videoID: id, methods: [.local])
            yt.itagFilter = { $0 == 18 || $0 == 22 }
            // We only reach here for a short the user is already viewing, so the
            // video is known playable — skip YouTubeKit's watchHTML availability
            // fetch and lean on the persisted js/ytcfg disk cache.
            yt.skipAvailabilityCheck = true
            let streams = try await withAnonymousCookies { try await yt.streams }
            return streams
                .filterVideoAndAudio()
                .filter { $0.isNativelyPlayable }
                .highestResolutionStream()?
                .url
        } catch {
            print("StreamResolver.resolveMuxed(\(id)) failed: \(error)")
            return nil
        }
    }

    // MARK: - Private

    /// googlevideo URLs carry their server-side TTL as an `expire` query
    /// parameter (unix seconds, ~6h from extraction). Takes the earliest
    /// across the given track URLs; if YouTube ever stops sending it, assumes
    /// a conservative 4h so the expiry-refresh path still fires.
    private static func expiry(of urls: URL...) -> Date {
        let stamps = urls
            .compactMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems }
            .compactMap { items in items.first(where: { $0.name == "expire" })?.value }
            .compactMap(TimeInterval.init)
        guard let earliest = stamps.min() else {
            return Date().addingTimeInterval(4 * 3600)
        }
        return Date(timeIntervalSince1970: earliest)
    }

    /// Returns the proxy only after proving its listener accepts connections,
    /// (re)starting it otherwise. Concurrent resolves share one in-flight
    /// start via `proxyStart` instead of racing two listeners.
    private static func ensureProxy() async -> HLSProxyServer? {
        if await proxy.healthCheck() { return proxy }
        if proxyStart == nil {
            proxyStart = Task {
                do {
                    try await proxy.start()
                    return true
                } catch {
                    print("StreamResolver: HLSProxyServer (re)start failed: \(error)")
                    return false
                }
            }
        }
        guard let task = proxyStart else { return nil }
        let ok = await task.value
        proxyStart = nil
        return ok ? proxy : nil
    }

    private static func codecString(for stream: YouTubeKit.Stream) -> String? {
        switch stream.videoCodec {
        case .avc1(let v): return v.isEmpty ? "avc1.4d4028" : "avc1.\(v)"
        case .av1(let v): return v.isEmpty ? "av01.0.05M.08" : "av01.\(v)"
        default: return nil
        }
    }
}

