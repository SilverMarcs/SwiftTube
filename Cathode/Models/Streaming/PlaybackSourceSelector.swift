import Foundation

nonisolated enum PlaybackSourceSelector {
    struct AdaptivePair: Sendable {
        let video: YouTubeStream
        let audio: YouTubeStream
    }

    private static let adaptiveVideoItags: Set<Int> = [134, 135, 136, 137, 298, 299]
    private static let adaptiveAudioItags: Set<Int> = [139, 140]
    private static let progressiveItags: Set<Int> = [18, 22]

    static func adaptivePairs(from streams: [YouTubeStream]) -> [AdaptivePair] {
        let clients = Set(streams.map(\.clientKind)).sorted {
            clientPriority($0) < clientPriority($1)
        }
        return clients.compactMap { clientKind in
            let clientStreams = streams.filter { $0.clientKind == clientKind }
            guard let video = clientStreams
                .filter({ adaptiveVideoItags.contains($0.itag) })
                .filter(\.isNativelyPlayable)
                .filter({ $0.includesVideo && !$0.includesAudio })
                .max(by: videoQualityAscending),
                  let audio = clientStreams
                .filter({ adaptiveAudioItags.contains($0.itag) })
                .filter(\.isNativelyPlayable)
                .filter({ $0.includesAudio && !$0.includesVideo })
                .max(by: audioPreferenceAscending)
            else { return nil }
            return AdaptivePair(video: video, audio: audio)
        }
    }

    static func progressive(from streams: [YouTubeStream]) -> YouTubeStream? {
        streams
            .filter({ progressiveItags.contains($0.itag) })
            .filter(\.isNativelyPlayable)
            .filter({ $0.includesVideo && $0.includesAudio })
            .max(by: videoQualityAscending)
    }

    static func preferredAudioTrack(
        from streams: [YouTubeStream]
    ) -> YouTubeAudioTrackMetadata? {
        streams
            .filter { $0.includesAudio && !$0.includesVideo && !$0.isDRC }
            .compactMap(\.audioTrack)
            .max {
                audioTrackPreference(for: $0) < audioTrackPreference(for: $1)
            }
    }

    private static func videoQualityAscending(_ lhs: YouTubeStream, _ rhs: YouTubeStream) -> Bool {
        let left = (lhs.height ?? 0, lhs.bitrate)
        let right = (rhs.height ?? 0, rhs.bitrate)
        return left < right
    }

    private static func audioPreferenceAscending(_ lhs: YouTubeStream, _ rhs: YouTubeStream) -> Bool {
        let leftPreference = audioPreference(for: lhs)
        let rightPreference = audioPreference(for: rhs)
        if leftPreference != rightPreference {
            return leftPreference < rightPreference
        }

        if lhs.isDRC != rhs.isDRC {
            return lhs.isDRC
        }
        return lhs.bitrate < rhs.bitrate
    }

    private static func audioPreference(for stream: YouTubeStream) -> Int {
        guard let track = stream.audioTrack else { return 2 }
        return audioTrackPreference(for: track)
    }

    private static func audioTrackPreference(
        for track: YouTubeAudioTrackMetadata
    ) -> Int {
        if track.isOriginal { return 4 }
        if track.primaryLanguageCode == "en" { return 3 }
        if !track.isAutoDubbed { return 1 }
        return 0
    }

    private static func clientPriority(_ clientKind: YouTubeStream.ClientKind) -> Int {
        switch clientKind {
        case .mwebPO:
            -1
        case .visionOS:
            0
        case .authenticatedTV:
            1
        case .authenticatedWebSafari:
            2
        case .android:
            3
        }
    }
}
