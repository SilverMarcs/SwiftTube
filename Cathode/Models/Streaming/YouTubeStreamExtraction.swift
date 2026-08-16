import Foundation

nonisolated struct YouTubeStreamExtraction: Sendable {
    struct NativeHLS: Sendable {
        let url: URL
        let clientKind: YouTubeStream.ClientKind
        let requestHeaders: [String: String]
    }

    let streams: [YouTubeStream]
    let nativeHLS: NativeHLS?
}
