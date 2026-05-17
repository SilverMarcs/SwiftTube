import Foundation
@preconcurrency import YouTubeKit

/// Resolves YouTube video IDs to AVPlayer-friendly URLs.
///
/// Playback URLs go through a local HLS proxy so we can serve adaptive
/// AVC1 + AAC streams (up to 1080p H.264). YouTube no longer ships >360p
/// muxed streams, so single-URL playback is capped — the proxy is the path.
enum StreamResolver {

    /// Itags YouTubeKit will sign for HD playback. Filtering early skips
    /// JavaScriptCore work for the dozens of formats we don't care about.
    private static let playbackItags: Set<Int> = [
        134, 135, 136, 137, // AVC1 video-only: 360p, 480p, 720p, 1080p
        139, 140,           // AAC audio-only: 48k, 128k
    ]

    /// Itags for downloads: only true muxed AVC1+AAC, single-file.
    /// itag 22 (720p) when available, itag 18 (360p) otherwise.
    private static let muxedItags: Set<Int> = [22, 18]

    /// Single proxy server instance reused across every playback.
    /// Each call reconfigures with new stream URLs.
    private static let proxy: HLSProxyServer? = try? HLSProxyServer()
    private static var proxyStarted = false
    private static let proxyLock = NSLock()

    /// Returns a localhost HLS URL that AVPlayer can stream.
    /// Up to 1080p via separate video+audio renditions stitched in a
    /// sidx-derived byte-range HLS manifest.
    static func resolve(id: String) async -> URL? {
        do {
            let yt = YouTube(videoID: id, methods: [.local])
            yt.skipAvailabilityCheck = true
            yt.itagFilter = { playbackItags.contains($0) }
            // Stop the InnerTube client cascade as soon as a response includes
            // 1080p AVC1 (itag 137). Most videos satisfy this on the first
            // (androidVR) call, skipping the other two HTTP round-trips.
            yt.responseSatisfied = { itags in itags.contains(137) }
            let streams = try await yt.streams

            guard let video = streams
                .filterVideoOnly()
                .filter({ $0.videoCodec?.isNativelyPlayable == true })
                .highestResolutionStream()
            else { return nil }

            guard let audio = streams
                .filterAudioOnly()
                .filter({ $0.audioCodec == .mp4a })
                .lowestAudioBitrateStream()
            else { return nil }

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
            // Unique query bust AVPlayer's internal HLS manifest cache so a
            // back-to-back video switch doesn't replay the previous video's segments.
            return URL(string: "http://127.0.0.1:\(proxy.boundPort)/master.m3u8?id=\(id)")
        } catch {
            print("StreamResolver.resolve(\(id)) failed: \(error)")
            return nil
        }
    }

    /// Returns a direct googlevideo URL for a muxed (video+audio) stream.
    /// Capped at 360p for most modern videos — used for downloads where
    /// the resulting file is opened later without the proxy.
    static func resolveMuxed(id: String) async -> URL? {
        do {
            let yt = YouTube(videoID: id, methods: [.local])
            yt.skipAvailabilityCheck = true
            yt.itagFilter = { muxedItags.contains($0) }
            // 360p muxed (itag 18) is universally available; stop on first response.
            yt.responseSatisfied = { itags in itags.contains(18) }
            return try await yt.streams
                .filterVideoAndAudio()
                .highestResolutionStream()?.url
        } catch {
            print("StreamResolver.resolveMuxed(\(id)) failed: \(error)")
            return nil
        }
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
