import Foundation
import Network

/// Tiny localhost HTTP server serving three synthesized HLS playlists
/// constructed from parsed fragmented-MP4 sidx info.
final class HLSProxyServer {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "hls-proxy")
    private var manifests: [String: String] = [:]
    private(set) var boundPort: UInt16 = 0

    init() throws {
        self.listener = try NWListener(using: .tcp, on: .any)
    }

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

    func start() async throws {
        listener.newConnectionHandler = { [weak self] conn in self?.handle(conn) }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            var resumed = false
            listener.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready:
                    if !resumed, let port = self.listener.port?.rawValue {
                        self.boundPort = port
                        resumed = true
                        cont.resume()
                    }
                case .failed(let err):
                    if !resumed { resumed = true; cont.resume(throwing: err) }
                case .cancelled:
                    if !resumed { resumed = true; cont.resume(throwing: CancellationError()) }
                default: break
                }
            }
            listener.start(queue: queue)
        }
    }

    func stop() { listener.cancel() }

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
        if let body = manifests[pathOnly] {
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
