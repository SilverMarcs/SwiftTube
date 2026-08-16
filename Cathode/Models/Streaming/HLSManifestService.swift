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

    func isAvailable(at localURL: URL) async -> Bool {
        await server.healthCheck(matching: localURL)
    }

    private func ensureRunning() async throws {
        if await server.healthCheck() { return }

        let task: Task<Void, Error>
        let attemptID: UUID
        if let startTask, let startAttemptID {
            task = startTask
            attemptID = startAttemptID
        } else {
            attemptID = UUID()
            task = Task { try await server.start() }
            startTask = task
            startAttemptID = attemptID
        }

        do {
            try await task.value
            clearStartAttempt(ifCurrent: attemptID)
        } catch {
            clearStartAttempt(ifCurrent: attemptID)
            throw StreamResolutionError.manifestServer(String(describing: error))
        }
    }

    private func clearStartAttempt(ifCurrent attemptID: UUID) {
        guard startAttemptID == attemptID else { return }
        startTask = nil
        startAttemptID = nil
    }
}
