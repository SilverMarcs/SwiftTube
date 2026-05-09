import AVKit
import Foundation
@preconcurrency import YouTubeKit

actor StreamURLCache {
    static let shared = StreamURLCache()

    private var urls: [String: URL] = [:]
    private var inflight: [String: Task<URL?, Never>] = [:]

    func cachedURL(for id: String) -> URL? { urls[id] }

    func fetch(id: String) async -> URL? {
        if let url = urls[id] { return url }
        if let task = inflight[id] { return await task.value }

        let methods = FetchingSettings().methods
        let task = Task<URL?, Never> {
            do {
                let youtube = YouTube(videoID: id, methods: methods)
                let stream = try await youtube.streams
                    .filterVideoAndAudio()
                    .filter({ $0.isNativelyPlayable })
                    .highestResolutionStream()
                return stream?.url
            } catch {
                return nil
            }
        }
        inflight[id] = task
        let url = await task.value
        inflight[id] = nil
        if let url { urls[id] = url }
        return url
    }

    func evict(id: String) {
        urls[id] = nil
    }

    func prefetch(ids: [String]) {
        for id in ids where urls[id] == nil && inflight[id] == nil {
            let task = Task<URL?, Never> {
                let methods = FetchingSettings().methods
                do {
                    let youtube = YouTube(videoID: id, methods: methods)
                    let stream = try await youtube.streams
                        .filterVideoAndAudio()
                        .filter({ $0.isNativelyPlayable })
                        .highestResolutionStream()
                    return stream?.url
                } catch {
                    return nil
                }
            }
            inflight[id] = task
            Task {
                let url = await task.value
                await self.storePrefetched(id: id, url: url)
            }
        }
    }

    private func storePrefetched(id: String, url: URL?) {
        inflight[id] = nil
        if let url { urls[id] = url }
    }
}

/// Awaits AVPlayerItem reaching `.readyToPlay` or `.failed`. Returns true on ready, false on failure.
func awaitPlayerItemReady(_ item: AVPlayerItem) async -> Bool {
    if item.status == .readyToPlay { return true }
    if item.status == .failed { return false }
    return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
        var resumed = false
        var observation: NSKeyValueObservation?
        observation = item.observe(\.status, options: [.new, .initial]) { item, _ in
            guard !resumed else { return }
            switch item.status {
            case .readyToPlay:
                resumed = true
                observation?.invalidate()
                cont.resume(returning: true)
            case .failed:
                resumed = true
                observation?.invalidate()
                cont.resume(returning: false)
            default:
                break
            }
        }
    }
}
