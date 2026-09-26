import Foundation

/// Tracking configuration from a player response whose account authentication
/// has been verified. Kept separate from media extraction, including PO tokens.
public nonisolated struct PlaybackTrackingURLs: Sendable {
    var sessionID: UUID? = nil
    public let playbackURL: URL
    public let watchtimeURL: URL
    public let usesPOST: Bool
}
