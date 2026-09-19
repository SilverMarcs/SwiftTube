import Foundation

nonisolated enum PlaybackBrokerError: Error, LocalizedError, Sendable, Equatable {
    case invalidConfiguration
    case notConfigured
    case invalidVideoID
    case unavailable
    case rejected(statusCode: Int)
    case invalidResponse
    case downloadsUnsupported

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            "Enter an HTTPS server address (or a local-network HTTP address) and an API key."
        case .notConfigured:
            "Set the playback server address and API key in Settings, or wait for iCloud sync to finish."
        case .invalidVideoID:
            "This video cannot be requested from the playback server."
        case .unavailable:
            "The token service could not be reached. Please try again later."
        case .rejected:
            "The token service rejected this request. Check the API key or try again shortly."
        case .invalidResponse:
            "The token service returned an invalid response."
        case .downloadsUnsupported:
            "Downloads are unavailable while Use Playback Server is enabled."
        }
    }
}
