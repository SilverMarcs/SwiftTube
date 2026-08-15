import Foundation

enum PlaybackSourceSelector {
    struct AdaptivePair: Sendable {
        let video: YouTubeStream
        let audio: YouTubeStream
    }

    private static let adaptiveVideoItags: Set<Int> = [134, 135, 136, 137, 298, 299]
    private static let adaptiveAudioItags: Set<Int> = [139, 140]
    private static let progressiveItags: Set<Int> = [18, 22]

    static func adaptivePair(from streams: [YouTubeStream]) -> AdaptivePair? {
        guard let video = streams
            .filter({ adaptiveVideoItags.contains($0.itag) })
            .filter(\.isNativelyPlayable)
            .filter({ $0.includesVideo && !$0.includesAudio })
            .max(by: videoQualityAscending),
              let audio = streams
            .filter({ adaptiveAudioItags.contains($0.itag) })
            .filter(\.isNativelyPlayable)
            .filter({ $0.includesAudio && !$0.includesVideo })
            .max(by: { $0.bitrate < $1.bitrate })
        else { return nil }

        return AdaptivePair(video: video, audio: audio)
    }

    static func progressive(from streams: [YouTubeStream]) -> YouTubeStream? {
        streams
            .filter({ progressiveItags.contains($0.itag) })
            .filter(\.isNativelyPlayable)
            .filter({ $0.includesVideo && $0.includesAudio })
            .max(by: videoQualityAscending)
    }

    private static func videoQualityAscending(_ lhs: YouTubeStream, _ rhs: YouTubeStream) -> Bool {
        let left = (lhs.height ?? 0, lhs.bitrate)
        let right = (rhs.height ?? 0, rhs.bitrate)
        return left < right
    }
}
