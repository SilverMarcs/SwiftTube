#if os(iOS)
//
//  DownloadActivityCoordinator.swift
//  Cathode
//

#if os(iOS)
import Foundation
import BackgroundTasks

/// Wraps a single `BGContinuedProcessingTask` that umbrella-tracks every
/// in-flight download. While this task is alive the system keeps the app
/// running past suspension, which means our regular foreground `URLSession`
/// downloads keep going at full speed. Progress is surfaced to the user as a
/// system-provided Live Activity (title / subtitle / progress bar) which they
/// can also use to cancel.
@MainActor
final class DownloadActivityCoordinator {
    static let shared = DownloadActivityCoordinator()

    static let taskIdentifier = "com.SilverMarcs.SwiftTube.downloads"

    private struct Tracked {
        var name: String
        /// Expected total bytes for this download. May be 0 if unknown at
        /// start; we substitute a placeholder so the bar still makes visible
        /// progress, and update once `didWriteData` reports a real size.
        var expectedSize: Int64
        var bytesWritten: Int64
    }

    /// Used when we don't yet know the expected size — gives the bar
    /// something large enough to crawl across without falsely hitting 100%
    /// for any realistic download.
    private static let unknownSizeFallback: Int64 = 1_000_000_000  // 1 GB

    private var activeTask: BGContinuedProcessingTask?
    private var tracked: [String: Tracked] = [:]

    private init() {}

    /// Call once at app launch (before any task is submitted).
    static func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: .main
        ) { task in
            guard let continued = task as? BGContinuedProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            MainActor.assumeIsolated {
                shared.adopt(task: continued)
            }
        }
    }

    // MARK: - Lifecycle hooks called from DownloadManager

    func startTracking(itemID: String, name: String, expectedSize: Int64 = 0) {
        if tracked[itemID] == nil {
            let effective = expectedSize > 0 ? expectedSize : Self.unknownSizeFallback
            tracked[itemID] = Tracked(name: name, expectedSize: effective, bytesWritten: 0)
        }
        ensureTaskRunning()
        refreshActivity()
    }

    func updateProgress(itemID: String, bytesWritten: Int64, totalExpected: Int64) {
        guard var t = tracked[itemID] else { return }
        t.bytesWritten = bytesWritten
        if totalExpected > 0 {
            t.expectedSize = totalExpected
        }
        tracked[itemID] = t
        refreshActivity()
    }

    func stopTracking(itemID: String, success: Bool = true) {
        guard tracked.removeValue(forKey: itemID) != nil else { return }
        if tracked.isEmpty {
            if success, let task = activeTask {
                // Snap the bar to full just before teardown so the user sees a
                // definite "done" frame on the Live Activity.
                task.progress.completedUnitCount = task.progress.totalUnitCount
            }
            activeTask?.setTaskCompleted(success: success)
            activeTask = nil
        } else {
            refreshActivity()
        }
    }

    // MARK: - Internal

    private func ensureTaskRunning() {
        guard activeTask == nil else { return }
        let request = BGContinuedProcessingTaskRequest(
            identifier: Self.taskIdentifier,
            title: title,
            subtitle: subtitle
        )
        // `.queue` lets iOS queue the request rather than reject it under
        // resource pressure — without an explicit strategy the system can
        // refuse to launch the task at all.
        request.strategy = .queue
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // The download itself still proceeds; we just lose the
            // background-life-extension benefit. Most common failure: the
            // identifier isn't in BGTaskSchedulerPermittedIdentifiers.
            print("BGContinuedProcessingTask submit failed: \(error)")
        }
    }

    private func adopt(task: BGContinuedProcessingTask) {
        activeTask = task
        task.expirationHandler = { [weak self] in
            // System (or user via Live Activity) is asking us to stop. Cancel
            // every in-flight download; the manager will tear down each
            // URLSessionDownloadTask.
            Task { @MainActor in
                guard let self else { return }
                let ids = Array(self.tracked.keys)
                for id in ids {
                    DownloadManager.shared.cancel(id)
                }
                self.tracked.removeAll()
                self.activeTask = nil
            }
        }
        refreshActivity()
    }

    private func refreshActivity() {
        guard let task = activeTask else { return }

        let totalUnits = tracked.values.reduce(Int64(0)) { $0 + $1.expectedSize }
        let writtenUnits = tracked.values.reduce(Int64(0)) { $0 + $1.bytesWritten }
        let safeTotal = max(totalUnits, 1)
        let cap = max(safeTotal - 1, 1)

        task.progress.totalUnitCount = safeTotal
        task.progress.completedUnitCount = min(writtenUnits, cap)

        task.updateTitle(title, subtitle: subtitle)
    }

    private var title: String {
        let count = tracked.count
        if count == 0 { return "Downloads" }
        if count == 1 { return "Downloading" }
        return "Downloading \(count) items"
    }

    private var subtitle: String {
        if tracked.isEmpty { return "" }
        if tracked.count == 1, let only = tracked.values.first {
            return only.name
        }
        let names = tracked.values.map(\.name).sorted()
        guard let first = names.first else { return "" }
        return "\(first) and \(names.count - 1) more"
    }
}
#endif
#endif
