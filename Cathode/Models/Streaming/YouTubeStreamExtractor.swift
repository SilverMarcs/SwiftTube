import Foundation
import OSLog

/// Fetches media URLs using an app-owned transport and explicit client policy.
/// Authentication cookies stay in `YTCookieAuth` and are attached only to the
/// clients that require them; extraction never edits or reads
/// `HTTPCookieStorage.shared` and has no process-wide JavaScript cache.
actor YouTubeStreamExtractor {
    static let shared = YouTubeStreamExtractor()

    private enum PlayerAuthentication: Sendable {
        case none
        case cookie(CookieAuthentication)
    }

    private struct Client: Sendable {
        let kind: YouTubeStream.ClientKind
        let name: String
        let nameID: String
        let version: String
        let userAgent: String
        let androidSDKVersion: Int?
        let deviceMake: String?
        let deviceModel: String?
        let osName: String?
        let osVersion: String?
        let prefersNativeHLS: Bool
        let allowsAdaptiveDirectURLs: Bool
    }

    struct WatchBootstrap: Sendable {
        let visitorData: String
        let signatureTimestamp: Int
        let playerJavaScriptURL: URL
    }

    private struct CookieAuthentication: Sendable {
        let authorization: String
        let cookies: String
    }

    private struct PlayerRequest: Encodable {
        let context: Context
        let videoId: String
        let contentCheckOk = true
        let racyCheckOk = true
        let playbackContext: PlaybackContext?

        struct Context: Encodable {
            let client: ClientContext
            let thirdParty: YouTubeEmbeddedPlayerConfiguration.ThirdParty?
        }

        struct ClientContext: Encodable {
            let hl = "en"
            let gl = "US"
            let clientName: String
            let clientVersion: String
            let androidSdkVersion: Int?
            let deviceMake: String?
            let deviceModel: String?
            let osName: String?
            let osVersion: String?
            let userAgent: String
            let visitorData: String?
            let platform: String?
        }

        struct PlaybackContext: Encodable {
            let contentPlaybackContext: ContentPlaybackContext

            struct ContentPlaybackContext: Encodable {
                let html5Preference = "HTML5_PREF_WANTS"
                let signatureTimestamp: Int
                let encryptedHostFlags: String?
            }
        }
    }

    private struct PlayerResponse: Decodable, Sendable {
        let playabilityStatus: PlayabilityStatus?
        let streamingData: StreamingData?
        let videoDetails: VideoDetails?

        struct PlayabilityStatus: Decodable, Sendable {
            let status: String?
            let reason: String?
        }

        struct VideoDetails: Decodable, Sendable {
            let videoId: String?
        }

        struct StreamingData: Decodable, Sendable {
            let formats: [Format]?
            let adaptiveFormats: [Format]?
            let hlsManifestUrl: String?

            struct Format: Decodable, Sendable {
                let itag: Int
                let url: String?
                let mimeType: String
                let bitrate: Int?
                let width: Int?
                let height: Int?
                let signatureCipher: String?
                let audioTrack: AudioTrack?
                let isDrc: Bool?
                let drmFamilies: [String]?

                struct AudioTrack: Decodable, Sendable {
                    let displayName: String
                    let id: String
                    let audioIsDefault: Bool?
                    let isAutoDubbed: Bool?
                }
            }
        }
    }

    private struct ClientResponse: Sendable {
        let client: Client
        let response: PlayerResponse
    }

    private struct StreamIdentity: Hashable {
        let clientKind: YouTubeStream.ClientKind
        let itag: Int
        let audioTrackID: String?
        let isDRC: Bool
    }

    private struct NativeHLSCandidate: Sendable {
        let client: Client
        let challenge: YouTubePlayerURLSigner.Challenge
    }

    private struct FormatCandidate: Sendable {
        let client: Client
        let format: PlayerResponse.StreamingData.Format
        let challenge: YouTubePlayerURLSigner.Challenge
    }

    private static let playbackItags: Set<Int> = [
        18, 22,
        134, 135, 136, 137,
        139, 140,
        298, 299,
    ]

    // Normal playback keeps its existing anonymous visionOS policy.
    private static let localClient = Client(
        kind: .visionOS,
        name: InnerTubeClients.VisionOS.name,
        nameID: InnerTubeClients.VisionOS.nameID,
        version: InnerTubeClients.VisionOS.version,
        userAgent: InnerTubeClients.VisionOS.userAgent,
        androidSDKVersion: nil,
        deviceMake: InnerTubeClients.VisionOS.deviceMake,
        deviceModel: InnerTubeClients.VisionOS.deviceModel,
        osName: InnerTubeClients.VisionOS.osName,
        osVersion: InnerTubeClients.VisionOS.osVersion,
        prefersNativeHLS: false,
        allowsAdaptiveDirectURLs: true
    )

    // Authenticated embedded-player HLS is the first remote playback attempt.
    private static let authenticatedClient = Client(
        kind: .authenticatedEmbedded, name: "WEB_EMBEDDED_PLAYER", nameID: "56",
        version: "2.20260708.00.00", userAgent: InnerTubeClients.WebSafari.userAgent,
        androidSDKVersion: nil, deviceMake: nil, deviceModel: nil, osName: nil, osVersion: nil,
        prefersNativeHLS: true, allowsAdaptiveDirectURLs: false
    )

    private static let bootstrapUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.5 Safari/605.1.15,gzip(gfe)"
    private static let logger = Logger(subsystem: "com.SilverMarcs.SwiftTube", category: "StreamExtraction")

    private let session: URLSession
    private let urlSigner: YouTubePlayerURLSigner

    init(
        session: URLSession = YouTubeMediaTransport.session,
        urlSigner: YouTubePlayerURLSigner? = nil
    ) {
        self.session = session
        self.urlSigner = urlSigner ?? YouTubePlayerURLSigner(session: session)
    }

    /// Returns the current web-player context used by authenticated tracking
    /// requests as well as stream extraction. Keeping both paths on the same
    /// STS and visitor context avoids successful `/player` responses that omit
    /// `playbackTracking` entirely.
    func watchBootstrap(for videoID: String) async throws -> WatchBootstrap {
        try await Self.fetchWatchBootstrap(videoID: videoID, session: session)
    }

    @MainActor
    static func playbackContext(for strategy: PlaybackStrategy) async -> YouTubePlaybackContext? {
        guard strategy == .authenticatedEmbedded else { return .anonymous }
        let auth = YTCookieAuth.shared
        await auth.refreshSignInState()
        guard let url = URL(string: "https://www.youtube.com"),
              let authorization = auth.sapisidHashAuthorization(), !authorization.isEmpty,
              let cookies = auth.cookieHeader(for: url), !cookies.isEmpty
        else { return nil }
        return YouTubePlaybackContext(strategy: .authenticatedEmbedded,
                                      authorization: authorization, cookies: cookies)
    }

    func extract(
        videoID: String,
        context: YouTubePlaybackContext = .anonymous
    ) async throws -> YouTubeStreamExtraction {
        do {
            try Task.checkCancellation()
            let client: Client = switch context.strategy {
            case .visionOS: Self.localClient
            case .authenticatedEmbedded: Self.authenticatedClient
            }
            let authentication: PlayerAuthentication
            if let authorization = context.authorization, let cookies = context.cookies {
                authentication = .cookie(CookieAuthentication(authorization: authorization, cookies: cookies))
            } else {
                authentication = .none
            }
            // Each attempt pins one client and credential snapshot. The caller
            // advances to anonymous extraction only after this attempt fails.
            let bootstrap = try await Self.fetchWatchBootstrap(
                videoID: videoID, session: session, cookies: context.cookies
            )
            let response = try await Self.fetch(videoID: videoID, client: client,
                                                bootstrap: bootstrap, authentication: authentication,
                                                session: session)
            try Task.checkCancellation()
            guard response.videoDetails?.videoId == nil || response.videoDetails?.videoId == videoID else {
                throw StreamExtractionError.invalidResponse
            }
            let matchingResponses = [ClientResponse(client: client, response: response)]
            for clientResponse in matchingResponses {
                let streamingData = clientResponse.response.streamingData
                Self.logger.info("Player client=\(clientResponse.client.name, privacy: .public) status=\(clientResponse.response.playabilityStatus?.status ?? "none", privacy: .public) formats=\((streamingData?.formats ?? []).count, privacy: .public) adaptive=\((streamingData?.adaptiveFormats ?? []).count, privacy: .public) hls=\(streamingData?.hlsManifestUrl != nil, privacy: .public)")
            }
            let nativeHLSCandidates = matchingResponses
                .filter(\.client.prefersNativeHLS)
                .compactMap { clientResponse -> NativeHLSCandidate? in
                    guard let rawURL = clientResponse.response.streamingData?.hlsManifestUrl,
                          let url = URL(string: rawURL)
                    else { return nil }
                    return NativeHLSCandidate(
                        client: clientResponse.client,
                        challenge: .init(url: url)
                    )
                }
            let formats = matchingResponses.flatMap { clientResponse in
                let streamingData = clientResponse.response.streamingData
                return (streamingData?.formats ?? []).map { (clientResponse.client, $0) }
                    + (streamingData?.adaptiveFormats ?? []).map { (clientResponse.client, $0) }
            }
            let formatCandidates: [FormatCandidate] = formats.compactMap { client, format in
                guard Self.playbackItags.contains(format.itag),
                      format.drmFamilies?.isEmpty != false,
                      let challenge = Self.urlChallenge(for: format)
                else { return nil }
                return FormatCandidate(
                    client: client,
                    format: format,
                    challenge: challenge
                )
            }

            let challenges = nativeHLSCandidates.map(\.challenge)
                + formatCandidates.map(\.challenge)
            let resolvedURLs: [URL]
            do {
                resolvedURLs = try await urlSigner.resolve(
                    challenges, playerJavaScriptURL: bootstrap.playerJavaScriptURL
                )
            } catch is CancellationError {
                throw StreamExtractionError.cancelled
            } catch {
                Self.logger.error("Player URL signing failed: \(String(describing: error), privacy: .public)")
                throw StreamExtractionError.urlSigning(String(describing: error))
            }

            let nativeHLS = zip(
                nativeHLSCandidates,
                resolvedURLs.prefix(nativeHLSCandidates.count)
            )
            .map { candidate, url in
                YouTubeStreamExtraction.NativeHLS(
                    url: url,
                    clientKind: candidate.client.kind,
                    requestHeaders: ["User-Agent": candidate.client.userAgent]
                )
            }
            .first
            let resolvedFormatURLs = resolvedURLs.dropFirst(nativeHLSCandidates.count)

            // YouTube reuses audio itags for every language, including
            // auto-dubs and DRC variants. Keying by itag alone silently kept
            // whichever language appeared first in the response.
            var streamsByIdentity: [StreamIdentity: YouTubeStream] = [:]
            for (candidate, resolvedURL) in zip(formatCandidates, resolvedFormatURLs) {
                guard let stream = Self.makeStream(
                    from: candidate.format,
                    resolvedURL: resolvedURL,
                    client: candidate.client
                ) else { continue }
                guard candidate.client.allowsAdaptiveDirectURLs
                        || (stream.includesAudio && stream.includesVideo)
                else { continue }
                let identity = StreamIdentity(
                    clientKind: stream.clientKind,
                    itag: stream.itag,
                    audioTrackID: stream.audioTrack?.id,
                    isDRC: stream.isDRC
                )
                streamsByIdentity[identity] = streamsByIdentity[identity] ?? stream
            }
            let streams = Array(streamsByIdentity.values)
            let hasAdaptiveVideo = streams.contains { $0.includesVideo && !$0.includesAudio }
            let hasAdaptiveAudio = streams.contains { $0.includesAudio && !$0.includesVideo }
            if nativeHLS != nil || (hasAdaptiveVideo && hasAdaptiveAudio) {
                return YouTubeStreamExtraction(
                    streams: streams,
                    nativeHLS: nativeHLS
                )
            }
            if !streams.isEmpty {
                return YouTubeStreamExtraction(
                    streams: streams,
                    nativeHLS: nativeHLS
                )
            }

            if formats.contains(where: { $0.1.url == nil && $0.1.signatureCipher != nil }) {
                throw StreamExtractionError.cipheredFormatsOnly
            }
            if let reason = matchingResponses
                .compactMap({ $0.response.playabilityStatus?.reason })
                .first {
                throw StreamExtractionError.unavailable(reason)
            }
            throw StreamExtractionError.noStreams
        } catch is CancellationError {
            throw StreamExtractionError.cancelled
        } catch let error as URLError where error.code == .cancelled {
            throw StreamExtractionError.cancelled
        } catch let error as StreamExtractionError {
            throw error
        } catch {
            throw StreamExtractionError.network(String(describing: error))
        }
    }

    private static func fetch(
        videoID: String,
        client: Client,
        bootstrap: WatchBootstrap?,
        authentication: PlayerAuthentication,
        session: URLSession
    ) async throws -> PlayerResponse {
        let endpoint = "https://www.youtube.com/youtubei/v1/player?prettyPrint=false"
        let embedded = client.kind == .authenticatedEmbedded
            ? try await fetchEmbeddedConfiguration(videoID: videoID, authentication: authentication, session: session)
            : nil
        let clientVersion = embedded?.clientVersion ?? client.version
        let visitorData = embedded?.visitorData ?? bootstrap?.visitorData
        guard let url = URL(string: endpoint) else {
            throw StreamExtractionError.invalidResponse
        }
        let context = PlayerRequest.ClientContext(
            clientName: client.name,
            clientVersion: clientVersion,
            androidSdkVersion: client.androidSDKVersion,
            deviceMake: client.deviceMake,
            deviceModel: client.deviceModel,
            osName: client.osName,
            osVersion: client.osVersion,
            userAgent: client.userAgent,
            visitorData: visitorData,
            platform: embedded == nil ? nil : "DESKTOP"
        )
        let payload = PlayerRequest(
            context: .init(client: context, thirdParty: embedded?.thirdParty),
            videoId: videoID,
            playbackContext: bootstrap.map {
                .init(contentPlaybackContext: .init(signatureTimestamp: $0.signatureTimestamp,
                                                   encryptedHostFlags: embedded?.encryptedHostFlags))
            }
        )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpShouldHandleCookies = false
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(client.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(client.nameID, forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue(clientVersion, forHTTPHeaderField: "X-YouTube-Client-Version")
        switch authentication {
        case .cookie(let cookieAuthentication):
            request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
            request.setValue("https://www.youtube.com", forHTTPHeaderField: "X-Origin")
            request.setValue(cookieAuthentication.authorization, forHTTPHeaderField: "Authorization")
            request.setValue(cookieAuthentication.cookies, forHTTPHeaderField: "Cookie")
        case .none:
            request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
            request.setValue("https://www.youtube.com", forHTTPHeaderField: "X-Origin")
        }
        if let visitorData {
            request.setValue(visitorData, forHTTPHeaderField: "X-Goog-Visitor-Id")
        }
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode)
        else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data.prefix(300), encoding: .utf8) ?? ""
            logger.error("Player client=\(client.name, privacy: .public) v=\(client.version, privacy: .public) HTTP \(statusCode, privacy: .public): \(body, privacy: .public)")
            throw StreamExtractionError.invalidResponse
        }
        return try JSONDecoder().decode(PlayerResponse.self, from: data)
    }

    private static func fetchEmbeddedConfiguration(
        videoID: String,
        authentication: PlayerAuthentication,
        session: URLSession
    ) async throws -> YouTubeEmbeddedPlayerConfiguration {
        guard case .cookie(let authentication) = authentication,
              var components = URLComponents(string: "https://www.youtube.com/embed/") else {
            throw StreamExtractionError.invalidResponse
        }
        components.path += videoID
        components.queryItems = [URLQueryItem(name: "html5", value: "1")]
        guard let url = components.url else { throw StreamExtractionError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpShouldHandleCookies = false
        request.setValue(authenticatedClient.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(YouTubeEmbeddedPlayerConfiguration.embedURL, forHTTPHeaderField: "Referer")
        request.setValue(authentication.cookies, forHTTPHeaderField: "Cookie")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            throw StreamExtractionError.invalidResponse
        }
        return try YouTubeEmbeddedPlayerConfiguration.parse(html)
    }

    private static func fetchWatchBootstrap(
        videoID: String,
        session: URLSession,
        cookies: String? = nil
    ) async throws -> WatchBootstrap {
        guard var components = URLComponents(string: "https://www.youtube.com/watch") else {
            throw StreamExtractionError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "v", value: videoID),
            URLQueryItem(name: "hl", value: "en"),
        ]
        guard let url = components.url else {
            throw StreamExtractionError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpShouldHandleCookies = false
        request.setValue(bootstrapUserAgent, forHTTPHeaderField: "User-Agent")
        if let cookies { request.setValue(cookies, forHTTPHeaderField: "Cookie") }
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              let html = String(data: data, encoding: .utf8),
              let rawVisitorData = firstCapture(
                in: html,
                pattern: #"\"VISITOR_DATA\":\"([^\"]+)\""#
              ),
              let timestampText = firstCapture(
                in: html,
                pattern: #"\"STS\":([0-9]+)"#
              ),
              let signatureTimestamp = Int(timestampText),
              let rawPlayerJavaScriptPath = firstCapture(
                in: html,
                pattern: #"\"(?:jsUrl|PLAYER_JS_URL)\":\"([^\"]+)\""#
              )
        else {
            throw StreamExtractionError.invalidResponse
        }

        let escapedVisitorData = rawVisitorData
            .replacing("\\u003d", with: "=")
            .replacing("\\u0026", with: "&")
        let actualPlayerJavaScriptPath = rawPlayerJavaScriptPath
            .replacing("\\/", with: "/")
            .replacing("\\u0026", with: "&")
        guard let actualPlayerJavaScriptURL = URL(
            string: actualPlayerJavaScriptPath,
            relativeTo: URL(string: "https://www.youtube.com")
        )?.absoluteURL,
              let playerID = firstCapture(
                in: actualPlayerJavaScriptURL.path,
                pattern: #"/s/player/([^/]+)/"#
              ),
              let playerJavaScriptURL = URL(
                string: "https://www.youtube.com/s/player/\(playerID)/player_ias.vflset/en_US/base.js"
              )
        else {
            throw StreamExtractionError.invalidResponse
        }
        return WatchBootstrap(
            visitorData: escapedVisitorData.removingPercentEncoding ?? escapedVisitorData,
            signatureTimestamp: signatureTimestamp,
            playerJavaScriptURL: playerJavaScriptURL
        )
    }

    private static func firstCapture(in text: String, pattern: String) -> String? {
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                in: text,
                range: NSRange(text.startIndex..., in: text)
              ),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[range])
    }

    private static func makeStream(
        from format: PlayerResponse.StreamingData.Format,
        resolvedURL: URL,
        client: Client
    ) -> YouTubeStream? {
        guard format.drmFamilies?.isEmpty != false else { return nil }

        let parts = format.mimeType.split(separator: ";", maxSplits: 1).map(String.init)
        guard let mediaType = parts.first else { return nil }
        let codecs: [String]
        if parts.count > 1,
           let quoteStart = parts[1].firstIndex(of: "\""),
           let quoteEnd = parts[1].lastIndex(of: "\""),
           quoteStart < quoteEnd {
            codecs = parts[1][parts[1].index(after: quoteStart)..<quoteEnd]
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
        } else {
            codecs = []
        }

        let isAudio = mediaType.hasPrefix("audio/")
        let includesAudio = isAudio || codecs.contains { $0.hasPrefix("mp4a.") }
        let includesVideo = !isAudio
        return YouTubeStream(
            url: resolvedURL,
            clientKind: client.kind,
            itag: format.itag,
            mediaKind: isAudio ? .audio : .video,
            codecs: codecs,
            bitrate: format.bitrate ?? 0,
            height: format.height,
            includesAudio: includesAudio,
            includesVideo: includesVideo,
            requestHeaders: ["User-Agent": client.userAgent],
            audioTrack: format.audioTrack.map {
                YouTubeAudioTrackMetadata(
                    id: $0.id,
                    displayName: $0.displayName,
                    isDefault: $0.audioIsDefault ?? false,
                    isAutoDubbed: $0.isAutoDubbed ?? false
                )
            },
            isDRC: format.isDrc ?? false
        )
    }

    private static func urlChallenge(
        for format: PlayerResponse.StreamingData.Format
    ) -> YouTubePlayerURLSigner.Challenge? {
        if let rawURL = format.url, let url = URL(string: rawURL) {
            return .init(url: url)
        }
        guard let signatureCipher = format.signatureCipher,
              let cipherComponents = URLComponents(
                string: "https://www.youtube.com/?\(signatureCipher)"
              ),
              let queryItems = cipherComponents.queryItems,
              let rawURL = queryItems.first(where: { $0.name == "url" })?.value,
              let url = URL(string: rawURL)
        else { return nil }
        return .init(
            url: url,
            signature: queryItems.first(where: { $0.name == "s" })?.value,
            signatureParameter: queryItems.first(where: { $0.name == "sp" })?.value
        )
    }

}
