import Foundation

enum PlaybackFailure: Error, LocalizedError, Sendable {
    case stream(StreamResolutionError)
    case player(String?)

    var errorDescription: String? {
        switch self {
        case .stream(let error):
            error.errorDescription
        case .player(let reason):
            reason ?? "The video stopped playing unexpectedly."
        }
    }
}
