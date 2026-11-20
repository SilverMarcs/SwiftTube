import Foundation
import Observation

@MainActor
@Observable
final class ShortPlaybackModel {
    private(set) var source: PlaybackSource?
    private(set) var isResolving = false
    private(set) var error: String?

    @ObservationIgnored private let resolver: StreamResolver
    private var loadID = UUID()

    init(resolver: StreamResolver = .shared) {
        self.resolver = resolver
    }

    func resolveIfNeeded(videoID: String) async {
        guard source == nil, !isResolving else { return }
        await resolve(videoID: videoID, startingWith: .authenticatedEmbedded)
    }

    func retry(videoID: String) async {
        guard !isResolving else { return }
        source = nil
        await resolve(videoID: videoID, startingWith: .authenticatedEmbedded)
    }

    func playerFailed(_ message: String, source failedSource: PlaybackSource, videoID: String) async {
        guard source?.url == failedSource.url,
              source?.strategy == failedSource.strategy,
              !isResolving else { return }
        source = nil
        guard let next = failedSource.strategy?.next else {
            error = message
            return
        }
        await resolve(videoID: videoID, startingWith: next)
    }

    private func resolve(videoID: String, startingWith strategy: PlaybackStrategy) async {
        let id = UUID()
        loadID = id
        isResolving = true
        error = nil
        defer { if loadID == id { isResolving = false } }

        do {
            let result = try await resolver.resolvePlaybackSource(videoID: videoID, startingWith: strategy)
            guard !Task.isCancelled, loadID == id else { return }
            source = result
        } catch {
            guard !Task.isCancelled, loadID == id else { return }
            self.error = error.localizedDescription
        }
    }
}
