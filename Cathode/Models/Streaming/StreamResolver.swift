import Foundation
@preconcurrency import YouTubeKit

/// Resolves YouTube video IDs to AVPlayer-friendly URLs.
///
/// Extraction goes through your YouTubeKit-Server's WebSocket endpoint so the
/// user's residential IP is what YouTube sees during the player call. That's
/// what gets us proper 1080p AVC1 — server-direct HTTP extraction (from the
/// Cloudflare Worker IP) reliably returns degraded formats only.
///
/// HLS proxy stitches the resulting adaptive video+audio streams into a single
/// localhost HLS manifest AVPlayer can consume.
enum StreamResolver {

    /// YouTubeKit-Server endpoint. Currently points at alexeichhorn's hosted
    /// public server — works reliably, ~5-7s extraction, free.
    /// Our own CF Worker exists at https://youtubekit-server.zabirraihan.workers.dev
    /// but the Free plan's 10ms CPU cap blocks decipher work; swap back when
    /// upgraded to Paid plan.
    private static let serverURL = URL(string: "https://remote-production.youtubekit.dev")!

    /// Itags we play (video-only + audio-only AVC1/AAC). Server skips decipher
    /// for everything else.
    private static let playbackItags: Set<Int> = [
        134, 135, 136, 137, // AVC1 video-only: 360p, 480p, 720p, 1080p
        139, 140,           // AAC audio-only: 48k, 128k
    ]

    /// Itags for downloads: muxed AVC1+AAC. itag 22 (720p) when available,
    /// itag 18 (360p) otherwise.
    private static let muxedItags: Set<Int> = [22, 18]

    /// Single proxy server instance reused across every playback.
    private static let proxy: HLSProxyServer? = try? HLSProxyServer()
    private static var proxyStarted = false
    private static let proxyLock = NSLock()

    /// Returns a localhost HLS URL that AVPlayer can stream — up to 1080p AVC1
    /// via separate video+audio renditions stitched in a sidx-derived
    /// byte-range HLS manifest.
    static func resolve(id: String) async -> URL? {
        do {
            let yt = YouTube(videoID: id, methods: [.remote(serverURL: serverURL)])
            yt.itagFilter = { playbackItags.contains($0) }
            let streams = try await yt.streams

            print("StreamResolver(\(id)): got \(streams.count) streams")

            guard let video = streams
                .filterVideoOnly()
                .filter({ $0.videoCodec?.isNativelyPlayable == true })
                .highestResolutionStream()
            else {
                let vCount = streams.filterVideoOnly().count
                print("StreamResolver(\(id)): no playable video — \(vCount) video-only streams, codecs: \(streams.filterVideoOnly().map { describeCodec($0.videoCodec) })")
                return nil
            }

            guard let audio = streams
                .filterAudioOnly()
                .filter({ $0.audioCodec == .mp4a })
                .lowestAudioBitrateStream()
            else {
                let aCount = streams.filterAudioOnly().count
                print("StreamResolver(\(id)): no AAC audio — \(aCount) audio-only streams, codecs: \(streams.filterAudioOnly().map { String(describing: $0.audioCodec) })")
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
            print("StreamResolver.resolve(\(id)) failed: \(error)")
            return nil
        }
    }

    /// Direct googlevideo URL for a muxed (video+audio) stream — 360p cap on
    /// most modern videos. Used for downloads where the result is a single file.
    static func resolveMuxed(id: String) async -> URL? {
        do {
            let yt = YouTube(videoID: id, methods: [.remote(serverURL: serverURL)])
            yt.itagFilter = { muxedItags.contains($0) }
            return try await yt.streams
                .filterVideoAndAudio()
                .highestResolutionStream()?.url
        } catch {
            print("StreamResolver.resolveMuxed(\(id)) failed: \(error)")
            return nil
        }
    }

    /// Cheap HTTP ping at the server's /warm endpoint. Warms DNS, TLS session,
    /// and Cloudflare Worker cold-start before the user's first click.
    static func prewarm() {
        Task.detached(priority: .utility) {
            let warmURL = serverURL.appendingPathComponent("warm")
            _ = try? await URLSession.shared.data(from: warmURL)
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

    private static func describeCodec(_ codec: YouTubeKit.VideoCodec?) -> String {
        switch codec {
        case .avc1: return "avc1"
        case .av1: return "av1"
        case .vp9: return "vp9"
        case .mp4v: return "mp4v"
        case .unknown(let s): return "unknown(\(s))"
        case .none: return "nil"
        }
    }
}
