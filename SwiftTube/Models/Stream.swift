import Foundation

struct Stream: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let quality: String
    let format: String
    let bitrate: Int?
    let isVideoOnly: Bool
    let codec: String?
    
    init(
        url: URL,
        quality: String,
        format: String,
        bitrate: Int? = nil,
        isVideoOnly: Bool = false,
        codec: String? = nil
    ) {
        self.url = url
        self.quality = quality
        self.format = format
        self.bitrate = bitrate
        self.isVideoOnly = isVideoOnly
        self.codec = codec
    }
    
    var qualityDescription: String {
        if let bitrate = bitrate {
            return "\(quality) (\(bitrate)kbps)"
        } else {
            return quality
        }
    }
}

struct VideoStreams {
    let videoStreams: [Stream]
    let audioStreams: [Stream]
    let hlsURL: URL?
    
    var bestVideoStream: Stream? {
        // Return the highest quality video stream
        videoStreams.sorted { first, second in
            let firstHeight = Int(first.quality.replacingOccurrences(of: "p", with: "")) ?? 0
            let secondHeight = Int(second.quality.replacingOccurrences(of: "p", with: "")) ?? 0
            return firstHeight > secondHeight
        }.first
    }
    
    var bestAudioStream: Stream? {
        // Return the highest bitrate audio stream
        audioStreams.sorted { first, second in
            (first.bitrate ?? 0) > (second.bitrate ?? 0)
        }.first
    }
}
