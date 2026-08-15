import Foundation

/// Fetches direct media URLs using an app-owned, cookie-free transport.
/// Authentication cookies stay in `YTCookieAuth`; extraction never edits or
/// reads `HTTPCookieStorage.shared` and has no process-wide JavaScript cache.
actor YouTubeStreamExtractor {
    static let shared = YouTubeStreamExtractor()

    private struct Client: Sendable {
        let name: String
        let nameID: String
        let version: String
        let userAgent: String
        let androidSDKVersion: Int?
        let deviceModel: String?
        let prefersNativeHLS: Bool
    }

    private struct PlayerRequest: Encodable {
        let context: Context
        let videoId: String
        let contentCheckOk = true
        let racyCheckOk = true

        struct Context: Encodable {
            let client: ClientContext
        }

        struct ClientContext: Encodable {
            let hl = "en"
            let gl = "US"
            let clientName: String
            let clientVersion: String
            let androidSdkVersion: Int?
            let deviceModel: String?
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
            }
        }
    }

    private struct ClientResponse: Sendable {
        let priority: Int
        let client: Client
        let response: PlayerResponse
    }

    private static let playbackItags: Set<Int> = [
        18, 22,
        134, 135, 136, 137,
        139, 140,
        298, 299,
    ]

    private static let clients: [Client] = [
        // Android's progressive MP4 URLs support arbitrary byte ranges. They
        // are the reliable resume/recovery fallback when an adaptive URL is
        // constrained to sequential CDN access.
        Client(
            name: InnerTubeClients.Android.name,
            nameID: InnerTubeClients.Android.nameID,
            version: InnerTubeClients.Android.version,
            userAgent: InnerTubeClients.Android.userAgent,
            androidSDKVersion: InnerTubeClients.Android.androidSdkVersion,
            deviceModel: nil,
            prefersNativeHLS: false
        ),
        Client(
            name: InnerTubeClients.AndroidVR.name,
            nameID: InnerTubeClients.AndroidVR.nameID,
            version: InnerTubeClients.AndroidVR.version,
            userAgent: InnerTubeClients.AndroidVR.userAgent,
            androidSDKVersion: 32,
            deviceModel: "Quest 3",
            prefersNativeHLS: false
        ),
        Client(
            name: "IOS",
            nameID: InnerTubeClients.iOS.nameID,
            version: InnerTubeClients.iOS.version,
            userAgent: InnerTubeClients.iOS.userAgent,
            androidSDKVersion: nil,
            deviceModel: "iPhone16,2",
            prefersNativeHLS: true
        ),
        Client(
            name: "MEDIA_CONNECT_FRONTEND",
            nameID: "0",
            version: "0.1",
            userAgent: "Mozilla/5.0",
            androidSDKVersion: nil,
            deviceModel: nil,
            prefersNativeHLS: false
        ),
    ]

    private let session: URLSession

    init(session: URLSession = YouTubeMediaTransport.session) {
        self.session = session
    }

    func extract(videoID: String) async throws -> YouTubeStreamExtraction {
        do {
            try Task.checkCancellation()
            var responses: [ClientResponse] = []
            var errors: [Error] = []

            await withTaskGroup(of: Result<ClientResponse, Error>.self) { group in
                for (priority, client) in Self.clients.enumerated() {
                    group.addTask { [session] in
                        do {
                            let response = try await Self.fetch(
                                videoID: videoID,
                                client: client,
                                session: session
                            )
                            return .success(ClientResponse(
                                priority: priority,
                                client: client,
                                response: response
                            ))
                        } catch {
                            return .failure(error)
                        }
                    }
                }

                for await result in group {
                    switch result {
                    case .success(let response): responses.append(response)
                    case .failure(let error): errors.append(error)
                    }
                }
            }

            try Task.checkCancellation()

            let matchingResponses = responses
                .sorted { $0.priority < $1.priority }
                .filter {
                    $0.response.videoDetails?.videoId == nil
                        || $0.response.videoDetails?.videoId == videoID
                }
            let nativeHLSManifestURL = matchingResponses
                .filter(\.client.prefersNativeHLS)
                .compactMap { $0.response.streamingData?.hlsManifestUrl }
                .compactMap(URL.init(string:))
                .first
            let formats = matchingResponses.flatMap { clientResponse in
                let streamingData = clientResponse.response.streamingData
                return (streamingData?.formats ?? []).map { (clientResponse.client, $0) }
                    + (streamingData?.adaptiveFormats ?? []).map { (clientResponse.client, $0) }
            }

            var streamsByItag: [Int: YouTubeStream] = [:]
            for (client, format) in formats where Self.playbackItags.contains(format.itag) {
                guard let stream = Self.makeStream(from: format, client: client) else { continue }
                streamsByItag[stream.itag] = streamsByItag[stream.itag] ?? stream
            }
            if !streamsByItag.isEmpty || nativeHLSManifestURL != nil {
                return YouTubeStreamExtraction(
                    streams: Array(streamsByItag.values),
                    nativeHLSManifestURL: nativeHLSManifestURL
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
            if let firstError = errors.first {
                throw StreamExtractionError.network(String(describing: firstError))
            }
            throw StreamExtractionError.noStreams
        } catch is CancellationError {
            throw StreamExtractionError.cancelled
        }
    }

    private static func fetch(
        videoID: String,
        client: Client,
        session: URLSession
    ) async throws -> PlayerResponse {
        guard let url = URL(string: "https://www.youtube.com/youtubei/v1/player?prettyPrint=false") else {
            throw StreamExtractionError.invalidResponse
        }
        let context = PlayerRequest.ClientContext(
            clientName: client.name,
            clientVersion: client.version,
            androidSdkVersion: client.androidSDKVersion,
            deviceModel: client.deviceModel
        )
        let payload = PlayerRequest(
            context: .init(client: context),
            videoId: videoID
        )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpShouldHandleCookies = false
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(client.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(client.nameID, forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue(client.version, forHTTPHeaderField: "X-YouTube-Client-Version")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode)
        else {
            throw StreamExtractionError.invalidResponse
        }
        return try JSONDecoder().decode(PlayerResponse.self, from: data)
    }

    private static func makeStream(
        from format: PlayerResponse.StreamingData.Format,
        client: Client
    ) -> YouTubeStream? {
        guard let rawURL = format.url,
              let url = URL(string: rawURL)
        else { return nil }

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
            url: url,
            itag: format.itag,
            mediaKind: isAudio ? .audio : .video,
            codecs: codecs,
            bitrate: format.bitrate ?? 0,
            height: format.height,
            includesAudio: includesAudio,
            includesVideo: includesVideo,
            requestHeaders: ["User-Agent": client.userAgent]
        )
    }
}
