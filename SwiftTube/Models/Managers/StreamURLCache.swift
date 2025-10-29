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

    // TTL for cached stream URLs: 2 hours
    private static let ttl: TimeInterval = 2 * 60 * 60

    private struct CacheEntry: Codable {
        let url: URL
        let createdAt: Date
    }

    private struct PersistedEntry: Codable {
        let url: String
        let createdAt: TimeInterval // seconds since 1970
    }

    private var cache: [String: CacheEntry] = [:]
    private var inFlight: [String: Task<URL, Error>] = [:]
    private let fileURL: URL

    enum CacheError: Error {
        case streamNotFound
    }

    /// Returns a cached stream URL for a given video ID, fetching and caching on miss.
    func url(for videoID: String) async throws -> URL {
        if let entry = cache[videoID], !isExpired(entry) {
            return entry.url
        } else if cache[videoID] != nil {
            // Expired; drop it so we fetch fresh
            cache[videoID] = nil
        }
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
            cache[videoID] = CacheEntry(url: url, createdAt: Date())
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
        if let data = try? Data(contentsOf: fileURL) {
            // Try new format first: [String: PersistedEntry]
            if let dict = try? JSONDecoder().decode([String: PersistedEntry].self, from: data) {
                var out: [String: CacheEntry] = [:]
                for (k, v) in dict {
                    if let u = URL(string: v.url) {
                        let entry = CacheEntry(url: u, createdAt: Date(timeIntervalSince1970: v.createdAt))
                        out[k] = entry
                    }
                }
                self.cache = out
            } else if let legacy = try? JSONDecoder().decode([String: String].self, from: data) {
                // Legacy format: [id: urlString]. Treat as expired to force refresh.
                var out: [String: CacheEntry] = [:]
                for (k, v) in legacy {
                    if let u = URL(string: v) {
                        out[k] = CacheEntry(url: u, createdAt: .distantPast)
                    }
                }
                self.cache = out
            }
        }

        // Prune expired entries on startup
        pruneExpired()
        // Persist to transition legacy format or remove expired items
        Task { await persistToDisk() }
    }

    private func persistToDisk() async {
        let dict: [String: PersistedEntry] = cache.reduce(into: [:]) { acc, pair in
            acc[pair.key] = PersistedEntry(url: pair.value.url.absoluteString,
                                           createdAt: pair.value.createdAt.timeIntervalSince1970)
        }
        if let data = try? JSONEncoder().encode(dict) {
            try? data.write(to: fileURL, options: [.atomic])
        }
    }

    // MARK: - Expiry Helpers
    private func isExpired(_ entry: CacheEntry) -> Bool {
        return Date().timeIntervalSince(entry.createdAt) > Self.ttl
    }

    private func pruneExpired() {
        let before = cache.count
        cache = cache.filter { !isExpired($0.value) }
        let after = cache.count
        if before != after {
            // best-effort logging in debug builds
            #if DEBUG
            print("StreamURLCache: pruned \(before - after) expired entries")
            #endif
        }
    }
}
