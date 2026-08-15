import Foundation

struct PlaybackSource: Sendable {
    enum Kind: Hashable, Sendable {
        case local
        case nativeHLS
        case progressive
        case adaptiveHLS
    }

    let url: URL
    let expiresAt: Date?
    let kind: Kind

    /// Synthesized adaptive HLS is backed by CDN URLs that may require byte
    /// ranges to be consumed sequentially. Native HLS, progressive MP4, and
    /// local files can safely open at an arbitrary saved playhead.
    var supportsArbitrarySeeking: Bool {
        kind != .adaptiveHLS
    }

    /// Keeps namespaced localhost manifests alive for as long as this source
    /// belongs to an installed player item.
    private let manifestLease: HLSManifestLease?

    static func local(url: URL) -> PlaybackSource {
        PlaybackSource(url: url, expiresAt: nil, kind: .local, manifestLease: nil)
    }

    static func progressive(url: URL, expiresAt: Date) -> PlaybackSource {
        PlaybackSource(url: url, expiresAt: expiresAt, kind: .progressive, manifestLease: nil)
    }

    static func nativeHLS(url: URL, expiresAt: Date) -> PlaybackSource {
        PlaybackSource(url: url, expiresAt: expiresAt, kind: .nativeHLS, manifestLease: nil)
    }

    static func adaptive(lease: HLSManifestLease, expiresAt: Date) -> PlaybackSource {
        PlaybackSource(url: lease.url, expiresAt: expiresAt, kind: .adaptiveHLS, manifestLease: lease)
    }
}
