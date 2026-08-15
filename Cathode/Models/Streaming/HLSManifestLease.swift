import Foundation

/// Keeps one namespaced set of HLS manifests registered for as long as its
/// player can still request them.
final class HLSManifestLease: @unchecked Sendable {
    let url: URL

    private let releaseRegistration: () -> Void

    init(url: URL, releaseRegistration: @escaping () -> Void) {
        self.url = url
        self.releaseRegistration = releaseRegistration
    }

    deinit {
        releaseRegistration()
    }
}
