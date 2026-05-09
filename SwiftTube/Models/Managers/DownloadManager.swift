//
//  DownloadManager.swift
//  SwiftTube
//

import Foundation
import SwiftUI

@Observable
final class DownloadManager: NSObject {
    static let shared = DownloadManager()

    static let sessionIdentifier = "com.SilverMarcs.SwiftTube.downloads"

    private(set) var downloadedVideos: [Video] = []
    private(set) var downloadingVideos: [Video] = []
    private(set) var progress: [String: Double] = [:]

    private let dir: URL

    @ObservationIgnored
    private var tasks: [String: URLSessionDownloadTask] = [:]
    @ObservationIgnored
    private var cancellingIds: Set<String> = []

    @ObservationIgnored
    var backgroundCompletionHandler: (() -> Void)?

    @ObservationIgnored
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    override private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        dir = base.appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        super.init()
        loadDownloaded()
        rehydrateActiveDownloads()
    }

    func localURL(for id: String) -> URL? {
        let url = videoFileURL(for: id)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func isDownloaded(_ id: String) -> Bool {
        localURL(for: id) != nil
    }

    func isDownloading(_ id: String) -> Bool {
        downloadingVideos.contains(where: { $0.id == id })
    }

    func progressValue(for id: String) -> Double {
        progress[id] ?? 0
    }

    @MainActor
    func download(_ video: Video) async {
        guard !isDownloaded(video.id), !isDownloading(video.id) else { return }

        guard let streamURL = await StreamURLCache.shared.fetch(id: video.id) else {
            print("Download: no stream for \(video.id)")
            return
        }

        do {
            let data = try JSONEncoder().encode(video)
            try data.write(to: metadataURL(for: video.id))
        } catch {
            print("Download: failed to write metadata for \(video.id): \(error)")
            return
        }

        withAnimation {
            downloadingVideos.append(video)
        }
        progress[video.id] = 0

        let task = session.downloadTask(with: streamURL)
        task.taskDescription = video.id
        tasks[video.id] = task
        task.resume()
    }

    func cancel(_ id: String) {
        guard let task = tasks[id] else { return }
        cancellingIds.insert(id)
        progress[id] = nil
        withAnimation {
            downloadingVideos.removeAll { $0.id == id }
        }
        task.cancel()
        // Metadata removal happens in didCompleteWithError once the system
        // confirms the cancel, so a racing didFinishDownloadingTo can't move
        // a stranded .mp4 into place.
    }

    func delete(_ id: String) {
        if isDownloading(id) {
            cancel(id)
            return
        }
        try? FileManager.default.removeItem(at: videoFileURL(for: id))
        try? FileManager.default.removeItem(at: metadataURL(for: id))
        withAnimation {
            downloadedVideos.removeAll { $0.id == id }
        }
    }

    private func videoFileURL(for id: String) -> URL {
        dir.appendingPathComponent("\(id).mp4")
    }

    private func metadataURL(for id: String) -> URL {
        dir.appendingPathComponent("\(id).json")
    }

    private func loadVideoMetadata(for id: String) -> Video? {
        let url = metadataURL(for: id)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Video.self, from: data)
    }

    private func loadDownloaded() {
        let decoder = JSONDecoder()
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        var videos: [Video] = []
        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let video = try? decoder.decode(Video.self, from: data),
                  isDownloaded(video.id) else { continue }
            videos.append(video)
        }
        downloadedVideos = videos
    }

    private func rehydrateActiveDownloads() {
        session.getAllTasks { [weak self] sessionTasks in
            guard let self else { return }
            let pairs: [(String, URLSessionDownloadTask)] = sessionTasks.compactMap { task in
                guard let id = task.taskDescription, let dl = task as? URLSessionDownloadTask else { return nil }
                return (id, dl)
            }
            Task { @MainActor in
                for (id, dl) in pairs {
                    self.tasks[id] = dl
                    if let video = self.loadVideoMetadata(for: id),
                       !self.downloadingVideos.contains(where: { $0.id == id }) {
                        self.downloadingVideos.append(video)
                    }
                }
            }
        }
    }
}

extension DownloadManager: URLSessionDownloadDelegate {
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task { @MainActor in
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let id = downloadTask.taskDescription, totalBytesExpectedToWrite > 0 else { return }
        let value = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        Task { @MainActor in
            self.progress[id] = value
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let id = downloadTask.taskDescription else { return }

        // Cancel raced ahead — drop the temp file (system cleans it up) and finish cleanup.
        if cancellingIds.contains(id) {
            Task { @MainActor in
                self.cleanupDownloadingState(id: id)
                try? FileManager.default.removeItem(at: self.metadataURL(for: id))
                self.cancellingIds.remove(id)
            }
            return
        }

        let dest = videoFileURL(for: id)
        try? FileManager.default.removeItem(at: dest)
        do {
            try FileManager.default.moveItem(at: location, to: dest)
        } catch {
            print("Download: failed to move file for \(id): \(error)")
            Task { @MainActor in
                self.cleanupDownloadingState(id: id)
            }
            return
        }

        let video = loadVideoMetadata(for: id)
        Task { @MainActor in
            self.cleanupDownloadingState(id: id)
            if let video, !self.downloadedVideos.contains(where: { $0.id == id }) {
                withAnimation {
                    self.downloadedVideos.append(video)
                }
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let id = task.taskDescription else { return }
        // Success: didFinishDownloadingTo already moved the file and cleaned up.
        guard let error else { return }
        let isCancel = (error as NSError).code == NSURLErrorCancelled
        if !isCancel {
            print("Download failed for \(id): \(error)")
        }
        Task { @MainActor in
            self.cleanupDownloadingState(id: id)
            try? FileManager.default.removeItem(at: self.metadataURL(for: id))
            try? FileManager.default.removeItem(at: self.videoFileURL(for: id))
            self.cancellingIds.remove(id)
        }
    }

    @MainActor
    private func cleanupDownloadingState(id: String) {
        tasks[id] = nil
        progress[id] = nil
        withAnimation {
            downloadingVideos.removeAll { $0.id == id }
        }
    }
}
