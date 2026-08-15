import Foundation

struct YouTubeStream: Sendable {
    enum MediaKind: Sendable {
        case audio
        case video
    }

    let url: URL
    let itag: Int
    let mediaKind: MediaKind
    let codecs: [String]
    let bitrate: Int
    let height: Int?
    let includesAudio: Bool
    let includesVideo: Bool
    let requestHeaders: [String: String]

    var videoCodec: String? {
        codecs.first { $0.hasPrefix("avc1.") || $0.hasPrefix("av01.") }
    }

    var audioCodec: String? {
        codecs.first { $0.hasPrefix("mp4a.") }
    }

    var isNativelyPlayable: Bool {
        let videoIsPlayable = !includesVideo || videoCodec != nil
        let audioIsPlayable = !includesAudio || audioCodec != nil
        return videoIsPlayable && audioIsPlayable
    }
}
