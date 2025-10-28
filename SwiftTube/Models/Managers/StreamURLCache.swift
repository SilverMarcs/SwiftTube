//
//  StreamURLCache.swift
//  SwiftTube
//
//  Created by AI on 28/10/2025.
//

import Foundation
import YouTubeKit

actor StreamURLCache {
    static let shared = StreamURLCache()

    private var cache: [String: URL] = [:]
    private var inFlight: [String: Task<URL, Error>] = [:]
    private let fileURL: URL

    enum CacheError: Error {
        case streamNotFound
    }

    /// Returns a cached stream URL for a given video ID, fetching and caching on miss.
    func url(for videoID: String) async throws -> URL {
        if let url = cache[videoID] { return url }
        if let task = inFlight[videoID] { return try await task.value }

        let task = Task<URL, Error> {
            let methods = self.currentExtractionMethods()
            let youtube = YouTube(videoID: videoID, methods: methods)
            let streams = try await youtube.streams

            guard let stream = streams
                .filterVideoAndAudio()
                .filter({ $0.isNativelyPlayable })
                .highestResolutionStream()
            else {
                throw CacheError.streamNotFound
            }
            return stream.url
        }

        inFlight[videoID] = task

        do {
            let url = try await task.value
            cache[videoID] = url
            inFlight[videoID] = nil
            await persistToDisk()
            return url
        } catch {
            inFlight[videoID] = nil
            throw error
        }
    }

    /// Prefetches stream URLs concurrently for the provided video IDs.
    /// Errors are ignored for prefetch.
    func prefetch(ids: [String]) async {
        await withTaskGroup(of: Void.self) { group in
            for id in ids {
                group.addTask { [weak self] in
                    guard let self else { return }
                    _ = try? await self.url(for: id)
                }
            }
        }
    }

    // MARK: - Helpers
    /// Reads the preferred extraction method from user defaults, mirroring FetchingSettings.
    private func currentExtractionMethods() -> [YouTube.ExtractionMethod] {
        let useLocal = UserDefaults.standard.bool(forKey: "useLocalFetching")
        return useLocal ? [.local] : [.remote]
    }

    // MARK: - Persistence
    init() {
        // Resolve Application Support path and ensure directory exists
        let baseDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = baseDir.appendingPathComponent("SwiftTube", isDirectory: true)
        if !FileManager.default.fileExists(atPath: appDir.path) {
            try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
        self.fileURL = appDir.appendingPathComponent("StreamURLCache.json")
        // Load existing cache from disk
        if let data = try? Data(contentsOf: fileURL),
           let dict = try? JSONDecoder().decode([String: String].self, from: data) {
            var out: [String: URL] = [:]
            for (k, v) in dict { if let u = URL(string: v) { out[k] = u } }
            self.cache = out
        }
    }

    private func persistToDisk() async {
        let dict = cache.mapValues { $0.absoluteString }
        if let data = try? JSONEncoder().encode(dict) {
            try? data.write(to: fileURL, options: [.atomic])
        }
    }
}
