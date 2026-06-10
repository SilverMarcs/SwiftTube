import Foundation
@preconcurrency import YouTubeKit

/// Resolves YouTube video IDs to AVPlayer-friendly URLs.
///
/// Extraction runs on-device via YouTubeKit's `.local` method (JavaScriptCore
/// cipher solving). The hosted `.remote` server was returning only itag 18
/// (360p muxed) and dropping every adaptive format, which starved the HLS-proxy
/// path; `.local` surfaces the full AVC1 + AAC adaptive set the proxy needs.
enum StreamResolver {

    /// Itags we play (video-only + audio-only AVC1/AAC) for HLS stitching.
    private static let playbackItags: Set<Int> = [
        134, 135, 136, 137, // AVC1 video-only 30fps: 360p, 480p, 720p, 1080p
        298, 299,           // AVC1 video-only 60fps: 720p60, 1080p60 — 60fps
                            // videos publish NO 136/137, so without these a
                            // 60fps clip caps at itag 135 (480p).
        139, 140,           // AAC audio-only: 48k, 128k
    ]

    /// Itags for downloads and simplified playback: muxed AVC1+AAC. itag 22 (720p) when available,
    /// itag 18 (360p) otherwise.
    private static let muxedItags: Set<Int> = [22, 18]

    /// Single proxy server instance reused across every playback.
    private static let proxy: HLSProxyServer? = try? HLSProxyServer()
    private static var proxyStarted = false
    private static let proxyLock = NSLock()

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
    private static func withAnonymousCookies<T>(_ body: () async throws -> T) async rethrows -> T {
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
    static func resolve(id: String) async -> URL? {
        let rawMode = UserDefaults.standard.string(forKey: "playbackMode") ?? ""
        let mode = PlaybackMode(rawValue: rawMode) ?? .simplified
        return await resolve(id: id, mode: mode)
    }

    static func resolve(id: String, mode: PlaybackMode) async -> URL? {
        switch mode {
        case .simplified:
            return await resolveSimplified(id: id)
        case .remote:
            return await resolveRemoteHLS(id: id)
        #if !os(tvOS)
        case .iframe:
            // The iframe player does not go through StreamResolver's resolve path.
            // But we can fallback to simplified if called.
            return await resolveSimplified(id: id)
        #endif
        }
    }

    /// Returns a direct googlevideo URL for a muxed (video+audio) stream.
    /// Capped at 720p (itag 22) or 360p (itag 18) for natively playable format.
    static func resolveSimplified(id: String) async -> URL? {
        do {
            let yt = YouTube(videoID: id, methods: [.local])
            yt.itagFilter = { muxedItags.contains($0) }
            let streams = try await withAnonymousCookies { try await yt.streams }

            guard let stream = streams
                .filterVideoAndAudio()
                .filter({ $0.isNativelyPlayable })
                .highestResolutionStream()
            else {
                return nil
            }
            return stream.url
        } catch {
            print("StreamResolver.resolveSimplified(\(id)) failed: \(error)")
            return nil
        }
    }

    /// Returns a localhost HLS URL that AVPlayer can stream — up to 1080p AVC1
    /// via separate video+audio renditions stitched in a sidx-derived
    /// byte-range HLS manifest.
    static func resolveRemoteHLS(id: String) async -> URL? {
        do {
            let yt = YouTube(videoID: id, methods: [.local])
            yt.itagFilter = { playbackItags.contains($0) }
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

            guard let proxy = try await ensureProxy() else { return nil }
            proxy.configure(
                videoURL: video.url,
                videoInfo: vInfo,
                videoCodec: codecString(for: video) ?? "avc1.4d4028",
                videoBandwidth: video.bitrate ?? 2_000_000,
                audioURL: audio.url,
                audioInfo: aInfo,
                audioCodec: "mp4a.40.2"
            )
            return URL(string: "http://127.0.0.1:\(proxy.boundPort)/master.m3u8?id=\(id)")
        } catch {
            print("StreamResolver.resolveRemoteHLS(\(id)) failed: \(error)")
            return nil
        }
    }

    /// Direct googlevideo URL for a muxed (video+audio) stream.
    static func resolveMuxed(id: String) async -> URL? {
        await resolveSimplified(id: id)
    }

    // MARK: - Private

    private static func ensureProxy() async throws -> HLSProxyServer? {
        guard let proxy else { return nil }
        proxyLock.lock()
        let started = proxyStarted
        proxyLock.unlock()
        if !started {
            try await proxy.start()
            proxyLock.lock()
            proxyStarted = true
            proxyLock.unlock()
        }
        return proxy
    }

    private static func codecString(for stream: YouTubeKit.Stream) -> String? {
        switch stream.videoCodec {
        case .avc1(let v): return v.isEmpty ? "avc1.4d4028" : "avc1.\(v)"
        case .av1(let v): return v.isEmpty ? "av01.0.05M.08" : "av01.\(v)"
        default: return nil
        }
    }
}

