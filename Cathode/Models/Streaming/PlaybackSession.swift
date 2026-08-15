import Foundation

struct PlaybackLoadToken: Equatable {
    let sessionID: UUID
    let loadID: UUID
    let videoID: String
}

struct PlaybackSession {
    enum Intent {
        case playing
        case paused
    }

    enum LoadReason {
        case initial
        case automaticRecovery(attempt: Int)
        case manualRetry
        case expirationRefresh
    }

    enum Phase {
        case resolving(LoadReason)
        case installing(LoadReason)
        case ready
        case failed(PlaybackFailure)

        var isLoading: Bool {
            switch self {
            case .resolving, .installing: true
            case .ready, .failed: false
            }
        }
    }

    let id = UUID()
    let videoID: String
    private(set) var loadID = UUID()
    var phase: Phase
    var intent: Intent
    var source: PlaybackSource?
    var position = PlaybackPositionState()
    var recovery = PlaybackRecoveryPolicy()
    private var itemReachedReady = false
    private var installationCompleted = false

    init(videoID: String, autoPlay: Bool) {
        self.videoID = videoID
        phase = .resolving(.initial)
        intent = autoPlay ? .playing : .paused
    }

    mutating func beginLoad(reason: LoadReason) -> PlaybackLoadToken {
        loadID = UUID()
        phase = .resolving(reason)
        itemReachedReady = false
        installationCompleted = false
        return currentToken
    }

    mutating func markItemReady() {
        itemReachedReady = true
        recovery.markItemReady()
        publishReadyIfPossible()
    }

    mutating func markInstallationCompleted() {
        installationCompleted = true
        publishReadyIfPossible()
    }

    var currentToken: PlaybackLoadToken {
        PlaybackLoadToken(sessionID: id, loadID: loadID, videoID: videoID)
    }

    func matches(_ token: PlaybackLoadToken) -> Bool {
        currentToken == token
    }

    private mutating func publishReadyIfPossible() {
        guard itemReachedReady, installationCompleted else { return }
        phase = .ready
    }
}
