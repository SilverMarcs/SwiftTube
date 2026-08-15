import Foundation

struct YouTubeStreamExtraction: Sendable {
    let streams: [YouTubeStream]
    let nativeHLSManifestURL: URL?
}
