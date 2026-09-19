import Foundation

nonisolated enum StreamResolutionError: Error, LocalizedError, Sendable {
    case cancelled
    case extraction(StreamExtractionError)
    case noPlayableSource
    case adaptivePreparation(String)
    case manifestServer(String)
    case broker(PlaybackBrokerError)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            "Playback loading was cancelled."
        case .extraction(let error):
            error.errorDescription
        case .noPlayableSource:
            "YouTube didn't return a playable stream for this video."
        case .adaptivePreparation:
            "The high-quality stream could not be prepared."
        case .manifestServer:
            "The local playback service could not be started."
        case .broker(let error):
            error.errorDescription
        }
    }
}
