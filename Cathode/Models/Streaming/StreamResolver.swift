import Foundation
import OSLog

/// Coordinates extraction, pure source selection, adaptive preparation, and
/// manifest registration. Each dependency owns one concern and reports typed
/// failures instead of collapsing every outcome into `nil`.
actor StreamResolver {
    enum Freshness: Sendable {
        case standard
        case revalidate
    }

    static let shared = StreamResolver()
    private static let logger = Logger(subsystem: "com.SilverMarcs.SwiftTube", category: "StreamResolution")

    private let extractor: YouTubeStreamExtractor
    private let manifests: HLSManifestService

    private struct FilteredNativeHLSMaster {
        let manifest: String
        let variantURLs: [URL]
        let languageCode: String
        let height: Int
    }

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
        requiring requiredKind: PlaybackSource.Kind? = nil
    ) async throws -> PlaybackSource {
        // Selective GVS enforcement is assigned per returned URL. Reject and
        // re-extract bad candidates before AVPlayer sees them instead of
        // discovering the cutoff after a minute of playback.
        let maximumAttempts = 3
        var lastError: StreamResolutionError?

        for attempt in 0..<maximumAttempts {
            do {
                try Task.checkCancellation()
                let extraction = try await extractor.extract(videoID: videoID)
                return try await prepareSource(from: extraction, requiring: requiredKind)
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
                try await Task.sleep(for: .milliseconds(250 * (attempt + 1)))
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
        requiring requiredKind: PlaybackSource.Kind?
    ) async throws -> PlaybackSource {
        let adaptivePairs = PlaybackSourceSelector.adaptivePairs(from: extraction.streams)
        if requiredKind == .nativeHLS {
            return try await nativeHLSSource(from: extraction)
        }
        if requiredKind == .progressive {
            return try progressiveSource(from: extraction)
        }
        if requiredKind == .local {
            throw StreamResolutionError.noPlayableSource
        }

        var preparationFailure: StreamResolutionError?
        if requiredKind == .adaptiveHLS {
            return try await prepareFirstAdaptive(in: adaptivePairs)
        }
        do {
            // `adaptivePairs` is ordered by client policy: visionOS first,
            // authenticated TV second, followed by the remaining fallbacks.
            return try await prepareFirstAdaptive(in: adaptivePairs)
        } catch let error as StreamResolutionError {
            if case .cancelled = error { throw error }
            preparationFailure = error
        }
        // A rejected HD path may use native HLS only when its language-filtered
        // rendition is itself HD. Never turn an available 1080p video into a
        // 144p/360p fallback merely because a direct URL was rejected.
        if extraction.nativeHLS != nil {
            do {
                return try await nativeHLSSource(
                    from: extraction,
                    minimumHeight: adaptivePairs.isEmpty ? nil : 720
                )
            } catch is CancellationError {
                throw StreamResolutionError.cancelled
            } catch {
                Self.logger.error("Native HLS preflight failed: \(String(describing: error), privacy: .public)")
                preparationFailure = .adaptivePreparation(String(describing: error))
            }
        }
        if adaptivePairs.isEmpty {
            return try progressiveSource(from: extraction)
        }
        throw preparationFailure ?? .noPlayableSource
    }

    private func prepareFirstAdaptive(
        in pairs: [PlaybackSourceSelector.AdaptivePair]
    ) async throws -> PlaybackSource {
        var lastError: StreamResolutionError?
        for pair in pairs {
            do {
                return try await prepareAdaptive(pair)
            } catch let error as StreamResolutionError {
                if case .cancelled = error { throw error }
                Self.logger.error("Adaptive preparation failed for \(String(describing: pair.video.clientKind), privacy: .public): \(String(describing: error), privacy: .public)")
                lastError = error
            } catch is CancellationError {
                throw StreamResolutionError.cancelled
            } catch {
                Self.logger.error("Adaptive preparation failed for \(String(describing: pair.video.clientKind), privacy: .public): \(String(describing: error), privacy: .public)")
                lastError = .adaptivePreparation(String(describing: error))
            }
        }
        throw lastError ?? .noPlayableSource
    }

    private func prepareAdaptive(
        _ pair: PlaybackSourceSelector.AdaptivePair
    ) async throws -> PlaybackSource {
        Self.logger.info("Preparing adaptive client=\(String(describing: pair.video.clientKind), privacy: .public) height=\(pair.video.height ?? 0, privacy: .public)")
        if ProcessInfo.processInfo.environment["CATHODE_DEBUG_VIDEO_ID"] != nil {
            print("DEBUG adaptive video url [\(pair.video.clientKind)] \(pair.video.url.absoluteString)")
            print("DEBUG adaptive audio url [\(pair.audio.clientKind)] \(pair.audio.url.absoluteString)")
            print("DEBUG video headers: \(pair.video.requestHeaders)")
            if ProcessInfo.processInfo.environment["CATHODE_DEBUG_NO_FETCH"] != nil {
                throw StreamResolutionError.adaptivePreparation("debug: fetch suppressed")
            }
        }
        async let videoInfo = FMP4Parser.parse(
            url: pair.video.url,
            requestHeaders: pair.video.requestHeaders
        )
        async let audioInfo = FMP4Parser.parse(
            url: pair.audio.url,
            requestHeaders: pair.audio.requestHeaders
        )
        let (parsedVideo, parsedAudio) = try await (videoInfo, audioInfo)
        async let videoAccess: Void = FMP4Parser.preflightMediaAccess(
            url: pair.video.url,
            requestHeaders: pair.video.requestHeaders,
            info: parsedVideo
        )
        async let audioAccess: Void = FMP4Parser.preflightMediaAccess(
            url: pair.audio.url,
            requestHeaders: pair.audio.requestHeaders,
            info: parsedAudio
        )
        _ = try await (videoAccess, audioAccess)
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
    }

    private func nativeHLSSource(
        from extraction: YouTubeStreamExtraction,
        minimumHeight: Int? = nil
    ) async throws -> PlaybackSource {
        guard let nativeHLS = extraction.nativeHLS else {
            throw StreamResolutionError.noPlayableSource
        }
        var request = URLRequest(url: nativeHLS.url)
        request.httpShouldHandleCookies = false
        request.timeoutInterval = 10
        for (header, value) in nativeHLS.requestHeaders {
            request.setValue(value, forHTTPHeaderField: header)
        }
        let (data, response) = try await YouTubeMediaTransport.session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              let manifest = String(data: data, encoding: .utf8),
              manifest.hasPrefix("#EXTM3U")
        else {
            throw StreamResolutionError.adaptivePreparation("Native HLS manifest was rejected.")
        }
        let preferredLanguageCode = PlaybackSourceSelector
            .preferredAudioTrack(from: extraction.streams)?
            .primaryLanguageCode
        if let filteredMaster = Self.filteredNativeHLSMaster(
            manifest,
            baseURL: nativeHLS.url,
            preferredLanguageCode: preferredLanguageCode
        ) {
            if let minimumHeight, filteredMaster.height < minimumHeight {
                throw StreamResolutionError.adaptivePreparation(
                    "The language-filtered HLS rendition is below \(minimumHeight)p."
                )
            }
            try await preflightNativeHLSVariant(
                filteredMaster.variantURLs[0],
                requestHeaders: nativeHLS.requestHeaders
            )
            let lease = try await manifests.registerNativeMaster(
                filteredMaster.manifest,
                requestHeaders: nativeHLS.requestHeaders
            )
            Self.logger.info("Selected native HLS client=\(String(describing: nativeHLS.clientKind), privacy: .public) language=\(filteredMaster.languageCode, privacy: .public)")
            return .nativeHLS(
                lease: lease,
                expiresAt: Self.expiry(of: nativeHLS.url),
                httpUserAgent: nil
            )
        }

        if minimumHeight != nil {
            throw StreamResolutionError.adaptivePreparation(
                "The HLS master could not be constrained to an HD language rendition."
            )
        }

        guard let preferredVariantURL = Self.preferredNativeHLSVariantURL(
            in: manifest,
            baseURL: nativeHLS.url
        ) else {
            throw StreamResolutionError.adaptivePreparation(
                "The HLS master contains no preflightable rendition."
            )
        }
        try await preflightNativeHLSVariant(
            preferredVariantURL,
            requestHeaders: nativeHLS.requestHeaders
        )

        // Never hand AVPlayer a remote master directly. AVFoundation does not
        // reliably preserve the client headers when it follows that master's
        // cross-origin variant and segment URLs. Some videos accept the master
        // request and then reject every child request with 403, which surfaces
        // as a misleading permission error. Relaying the already-fetched master
        // keeps the same headers on the complete HLS resource graph.
        let lease = try await manifests.registerNativeMaster(
            manifest,
            requestHeaders: nativeHLS.requestHeaders
        )
        Self.logger.info("Selected proxied native HLS client=\(String(describing: nativeHLS.clientKind), privacy: .public)")
        return .nativeHLS(
            lease: lease,
            expiresAt: Self.expiry(of: nativeHLS.url),
            httpUserAgent: nil
        )
    }

    private func preflightNativeHLSVariant(
        _ url: URL,
        requestHeaders: [String: String]
    ) async throws {
        var request = URLRequest(url: url)
        request.httpShouldHandleCookies = false
        request.timeoutInterval = 10
        for (header, value) in requestHeaders {
            request.setValue(value, forHTTPHeaderField: header)
        }
        let (data, response) = try await YouTubeMediaTransport.session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              let playlist = String(data: data, encoding: .utf8),
              playlist.hasPrefix("#EXTM3U")
        else {
            throw StreamResolutionError.adaptivePreparation(
                "The selected HLS rendition was rejected."
            )
        }
    }

    private static func preferredNativeHLSVariantURL(
        in manifest: String,
        baseURL: URL
    ) -> URL? {
        struct Candidate {
            let url: URL
            let height: Int
            let bandwidth: Int
        }

        let lines = manifest.split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        var candidates: [Candidate] = []
        var index = 0
        while index < lines.count {
            let streamInfo = lines[index]
            guard streamInfo.hasPrefix("#EXT-X-STREAM-INF:") else {
                index += 1
                continue
            }

            var urlIndex = index + 1
            while urlIndex < lines.count,
                  lines[urlIndex].isEmpty || lines[urlIndex].hasPrefix("#") {
                urlIndex += 1
            }
            guard urlIndex < lines.count,
                  let url = URL(
                      string: lines[urlIndex],
                      relativeTo: baseURL
                  )?.absoluteURL
            else {
                index += 1
                continue
            }
            let height = attribute(named: "RESOLUTION", in: streamInfo)
                .flatMap { resolution in
                    resolution.split(separator: "x", maxSplits: 1).last.flatMap {
                        Int($0)
                    }
                } ?? 0
            let bandwidth = attribute(named: "BANDWIDTH", in: streamInfo)
                .flatMap(Int.init) ?? 0
            candidates.append(Candidate(
                url: url,
                height: height,
                bandwidth: bandwidth
            ))
            index = urlIndex + 1
        }

        return candidates.max {
            ($0.height, $0.bandwidth) < ($1.height, $1.bandwidth)
        }?.url
    }

    private static func filteredNativeHLSMaster(
        _ manifest: String,
        baseURL: URL,
        preferredLanguageCode: String?
    ) -> FilteredNativeHLSMaster? {
        struct Variant {
            let streamInfo: String
            let url: URL
            let languageCode: String
            let bandwidth: Int
            let height: Int
            let consumedIndices: Set<Int>
        }

        let lines = manifest.split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        var variants: [Variant] = []
        var index = 0
        while index < lines.count {
            let line = lines[index]
            guard line.hasPrefix("#EXT-X-STREAM-INF:"),
                  let audioContentID = attribute(
                    named: "YT-EXT-AUDIO-CONTENT-ID",
                    in: line
                  )
            else {
                index += 1
                continue
            }

            var urlIndex = index + 1
            while urlIndex < lines.count,
                  lines[urlIndex].isEmpty || lines[urlIndex].hasPrefix("#") {
                urlIndex += 1
            }
            guard urlIndex < lines.count,
                  let url = URL(string: lines[urlIndex], relativeTo: baseURL)?.absoluteURL
            else {
                index += 1
                continue
            }
            guard let contentLanguage = audioContentID
                .split(separator: ".", maxSplits: 1)
                .first,
                let primaryLanguage = contentLanguage
                    .split(separator: "-", maxSplits: 1)
                    .first
            else {
                index += 1
                continue
            }
            let languageCode = primaryLanguage.lowercased()
            let bandwidth = attribute(named: "BANDWIDTH", in: line)
                .flatMap(Int.init) ?? 0
            let height = attribute(named: "RESOLUTION", in: line)
                .flatMap { resolution in
                    resolution.split(separator: "x", maxSplits: 1).last.flatMap {
                        Int($0)
                    }
                } ?? 0
            variants.append(Variant(
                streamInfo: line,
                url: url,
                languageCode: languageCode,
                bandwidth: bandwidth,
                height: height,
                consumedIndices: [index, urlIndex]
            ))
            index = urlIndex + 1
        }

        let availableLanguages = Set(variants.map(\.languageCode))
        let normalizedPreference = preferredLanguageCode?.lowercased()
        let selectedLanguage: String?
        if let normalizedPreference,
           availableLanguages.contains(normalizedPreference) {
            selectedLanguage = normalizedPreference
        } else if availableLanguages.contains("en") {
            selectedLanguage = "en"
        } else {
            selectedLanguage = nil
        }
        guard let selectedLanguage else { return nil }
        let languageVariants = variants.filter {
            $0.languageCode == selectedLanguage
        }
        guard let selectedVariant = languageVariants.max(by: {
            ($0.height, $0.bandwidth) < ($1.height, $1.bandwidth)
        }) else { return nil }

        let consumedIndices = variants.reduce(into: Set<Int>()) {
            $0.formUnion($1.consumedIndices)
        }
        let globalLines = lines.enumerated().compactMap { lineIndex, line -> String? in
            guard !consumedIndices.contains(lineIndex),
                  line.hasPrefix("#"),
                  !line.hasPrefix("#EXT-X-MEDIA:"),
                  !line.hasPrefix("#EXT-X-STREAM-INF:"),
                  !line.hasPrefix("#EXT-X-I-FRAME-STREAM-INF:")
            else { return nil }
            return line
        }
        let variantLines = [selectedVariant.streamInfo, selectedVariant.url.absoluteString]
        return FilteredNativeHLSMaster(
            manifest: (globalLines + variantLines).joined(separator: "\n") + "\n",
            variantURLs: [selectedVariant.url],
            languageCode: selectedLanguage,
            height: selectedVariant.height
        )
    }

    private static func attribute(named name: String, in line: String) -> String? {
        let quotedMarker = "\(name)=\""
        if let markerRange = line.range(of: quotedMarker) {
            let valueStart = markerRange.upperBound
            guard let valueEnd = line[valueStart...].firstIndex(of: "\"") else {
                return nil
            }
            return String(line[valueStart..<valueEnd])
        }

        let marker = "\(name)="
        guard let markerRange = line.range(of: marker) else { return nil }
        let suffix = line[markerRange.upperBound...]
        return String(suffix.prefix { $0 != "," })
    }

    private func progressiveSource(
        from extraction: YouTubeStreamExtraction
    ) throws -> PlaybackSource {
        guard let progressive = PlaybackSourceSelector.progressive(from: extraction.streams) else {
            throw StreamResolutionError.noPlayableSource
        }
        return .progressive(
            url: progressive.url,
            expiresAt: Self.expiry(of: progressive.url)
        )
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
