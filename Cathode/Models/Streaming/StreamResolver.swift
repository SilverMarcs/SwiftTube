import Foundation

/// Coordinates extraction, pure source selection, adaptive preparation, and
/// manifest registration. Each dependency owns one concern and reports typed
/// failures instead of collapsing every outcome into `nil`.
actor StreamResolver {
    enum Freshness: Sendable {
        case standard
        case revalidate
    }

    static let shared = StreamResolver()

    private let extractor: YouTubeStreamExtractor
    private let manifests: HLSManifestService

    init(
        extractor: YouTubeStreamExtractor = .shared,
        manifests: HLSManifestService = .shared
    ) {
        self.extractor = extractor
        self.manifests = manifests
    }

    func resolvePlaybackSource(
        videoID: String,
        freshness: Freshness = .standard,
        deprioritizing failedKind: PlaybackSource.Kind? = nil
    ) async throws -> PlaybackSource {
        let maximumAttempts = freshness == .revalidate ? 2 : 1
        var lastError: StreamResolutionError?

        for attempt in 0..<maximumAttempts {
            do {
                try Task.checkCancellation()
                let extraction = try await extractor.extract(videoID: videoID)
                return try await prepareSource(
                    from: extraction,
                    deprioritizing: failedKind
                )
            } catch let error as StreamExtractionError {
                if case .cancelled = error { throw StreamResolutionError.cancelled }
                lastError = .extraction(error)
            } catch let error as StreamResolutionError {
                if case .cancelled = error { throw error }
                lastError = error
            } catch is CancellationError {
                throw StreamResolutionError.cancelled
            } catch {
                lastError = .extraction(.network(String(describing: error)))
            }

            if attempt + 1 < maximumAttempts {
                try await Task.sleep(for: .milliseconds(250))
            }
        }

        throw lastError ?? .noPlayableSource
    }

    func resolveProgressiveRequest(
        videoID: String,
        freshness: Freshness = .revalidate
    ) async throws -> URLRequest {
        let maximumAttempts = freshness == .revalidate ? 2 : 1
        var lastError: StreamResolutionError?

        for attempt in 0..<maximumAttempts {
            do {
                try Task.checkCancellation()
                let extraction = try await extractor.extract(videoID: videoID)
                if let progressive = PlaybackSourceSelector.progressive(from: extraction.streams) {
                    var request = URLRequest(url: progressive.url)
                    request.httpShouldHandleCookies = false
                    for (header, value) in progressive.requestHeaders {
                        request.setValue(value, forHTTPHeaderField: header)
                    }
                    return request
                }
                lastError = .noPlayableSource
            } catch let error as StreamExtractionError {
                if case .cancelled = error { throw StreamResolutionError.cancelled }
                lastError = .extraction(error)
            } catch is CancellationError {
                throw StreamResolutionError.cancelled
            }

            if attempt + 1 < maximumAttempts {
                try await Task.sleep(for: .milliseconds(250))
            }
        }

        throw lastError ?? .noPlayableSource
    }

    private func prepareSource(
        from extraction: YouTubeStreamExtraction,
        deprioritizing failedKind: PlaybackSource.Kind?
    ) async throws -> PlaybackSource {
        // Native HLS preserves adaptive quality without exposing signed media
        // URLs. Android progressive MP4 is the reliable fallback and supports
        // arbitrary seeks. Synthesized adaptive HLS remains last-resort only:
        // some CDN URLs enforce sequential range delivery and can fail when a
        // player prefetches segments concurrently.
        var candidates: [PlaybackSource.Kind] = [.nativeHLS, .progressive, .adaptiveHLS]
        if let failedKind,
           let failedIndex = candidates.firstIndex(of: failedKind) {
            candidates.append(candidates.remove(at: failedIndex))
        }

        var preparationFailure: StreamResolutionError?
        for candidate in candidates {
            switch candidate {
            case .nativeHLS:
                if let url = extraction.nativeHLSManifestURL {
                    return .nativeHLS(url: url, expiresAt: Self.expiry(of: url))
                }
            case .adaptiveHLS:
                guard let pair = PlaybackSourceSelector.adaptivePair(from: extraction.streams) else {
                    continue
                }
                do {
                    async let videoInfo = FMP4Parser.parse(
                        url: pair.video.url,
                        requestHeaders: pair.video.requestHeaders
                    )
                    async let audioInfo = FMP4Parser.parse(
                        url: pair.audio.url,
                        requestHeaders: pair.audio.requestHeaders
                    )
                    let (parsedVideo, parsedAudio) = try await (videoInfo, audioInfo)
                    let lease = try await manifests.register(
                        videoURL: pair.video.url,
                        videoInfo: parsedVideo,
                        videoCodec: pair.video.videoCodec ?? "avc1.4d4028",
                        videoBandwidth: max(pair.video.bitrate, 2_000_000),
                        videoRequestHeaders: pair.video.requestHeaders,
                        audioURL: pair.audio.url,
                        audioInfo: parsedAudio,
                        audioCodec: pair.audio.audioCodec ?? "mp4a.40.2",
                        audioRequestHeaders: pair.audio.requestHeaders
                    )
                    return .adaptive(
                        lease: lease,
                        expiresAt: Self.expiry(of: pair.video.url, pair.audio.url)
                    )
                } catch let error as StreamResolutionError {
                    preparationFailure = error
                } catch is CancellationError {
                    throw StreamResolutionError.cancelled
                } catch {
                    preparationFailure = .adaptivePreparation(String(describing: error))
                }
            case .progressive:
                if let progressive = PlaybackSourceSelector.progressive(from: extraction.streams) {
                    return .progressive(
                        url: progressive.url,
                        expiresAt: Self.expiry(of: progressive.url)
                    )
                }
            case .local:
                continue
            }
        }

        throw preparationFailure ?? .noPlayableSource
    }

    private static func expiry(of urls: URL...) -> Date {
        let queryTimestamps = urls
            .compactMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems }
            .compactMap { items in items.first(where: { $0.name == "expire" })?.value }
            .compactMap(TimeInterval.init)
        let pathTimestamps = urls.compactMap { url -> TimeInterval? in
            let parts = url.pathComponents
            guard let expireIndex = parts.firstIndex(of: "expire"),
                  parts.indices.contains(parts.index(after: expireIndex))
            else { return nil }
            return TimeInterval(parts[parts.index(after: expireIndex)])
        }
        guard let earliest = (queryTimestamps + pathTimestamps).min() else {
            return Date().addingTimeInterval(4 * 3600)
        }
        return Date(timeIntervalSince1970: earliest)
    }
}
