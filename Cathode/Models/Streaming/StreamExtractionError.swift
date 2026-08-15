import Foundation

enum StreamExtractionError: Error, LocalizedError, Sendable {
    case cancelled
    case invalidResponse
    case network(String)
    case unavailable(String)
    case noStreams
    case cipheredFormatsOnly

    var errorDescription: String? {
        switch self {
        case .cancelled:
            "Stream extraction was cancelled."
        case .invalidResponse:
            "YouTube returned an invalid player response."
        case .network:
            "YouTube could not be reached."
        case .unavailable(let reason):
            reason
        case .noStreams:
            "YouTube did not return any media streams."
        case .cipheredFormatsOnly:
            "YouTube returned only encrypted stream URLs."
        }
    }
}
