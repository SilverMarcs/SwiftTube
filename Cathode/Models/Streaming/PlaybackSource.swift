import Foundation

nonisolated struct PlaybackSource: Sendable {
    enum Kind: Hashable, Sendable {
        case nativeHLS
        case progressive
        case adaptiveHLS
    }

    let url: URL
    let expiresAt: Date?
    let kind: Kind
    let httpUserAgent: String?
    let strategy: PlaybackStrategy?
    /// Metadata from the same `/player` response the media came from.
    let details: PlayerVideoDetails?

    /// Keeps namespaced localhost manifests alive for as long as this source
    /// belongs to an installed player item.
    private let manifestLease: HLSManifestLease?

    var dependsOnManifestServer: Bool {
        manifestLease != nil
    }

    private init(
        url: URL, expiresAt: Date?, kind: Kind, httpUserAgent: String?,
        manifestLease: HLSManifestLease?, strategy: PlaybackStrategy? = nil,
        details: PlayerVideoDetails? = nil
    ) {
        self.url = url
        self.expiresAt = expiresAt
        self.kind = kind
        self.httpUserAgent = httpUserAgent
        self.manifestLease = manifestLease
        self.strategy = strategy
        self.details = details
    }

    func using(_ strategy: PlaybackStrategy, details: PlayerVideoDetails?) -> Self {
        Self(url: url, expiresAt: expiresAt, kind: kind, httpUserAgent: httpUserAgent,
             manifestLease: manifestLease, strategy: strategy, details: details)
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
