import Foundation

/// Owns listener health and registration. The actor serializes restarts while
/// `HLSProxyServer` keeps socket callbacks on its dedicated Network queue.
actor HLSManifestService {
    static let shared = HLSManifestService()

    private let server = HLSProxyServer()
    private var startTask: Task<Void, Error>?
    private var startAttemptID: UUID?

    func register(
        videoURL: URL,
        videoInfo: FMP4Info,
        videoCodec: String,
        videoBandwidth: Int,
        videoRequestHeaders: [String: String],
        audioURL: URL,
        audioInfo: FMP4Info,
        audioCodec: String,
        audioRequestHeaders: [String: String]
    ) async throws -> HLSManifestLease {
        try await ensureRunning()
        guard let lease = server.register(
            videoURL: videoURL,
            videoInfo: videoInfo,
            videoCodec: videoCodec,
            videoBandwidth: videoBandwidth,
            videoRequestHeaders: videoRequestHeaders,
            audioURL: audioURL,
            audioInfo: audioInfo,
            audioCodec: audioCodec,
            audioRequestHeaders: audioRequestHeaders
        ) else {
            throw StreamResolutionError.manifestServer("Unable to create a localhost manifest URL.")
        }
        return lease
    }

    func registerNativeMaster(
        _ manifest: String,
        requestHeaders: [String: String]
    ) async throws -> HLSManifestLease {
        try await ensureRunning()
        guard let lease = server.registerNativeMaster(
            manifest,
            requestHeaders: requestHeaders
        ) else {
            throw StreamResolutionError.manifestServer(
                "Unable to create a localhost native HLS manifest URL."
            )
        }
        return lease
    }

    /// Restores the listener at the port already embedded throughout an
    /// installed AVPlayer item's HLS graph. Keeping that port stable lets the
    /// existing item continue without a new extraction or item replacement.
    /// Returns `false` only when transparent restoration is impossible; a
    /// listener on a fresh port is prepared before returning so fallback
    /// registration can proceed immediately.
    func restoreIfNeeded(at localURL: URL) async -> Bool {
        if await server.healthCheck(matching: localURL) { return true }

        guard localURL.host == "127.0.0.1",
              let rawPort = localURL.port,
              let port = UInt16(exactly: rawPort)
        else { return false }

        // Another recovery may already have established a healthy listener on
        // a new port. Do not tear it down and invalidate its fresh registrations.
        if await server.healthCheck() { return false }

        for attempt in 0..<3 {
            do {
                try await startServer(on: port)
                if await server.healthCheck(matching: localURL) {
                    return true
                }
            } catch {
                // The defunct listener's port can take a moment to become
                // reusable. Keep the installed player item untouched while a
                // few short, bounded same-port attempts finish.
            }
            if attempt < 2 {
                try? await Task.sleep(for: .milliseconds(150 * (attempt + 1)))
            }
        }

        // Fall back to a fresh port for the slower item-rebuild path instead
        // of leaving the manifest service unavailable.
        try? await startServer(on: nil)
        return false
    }

    private func ensureRunning() async throws {
        if await server.healthCheck() { return }

        do {
            try await startServer(on: nil)
        } catch {
            throw StreamResolutionError.manifestServer(String(describing: error))
        }
    }

    private func startServer(on preferredPort: UInt16?) async throws {
        let task: Task<Void, Error>
        let attemptID: UUID
        if let startTask, let startAttemptID {
            task = startTask
            attemptID = startAttemptID
        } else {
            attemptID = UUID()
            task = Task { try await server.start(on: preferredPort) }
            startTask = task
            startAttemptID = attemptID
        }

        do {
            try await task.value
            clearStartAttempt(ifCurrent: attemptID)
        } catch {
            clearStartAttempt(ifCurrent: attemptID)
            throw error
        }
    }

    private func clearStartAttempt(ifCurrent attemptID: UUID) {
        guard startAttemptID == attemptID else { return }
        startTask = nil
        startAttemptID = nil
    }
}
