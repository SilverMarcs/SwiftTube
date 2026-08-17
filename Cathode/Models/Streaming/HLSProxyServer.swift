import Foundation
import Network

/// Tiny localhost HTTP server serving namespaced synthesized HLS playlists
/// and authorized fragmented-MP4 byte ranges.
///
/// The listener socket does NOT survive app suspension — the system defuncts
/// it, sometimes without ever delivering a `.failed` state update (Apple's
/// guidance: don't keep listeners across suspension; a dead NWListener can't
/// be restarted, only replaced). That killed every post-resume playback until
/// app relaunch (2026-07 "new videos stop loading after a while" bug), so
/// `start(on:)` is re-callable — it builds a fresh listener, preferentially on
/// the previous port so installed AVPlayer items remain valid — and
/// `healthCheck()` proves the socket actually accepts connections.
///
/// Direct media URLs can reject AVFoundation's requests even when the same
/// range succeeds through Cathode's isolated media transport. Relaying ranges
/// here keeps the client headers and range semantics consistent.
nonisolated final class HLSProxyServer: @unchecked Sendable {
    /// Access is confined to the listener's serial queue. A reference type is
    /// used so the sendable state callback never captures mutable stack state.
    private final class ListenerStartState: @unchecked Sendable {
        var didResumeContinuation = false
    }

    private struct MediaSource: Sendable {
        let url: URL
        let requestHeaders: [String: String]
        let session: URLSession
    }

    private struct NativeResource: Sendable {
        let url: URL
        let requestHeaders: [String: String]
        let basePath: String
        let session: URLSession
    }

    private enum MediaProxyError: Error {
        case invalidResponse
        case rejected(Int)
    }

    private static let maximumMediaAttempts = 3

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "hls-proxy")
    private var manifests: [String: String] = [:]
    private var mediaSources: [String: MediaSource] = [:]
    private var nativeResources: [String: NativeResource] = [:]
    private var nativeResourcePaths: [String: String] = [:]
    private var activeNativeRegistrations: Set<String> = []
    private var registrationSessions: [String: URLSession] = [:]
    private var alive = false
    private(set) var boundPort: UInt16 = 0

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
        let playbackSession = YouTubeMediaTransport.makePlaybackSession()
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
                requestHeaders: videoRequestHeaders,
                session: playbackSession
            )
            mediaSources[audioPath] = MediaSource(
                url: audioURL,
                requestHeaders: audioRequestHeaders,
                session: playbackSession
            )
            registrationSessions[basePath] = playbackSession
        }
        guard let url = URL(string: "http://127.0.0.1:\(port)\(basePath)/master.m3u8") else {
            removeRegistration(at: basePath)
            return nil
        }
        return HLSManifestLease(url: url) { [weak self] in
            self?.removeRegistration(at: basePath)
        }
    }

    /// Registers a filtered remote HLS master playlist and rewrites every
    /// child URI through this server. AVFoundation does not reliably carry an
    /// asset's HTTP headers from a localhost master to a different host, which
    /// made otherwise valid YouTube variants and media segments fail with 403.
    func registerNativeMaster(
        _ manifest: String,
        requestHeaders: [String: String]
    ) -> HLSManifestLease? {
        let namespace = UUID().uuidString.lowercased()
        let basePath = "/streams/\(namespace)"
        let manifestPath = "\(basePath)/master.m3u8"
        let port = queue.sync { boundPort }
        guard port != 0 else { return nil }
        let playbackSession = YouTubeMediaTransport.makePlaybackSession()

        let didRegister = queue.sync {
            activeNativeRegistrations.insert(basePath)
            registrationSessions[basePath] = playbackSession
            guard let rewrittenManifest = rewriteNativePlaylist(
                manifest,
                relativeTo: nil,
                basePath: basePath,
                port: port,
                requestHeaders: requestHeaders,
                session: playbackSession
            ) else {
                activeNativeRegistrations.remove(basePath)
                nativeResources = nativeResources.filter {
                    !$0.key.hasPrefix(basePath)
                }
                nativeResourcePaths = nativeResourcePaths.filter {
                    !$0.key.hasPrefix("\(basePath)\n")
                }
                registrationSessions.removeValue(forKey: basePath)
                return false
            }
            manifests[manifestPath] = rewrittenManifest
            return true
        }
        guard didRegister else {
            playbackSession.invalidateAndCancel()
            return nil
        }
        guard let url = URL(string: "http://127.0.0.1:\(port)\(manifestPath)") else {
            removeRegistration(at: basePath)
            return nil
        }
        return HLSManifestLease(url: url) { [weak self] in
            self?.removeRegistration(at: basePath)
        }
    }

    private func removeRegistration(at basePath: String) {
        queue.async { [weak self] in
            guard let self else { return }
            let session = self.registrationSessions.removeValue(forKey: basePath)
            self.manifests = self.manifests.filter { !$0.key.hasPrefix(basePath) }
            self.mediaSources = self.mediaSources.filter { !$0.key.hasPrefix(basePath) }
            self.nativeResources = self.nativeResources.filter {
                !$0.key.hasPrefix(basePath)
            }
            self.nativeResourcePaths = self.nativeResourcePaths.filter {
                !$0.key.hasPrefix("\(basePath)\n")
            }
            self.activeNativeRegistrations.remove(basePath)
            session?.invalidateAndCancel()
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
    /// replaced; configured manifests survive the swap. Rebinding the previous
    /// port preserves every URL already installed in an AVPlayer item.
    func start(on preferredPort: UInt16? = nil) async throws {
        let requestedPort: NWEndpoint.Port
        if let preferredPort,
           let exactPort = NWEndpoint.Port(rawValue: preferredPort) {
            requestedPort = exactPort
        } else {
            requestedPort = .any
        }

        let fresh = try NWListener(using: .tcp, on: requestedPort)
        fresh.newConnectionHandler = { [weak self] conn in self?.handle(conn) }
        let (old, previousPort): (NWListener?, UInt16) = queue.sync {
            let previous = listener
            listener = fresh
            alive = false
            return (previous, boundPort)
        }
        old?.cancel()
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let startState = ListenerStartState()
            fresh.stateUpdateHandler = { [weak self] state in
                // Ignore callbacks from a listener that start() has already
                // replaced — a late .cancelled from the old one must not
                // clobber `alive` for the new one.
                guard let self, self.listener === fresh else { return }
                switch state {
                case .ready:
                    self.alive = true
                    if !startState.didResumeContinuation, let port = fresh.port?.rawValue {
                        self.boundPort = port
                        if previousPort != 0, previousPort == port {
                            self.refreshRegistrationTransports()
                        }
                        startState.didResumeContinuation = true
                        cont.resume()
                    }
                case .failed(let err):
                    self.alive = false
                    if !startState.didResumeContinuation {
                        startState.didResumeContinuation = true
                        cont.resume(throwing: err)
                    }
                case .waiting(let err):
                    self.alive = false
                    if !startState.didResumeContinuation {
                        startState.didResumeContinuation = true
                        cont.resume(throwing: err)
                    }
                case .cancelled:
                    self.alive = false
                    if !startState.didResumeContinuation {
                        startState.didResumeContinuation = true
                        cont.resume(throwing: CancellationError())
                    }
                default: break
                }
            }
            fresh.start(queue: queue)
        }
    }

    /// URLSession connection pools may be stale after suspension even when the
    /// signed upstream URLs remain fresh. Replace them without changing any
    /// registered path or manifest URL.
    private func refreshRegistrationTransports() {
        let basePaths = Array(registrationSessions.keys)
        for basePath in basePaths {
            let previousSession = registrationSessions[basePath]
            let freshSession = YouTubeMediaTransport.makePlaybackSession()
            registrationSessions[basePath] = freshSession

            let mediaPaths = mediaSources.keys.filter { $0.hasPrefix(basePath) }
            for path in mediaPaths {
                guard let source = mediaSources[path] else { continue }
                mediaSources[path] = MediaSource(
                    url: source.url,
                    requestHeaders: source.requestHeaders,
                    session: freshSession
                )
            }
            let nativePaths = nativeResources.compactMap { path, source in
                source.basePath == basePath ? path : nil
            }
            for path in nativePaths {
                guard let source = nativeResources[path] else { continue }
                nativeResources[path] = NativeResource(
                    url: source.url,
                    requestHeaders: source.requestHeaders,
                    basePath: source.basePath,
                    session: freshSession
                )
            }
            previousSession?.invalidateAndCancel()
        }
    }

    /// Round-trips a real HTTP request through the listener. State callbacks
    /// alone can't be trusted here: a suspended app's socket can be defuncted
    /// with no `.failed` delivery, leaving `alive` stale-true.
    func healthCheck(matching localURL: URL? = nil) async -> Bool {
        let (isAlive, port) = queue.sync { (alive, boundPort) }
        guard isAlive, port != 0 else { return false }
        if let localURL,
           (localURL.host != "127.0.0.1" || localURL.port != Int(port)) {
            return false
        }
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
            let requestLines = request.components(separatedBy: "\r\n")
            let firstLine = requestLines.first ?? ""
            let parts = firstLine.split(separator: " ")
            guard parts.count >= 2 else { conn.cancel(); return }
            let headers = requestLines.dropFirst().reduce(into: [String: String]()) {
                result, line in
                guard let separator = line.firstIndex(of: ":") else { return }
                let name = line[..<separator].trimmingCharacters(in: .whitespaces)
                let value = line[line.index(after: separator)...]
                    .trimmingCharacters(in: .whitespaces)
                result[name.lowercased()] = value
            }
            self.respond(
                conn,
                target: String(parts[1]),
                requestHeaders: headers
            )
        }
    }

    private func respond(
        _ conn: NWConnection,
        target: String,
        requestHeaders: [String: String]
    ) {
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
        } else if let source = nativeResources[pathOnly] {
            proxyNativeResource(
                conn,
                source: source,
                range: requestHeaders["range"]
            )
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
        Task { [weak self] in
            guard let self else {
                conn.cancel()
                return
            }

            do {
                let (data, contentType) = try await fetchMedia(source: source, range: range)
                sendResponse(
                    conn,
                    status: "200 OK",
                    contentType: contentType,
                    body: data
                )
            } catch {
                print("HLS media proxy failed after retries for \(range): \(error)")
                sendResponse(
                    conn,
                    status: "502 Bad Gateway",
                    contentType: nil,
                    body: Data()
                )
            }
        }
    }

    private func fetchMedia(
        source: MediaSource,
        range: String
    ) async throws -> (Data, String) {
        var lastError: Error = MediaProxyError.invalidResponse

        for attempt in 0..<Self.maximumMediaAttempts {
            do {
                var request = URLRequest(url: source.url)
                request.httpShouldHandleCookies = false
                request.setValue(range, forHTTPHeaderField: "Range")
                request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
                for (header, value) in source.requestHeaders {
                    request.setValue(value, forHTTPHeaderField: header)
                }

                let session = attempt == 0
                    ? source.session
                    : YouTubeMediaTransport.makePlaybackSession()
                defer {
                    if attempt > 0 {
                        session.invalidateAndCancel()
                    }
                }
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw MediaProxyError.invalidResponse
                }
                guard http.statusCode == 206 else {
                    throw MediaProxyError.rejected(http.statusCode)
                }
                return (
                    data,
                    http.value(forHTTPHeaderField: "Content-Type") ?? "video/mp4"
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
                if attempt + 1 < Self.maximumMediaAttempts {
                    try await Task.sleep(for: .milliseconds(150 * (attempt + 1)))
                }
            }
        }

        throw lastError
    }

    private func proxyNativeResource(
        _ conn: NWConnection,
        source: NativeResource,
        range: String?
    ) {
        Task { [weak self] in
            guard let self else {
                conn.cancel()
                return
            }

            do {
                try await relayNativeResource(conn, source: source, range: range)
            } catch {
                print("Native HLS proxy failed after retries: \(error)")
                sendResponse(
                    conn,
                    status: "502 Bad Gateway",
                    contentType: nil,
                    body: Data()
                )
            }
        }
    }

    /// Playlist bodies must be collected so their child URLs can be rewritten,
    /// but media is forwarded as it arrives. Buffering a complete multi-MB HLS
    /// segment before responding made startup several seconds slower than direct
    /// AVPlayer playback.
    private func relayNativeResource(
        _ conn: NWConnection,
        source: NativeResource,
        range: String?
    ) async throws {
        var lastError: Error = MediaProxyError.invalidResponse

        for attempt in 0..<Self.maximumMediaAttempts {
            var didStartDownstreamResponse = false
            let session = attempt == 0
                ? source.session
                : YouTubeMediaTransport.makePlaybackSession()
            defer {
                if attempt > 0 {
                    session.invalidateAndCancel()
                }
            }

            do {
                var request = URLRequest(url: source.url)
                request.httpShouldHandleCookies = false
                request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
                if let range {
                    request.setValue(range, forHTTPHeaderField: "Range")
                }
                for (header, value) in source.requestHeaders {
                    request.setValue(value, forHTTPHeaderField: header)
                }

                let (bytes, response) = try await session.bytes(for: request)
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode),
                      let finalURL = http.url
                else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                    throw MediaProxyError.rejected(statusCode)
                }

                var iterator = bytes.makeAsyncIterator()
                var prefix = Data()
                while prefix.count < 7, let byte = try await iterator.next() {
                    prefix.append(byte)
                }
                let contentType = http.value(forHTTPHeaderField: "Content-Type")
                let isPlaylist = prefix.starts(with: Data("#EXTM3U".utf8))
                    || contentType?.lowercased().contains("mpegurl") == true

                if isPlaylist {
                    var data = prefix
                    while let byte = try await iterator.next() {
                        data.append(byte)
                    }
                    guard let playlist = String(data: data, encoding: .utf8),
                          let rewritten = queue.sync(execute: {
                              self.rewriteNativePlaylist(
                                  playlist,
                                  relativeTo: finalURL,
                                  basePath: source.basePath,
                                  port: self.boundPort,
                                  requestHeaders: source.requestHeaders,
                                  session: source.session
                              )
                          })
                    else {
                        throw MediaProxyError.invalidResponse
                    }
                    sendResponse(
                        conn,
                        status: http.statusCode == 206
                            ? "206 Partial Content"
                            : "200 OK",
                        contentType: "application/vnd.apple.mpegurl",
                        body: Data(rewritten.utf8)
                    )
                    return
                }

                didStartDownstreamResponse = true
                try await sendStreamingHeader(
                    conn,
                    status: http.statusCode == 206
                        ? "206 Partial Content"
                        : "200 OK",
                    contentType: contentType,
                    contentLength: http.expectedContentLength,
                    contentRange: http.value(forHTTPHeaderField: "Content-Range")
                )
                var chunk = prefix
                chunk.reserveCapacity(64 * 1024)
                while let byte = try await iterator.next() {
                    chunk.append(byte)
                    if chunk.count >= 64 * 1024 {
                        try await sendStreamingChunk(conn, data: chunk, isComplete: false)
                        chunk.removeAll(keepingCapacity: true)
                    }
                }
                if !chunk.isEmpty {
                    try await sendStreamingChunk(conn, data: chunk, isComplete: false)
                }
                try await sendStreamingChunk(conn, data: nil, isComplete: true)
                conn.cancel()
                return
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // Once HTTP headers or media bytes have been sent, a retry
                // cannot form a valid second response on the same connection.
                if didStartDownstreamResponse {
                    conn.cancel()
                    return
                }
                lastError = error
                if attempt + 1 < Self.maximumMediaAttempts {
                    try await Task.sleep(for: .milliseconds(150 * (attempt + 1)))
                }
            }
        }

        throw lastError
    }

    private func sendStreamingHeader(
        _ conn: NWConnection,
        status: String,
        contentType: String?,
        contentLength: Int64,
        contentRange: String?
    ) async throws {
        var header = "HTTP/1.1 \(status)\r\n"
        if let contentType {
            header += "Content-Type: \(contentType)\r\n"
        }
        if contentLength >= 0 {
            header += "Content-Length: \(contentLength)\r\n"
        }
        if let contentRange {
            header += "Content-Range: \(contentRange)\r\n"
        }
        header += "Accept-Ranges: bytes\r\n"
        header += "Access-Control-Allow-Origin: *\r\n"
        header += "Connection: close\r\n\r\n"
        try await sendStreamingChunk(
            conn,
            data: Data(header.utf8),
            isComplete: false
        )
    }

    private func sendStreamingChunk(
        _ conn: NWConnection,
        data: Data?,
        isComplete: Bool
    ) async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            conn.send(
                content: data,
                contentContext: .defaultMessage,
                isComplete: isComplete,
                completion: .contentProcessed { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            )
        }
    }

    /// Rewrites both standalone playlist URI lines and quoted URI attributes
    /// such as EXT-X-MAP and EXT-X-KEY through a namespaced localhost route.
    /// This method is called only while `queue` owns the registration maps.
    private func rewriteNativePlaylist(
        _ playlist: String,
        relativeTo baseURL: URL?,
        basePath: String,
        port: UInt16,
        requestHeaders: [String: String],
        session: URLSession
    ) -> String? {
        guard activeNativeRegistrations.contains(basePath) else { return nil }
        let lines = playlist.split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        var didFindPlaylistHeader = false
        let rewrittenLines = lines.map { rawLine in
            let line = rawLine.hasSuffix("\r") ? String(rawLine.dropLast()) : rawLine
            if line == "#EXTM3U" {
                didFindPlaylistHeader = true
            }
            if line.hasPrefix("#") {
                return rewriteURIAttributes(
                    in: line,
                    relativeTo: baseURL,
                    basePath: basePath,
                    port: port,
                    requestHeaders: requestHeaders,
                    session: session
                )
            }
            guard !line.isEmpty,
                  let remoteURL = URL(string: line, relativeTo: baseURL)?.absoluteURL,
                  let localURL = registerNativeResource(
                    remoteURL,
                    basePath: basePath,
                    port: port,
                    requestHeaders: requestHeaders,
                    session: session
                  )
            else { return line }
            return localURL.absoluteString
        }
        guard didFindPlaylistHeader else { return nil }
        return rewrittenLines.joined(separator: "\n")
    }

    private func rewriteURIAttributes(
        in line: String,
        relativeTo baseURL: URL?,
        basePath: String,
        port: UInt16,
        requestHeaders: [String: String],
        session: URLSession
    ) -> String {
        var result = line
        var searchStart = result.startIndex
        while let markerRange = result[searchStart...].range(of: "URI=\"") {
            let valueStart = markerRange.upperBound
            guard let valueEnd = result[valueStart...].firstIndex(of: "\"") else {
                break
            }
            let rawURL = String(result[valueStart..<valueEnd])
            guard let remoteURL = URL(string: rawURL, relativeTo: baseURL)?.absoluteURL,
                  let localURL = registerNativeResource(
                    remoteURL,
                    basePath: basePath,
                    port: port,
                    requestHeaders: requestHeaders,
                    session: session
                  )
            else {
                searchStart = result.index(after: valueEnd)
                continue
            }
            result.replaceSubrange(valueStart..<valueEnd, with: localURL.absoluteString)
            searchStart = result.index(valueStart, offsetBy: localURL.absoluteString.count)
        }
        return result
    }

    private func registerNativeResource(
        _ remoteURL: URL,
        basePath: String,
        port: UInt16,
        requestHeaders: [String: String],
        session: URLSession
    ) -> URL? {
        if remoteURL.host == "127.0.0.1", remoteURL.port == Int(port) {
            return remoteURL
        }

        let lookupKey = "\(basePath)\n\(remoteURL.absoluteString)"
        let path: String
        if let existingPath = nativeResourcePaths[lookupKey] {
            path = existingPath
        } else {
            let pathExtension = remoteURL.pathExtension
            let suffix = pathExtension.isEmpty ? "" : ".\(pathExtension)"
            path = "\(basePath)/native/\(UUID().uuidString.lowercased())\(suffix)"
            nativeResourcePaths[lookupKey] = path
            nativeResources[path] = NativeResource(
                url: remoteURL,
                requestHeaders: requestHeaders,
                basePath: basePath,
                session: session
            )
        }
        return URL(string: "http://127.0.0.1:\(port)\(path)")
    }

    private func sendResponse(
        _ conn: NWConnection,
        status: String,
        contentType: String?,
        body: Data,
        additionalHeaders: [String: String] = [:]
    ) {
        var header = "HTTP/1.1 \(status)\r\n"
        if let contentType {
            header += "Content-Type: \(contentType)\r\n"
        }
        for (name, value) in additionalHeaders {
            header += "\(name): \(value)\r\n"
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
