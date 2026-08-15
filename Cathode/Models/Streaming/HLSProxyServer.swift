import Foundation
import Network

/// Tiny localhost HTTP server serving namespaced synthesized HLS playlists
/// and their fragmented-MP4 byte ranges.
///
/// The listener socket does NOT survive app suspension — the system defuncts
/// it, sometimes without ever delivering a `.failed` state update (Apple's
/// guidance: don't keep listeners across suspension; a dead NWListener can't
/// be restarted, only replaced). That killed every post-resume playback until
/// app relaunch (2026-07 "new videos stop loading after a while" bug), so
/// `start()` is re-callable — it builds a fresh listener on a fresh port each
/// time — and `healthCheck()` proves the socket actually accepts connections
/// before a playback URL is handed to AVPlayer.
///
/// Media is proxied as well as manifests. This keeps required request headers
/// and transport behavior under Cathode's control instead of handing signed
/// googlevideo URLs directly to AVFoundation.
final class HLSProxyServer: @unchecked Sendable {
    private struct MediaSource: Sendable {
        let url: URL
        let requestHeaders: [String: String]
    }

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "hls-proxy")
    private var manifests: [String: String] = [:]
    private var mediaSources: [String: MediaSource] = [:]
    private var alive = false
    private(set) var boundPort: UInt16 = 0
    // Extraction and FMP4Parser deliberately use this same session so signed
    // media requests share one cookie-free connection pool end to end.
    private let mediaSession = YouTubeMediaTransport.session

    /// Registers an immutable manifest set and returns a lease that removes it
    /// when its owning player goes away. Each resolution gets unique paths so
    /// resolving a Short or another window cannot overwrite an active player.
    func register(
        videoURL: URL,
        videoInfo: FMP4Info,
        videoCodec: String,
        videoBandwidth: Int,
        videoRequestHeaders: [String: String],
        audioURL: URL,
        audioInfo: FMP4Info,
        audioCodec: String,
        audioRequestHeaders: [String: String]
    ) -> HLSManifestLease? {
        let namespace = UUID().uuidString.lowercased()
        let basePath = "/streams/\(namespace)"
        let port = queue.sync { boundPort }
        guard port != 0 else { return nil }

        let localBaseURL = "http://127.0.0.1:\(port)\(basePath)"
        let videoPath = "\(basePath)/video.mp4"
        let audioPath = "\(basePath)/audio.m4a"
        let videoPlaylist = Self.makePlaylist(
            streamURL: "\(localBaseURL)/video.mp4",
            info: videoInfo
        )
        let audioPlaylist = Self.makePlaylist(
            streamURL: "\(localBaseURL)/audio.m4a",
            info: audioInfo
        )
        let master = """
        #EXTM3U
        #EXT-X-VERSION:7
        #EXT-X-INDEPENDENT-SEGMENTS
        #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aud",NAME="default",DEFAULT=YES,AUTOSELECT=YES,URI="audio.m3u8"
        #EXT-X-STREAM-INF:BANDWIDTH=\(videoBandwidth),CODECS="\(videoCodec),\(audioCodec)",AUDIO="aud"
        video.m3u8
        """
        queue.sync {
            manifests["\(basePath)/master.m3u8"] = master
            manifests["\(basePath)/video.m3u8"] = videoPlaylist
            manifests["\(basePath)/audio.m3u8"] = audioPlaylist
            mediaSources[videoPath] = MediaSource(
                url: videoURL,
                requestHeaders: videoRequestHeaders
            )
            mediaSources[audioPath] = MediaSource(
                url: audioURL,
                requestHeaders: audioRequestHeaders
            )
        }
        guard let url = URL(string: "http://127.0.0.1:\(port)\(basePath)/master.m3u8") else {
            removeRegistration(at: basePath)
            return nil
        }
        return HLSManifestLease(url: url) { [weak self] in
            self?.removeRegistration(at: basePath)
        }
    }

    private func removeRegistration(at basePath: String) {
        queue.async { [weak self] in
            self?.manifests = self?.manifests.filter { !$0.key.hasPrefix(basePath) } ?? [:]
            self?.mediaSources = self?.mediaSources.filter { !$0.key.hasPrefix(basePath) } ?? [:]
        }
    }

    private static func makePlaylist(streamURL: String, info: FMP4Info) -> String {
        let maxDur = info.segments.map(\.duration).max() ?? 6.0
        var lines: [String] = [
            "#EXTM3U",
            "#EXT-X-VERSION:7",
            "#EXT-X-PLAYLIST-TYPE:VOD",
            "#EXT-X-TARGETDURATION:\(Int(maxDur.rounded(.up)))",
            "#EXT-X-MAP:URI=\"\(streamURL)?start=0&length=\(info.initSize)\"",
        ]
        for seg in info.segments {
            let duration = seg.duration.formatted(
                .number
                    .locale(Locale(identifier: "en_US_POSIX"))
                    .precision(.fractionLength(6))
            )
            lines.append("#EXTINF:\(duration),")
            lines.append("\(streamURL)?start=\(seg.offset)&length=\(seg.size)")
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
            self.respond(conn, target: String(parts[1]))
        }
    }

    private func respond(_ conn: NWConnection, target: String) {
        let components = URLComponents(string: "http://127.0.0.1\(target)")
        let pathOnly = components?.path ?? target
        if pathOnly == "/health" {
            sendResponse(conn, status: "200 OK", contentType: nil, body: Data())
        } else if let body = manifests[pathOnly] {
            sendResponse(
                conn,
                status: "200 OK",
                contentType: "application/vnd.apple.mpegurl",
                body: Data(body.utf8)
            )
        } else if let source = mediaSources[pathOnly],
                  let range = Self.mediaRange(from: components) {
            proxyMedia(conn, source: source, range: range)
        } else {
            sendResponse(conn, status: "404 Not Found", contentType: nil, body: Data())
        }
    }

    private static func mediaRange(from components: URLComponents?) -> String? {
        let queryItems = components?.queryItems ?? []
        guard let startValue = queryItems.first(where: { $0.name == "start" })?.value,
              let lengthValue = queryItems.first(where: { $0.name == "length" })?.value,
              let start = Int64(startValue),
              let length = Int64(lengthValue),
              start >= 0,
              length > 0,
              start <= Int64.max - length
        else { return nil }
        return "bytes=\(start)-\(start + length - 1)"
    }

    private func proxyMedia(
        _ conn: NWConnection,
        source: MediaSource,
        range: String
    ) {
        var request = URLRequest(url: source.url)
        request.httpShouldHandleCookies = false
        request.setValue(range, forHTTPHeaderField: "Range")
        for (header, value) in source.requestHeaders {
            request.setValue(value, forHTTPHeaderField: header)
        }

        Task { [weak self] in
            guard let self else {
                conn.cancel()
                return
            }
            do {
                let (data, response) = try await mediaSession.data(for: request)
                guard let http = response as? HTTPURLResponse,
                      http.statusCode == 206
                else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                    print("HLS media proxy rejected upstream response: HTTP \(statusCode)")
                    sendResponse(
                        conn,
                        status: "502 Bad Gateway",
                        contentType: nil,
                        body: Data()
                    )
                    return
                }
                sendResponse(
                    conn,
                    status: "200 OK",
                    contentType: http.value(forHTTPHeaderField: "Content-Type") ?? "video/mp4",
                    body: data
                )
            } catch {
                print("HLS media proxy request failed: \(error.localizedDescription)")
                sendResponse(
                    conn,
                    status: "502 Bad Gateway",
                    contentType: nil,
                    body: Data()
                )
            }
        }
    }

    private func sendResponse(
        _ conn: NWConnection,
        status: String,
        contentType: String?,
        body: Data
    ) {
        var header = "HTTP/1.1 \(status)\r\n"
        if let contentType {
            header += "Content-Type: \(contentType)\r\n"
        }
        header += "Content-Length: \(body.count)\r\n"
        header += "Accept-Ranges: bytes\r\n"
        header += "Access-Control-Allow-Origin: *\r\n"
        header += "Connection: close\r\n\r\n"
        var response = Data(header.utf8)
        response.append(body)
        conn.send(content: response, completion: .contentProcessed { _ in conn.cancel() })
    }
}
