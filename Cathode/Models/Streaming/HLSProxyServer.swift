import Foundation
import Network

/// Tiny localhost HTTP server serving three synthesized HLS playlists
/// constructed from parsed fragmented-MP4 sidx info.
///
/// The listener socket does NOT survive app suspension — the system defuncts
/// it, sometimes without ever delivering a `.failed` state update (Apple's
/// guidance: don't keep listeners across suspension; a dead NWListener can't
/// be restarted, only replaced). That killed every post-resume playback until
/// app relaunch (2026-07 "new videos stop loading after a while" bug), so
/// `start()` is re-callable — it builds a fresh listener on a fresh port each
/// time — and `healthCheck()` proves the socket actually accepts connections
/// before a playback URL is handed to AVPlayer. In-flight playbacks don't
/// care: segment byte-ranges point straight at googlevideo, so this socket is
/// only touched when a new player item loads its manifests.
final class HLSProxyServer {
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "hls-proxy")
    private var manifests: [String: String] = [:]
    private var alive = false
    private(set) var boundPort: UInt16 = 0

    func configure(videoURL: URL, videoInfo: FMP4Info, videoCodec: String, videoBandwidth: Int,
                   audioURL: URL, audioInfo: FMP4Info, audioCodec: String) {
        let videoPlaylist = Self.makePlaylist(streamURL: videoURL.absoluteString, info: videoInfo)
        let audioPlaylist = Self.makePlaylist(streamURL: audioURL.absoluteString, info: audioInfo)
        let master = """
        #EXTM3U
        #EXT-X-VERSION:7
        #EXT-X-INDEPENDENT-SEGMENTS
        #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aud",NAME="default",DEFAULT=YES,AUTOSELECT=YES,URI="audio.m3u8"
        #EXT-X-STREAM-INF:BANDWIDTH=\(videoBandwidth),CODECS="\(videoCodec),\(audioCodec)",AUDIO="aud"
        video.m3u8
        """
        let new = [
            "/master.m3u8": master,
            "/video.m3u8": videoPlaylist,
            "/audio.m3u8": audioPlaylist,
        ]
        // Serialize the write onto the same queue that reads happen on, so a
        // request mid-reconfigure can't see a torn dict mixing two videos.
        queue.sync { self.manifests = new }
    }

    private static func makePlaylist(streamURL: String, info: FMP4Info) -> String {
        let maxDur = info.segments.map(\.duration).max() ?? 6.0
        var lines: [String] = [
            "#EXTM3U",
            "#EXT-X-VERSION:7",
            "#EXT-X-PLAYLIST-TYPE:VOD",
            "#EXT-X-TARGETDURATION:\(Int(maxDur.rounded(.up)))",
            "#EXT-X-MAP:URI=\"\(streamURL)\",BYTERANGE=\"\(info.initSize)@0\"",
        ]
        for seg in info.segments {
            lines.append("#EXTINF:\(String(format: "%.6f", seg.duration)),")
            lines.append("#EXT-X-BYTERANGE:\(seg.size)@\(seg.offset)")
            lines.append(streamURL)
        }
        lines.append("#EXT-X-ENDLIST")
        return lines.joined(separator: "\n")
    }

    /// (Re)creates the listener. Any previous listener is cancelled and
    /// replaced; configured manifests survive the swap.
    func start() async throws {
        let fresh = try NWListener(using: .tcp, on: .any)
        fresh.newConnectionHandler = { [weak self] conn in self?.handle(conn) }
        let old: NWListener? = queue.sync {
            let previous = listener
            listener = fresh
            alive = false
            return previous
        }
        old?.cancel()
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            var resumed = false
            fresh.stateUpdateHandler = { [weak self] state in
                // Ignore callbacks from a listener that start() has already
                // replaced — a late .cancelled from the old one must not
                // clobber `alive` for the new one.
                guard let self, self.listener === fresh else { return }
                switch state {
                case .ready:
                    self.alive = true
                    if !resumed, let port = fresh.port?.rawValue {
                        self.boundPort = port
                        resumed = true
                        cont.resume()
                    }
                case .failed(let err):
                    self.alive = false
                    if !resumed { resumed = true; cont.resume(throwing: err) }
                case .cancelled:
                    self.alive = false
                    if !resumed { resumed = true; cont.resume(throwing: CancellationError()) }
                default: break
                }
            }
            fresh.start(queue: queue)
        }
    }

    /// Round-trips a real HTTP request through the listener. State callbacks
    /// alone can't be trusted here: a suspended app's socket can be defuncted
    /// with no `.failed` delivery, leaving `alive` stale-true.
    func healthCheck() async -> Bool {
        let (isAlive, port) = queue.sync { (alive, boundPort) }
        guard isAlive, port != 0 else { return false }
        guard let url = URL(string: "http://127.0.0.1:\(port)/health") else { return false }
        var req = URLRequest(url: url)
        // Never satisfy from URLCache — a cached response would fake health.
        req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        req.timeoutInterval = 1
        guard let (_, response) = try? await URLSession.shared.data(for: req) else { return false }
        return response is HTTPURLResponse
    }

    private func handle(_ conn: NWConnection) {
        conn.start(queue: queue)
        conn.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, _ in
            guard let self, let data, let request = String(data: data, encoding: .utf8) else {
                conn.cancel(); return
            }
            let firstLine = request.split(separator: "\r\n").first ?? ""
            let parts = firstLine.split(separator: " ")
            guard parts.count >= 2 else { conn.cancel(); return }
            self.respond(conn, path: String(parts[1]))
        }
    }

    private func respond(_ conn: NWConnection, path: String) {
        // Strip query string so cache-busting params don't break lookup.
        let pathOnly = path.split(separator: "?", maxSplits: 1).first.map(String.init) ?? path
        if pathOnly == "/health" {
            let resp = "HTTP/1.1 200 OK\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
            conn.send(content: Data(resp.utf8), completion: .contentProcessed { _ in conn.cancel() })
        } else if let body = manifests[pathOnly] {
            let bytes = Data(body.utf8)
            let header = """
            HTTP/1.1 200 OK\r
            Content-Type: application/vnd.apple.mpegurl\r
            Content-Length: \(bytes.count)\r
            Access-Control-Allow-Origin: *\r
            Connection: close\r
            \r\n
            """
            var out = Data(header.utf8); out.append(bytes)
            conn.send(content: out, completion: .contentProcessed { _ in conn.cancel() })
        } else {
            let resp = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
            conn.send(content: Data(resp.utf8), completion: .contentProcessed { _ in conn.cancel() })
        }
    }
}
