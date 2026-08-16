import Foundation

nonisolated struct PlaybackSource: Sendable {
    enum Kind: Hashable, Sendable {
        case local
        case nativeHLS
        case progressive
        case adaptiveHLS
    }

    let url: URL
    let expiresAt: Date?
    let kind: Kind
    let httpUserAgent: String?

    /// Keeps namespaced localhost manifests alive for as long as this source
    /// belongs to an installed player item.
    private let manifestLease: HLSManifestLease?

    var dependsOnManifestServer: Bool {
        manifestLease != nil
    }

    static func local(url: URL) -> PlaybackSource {
        PlaybackSource(
            url: url,
            expiresAt: nil,
            kind: .local,
            httpUserAgent: nil,
            manifestLease: nil
        )
    }

    static func progressive(url: URL, expiresAt: Date) -> PlaybackSource {
        PlaybackSource(
            url: url,
            expiresAt: expiresAt,
            kind: .progressive,
            httpUserAgent: nil,
            manifestLease: nil
        )
    }

    static func nativeHLS(
        url: URL,
        expiresAt: Date,
        httpUserAgent: String?
    ) -> PlaybackSource {
        PlaybackSource(
            url: url,
            expiresAt: expiresAt,
            kind: .nativeHLS,
            httpUserAgent: httpUserAgent,
            manifestLease: nil
        )
    }

    static func nativeHLS(
        lease: HLSManifestLease,
        expiresAt: Date,
        httpUserAgent: String?
    ) -> PlaybackSource {
        PlaybackSource(
            url: lease.url,
            expiresAt: expiresAt,
            kind: .nativeHLS,
            httpUserAgent: httpUserAgent,
            manifestLease: lease
        )
    }

    static func adaptive(lease: HLSManifestLease, expiresAt: Date) -> PlaybackSource {
        PlaybackSource(
            url: lease.url,
            expiresAt: expiresAt,
            kind: .adaptiveHLS,
            httpUserAgent: nil,
            manifestLease: lease
        )
    }
}
