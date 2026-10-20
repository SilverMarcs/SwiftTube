/// The remote playback attempts are ordered and never cycle automatically.
nonisolated enum PlaybackStrategy: CaseIterable, Sendable {
    case authenticatedEmbedded
    case visionOS

    var next: Self? {
        switch self {
        case .authenticatedEmbedded: .visionOS
        case .visionOS: nil
        }
    }
}
