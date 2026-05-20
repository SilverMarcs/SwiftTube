//
//  YouTubeVideoThumbnail.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 27/09/2025.
//

import Foundation

enum YouTubeThumbnailResolution: String {
    case `default` = "default"
    case medium = "mqdefault"     // 320×180, 16:9 clean
    case hd720 = "hq720"          // 1280×720, 16:9 clean — universally available
    case high = "hqdefault"       // 480×360, 4:3 with letterbox bars baked in — avoid
    case standard = "sddefault"   // 640×480, 4:3 with letterbox bars baked in — avoid
    case maximum = "maxresdefault" // 1280×720+, 16:9 clean but only if uploader supplied a custom thumb
    case shortsPortrait = "oardefault" // 9:16 portrait, Shorts only
}

struct YouTubeVideoThumbnail {
    let videoID: String
    let resolution: YouTubeThumbnailResolution

    var url: URL? {
        let urlString = "https://i.ytimg.com/vi/\(videoID)/\(resolution.rawValue).jpg"
        return URL(string: urlString)
    }

    /// Default resolution is `hd720` — the highest-resolution 16:9 variant that exists
    /// for every video on the CDN. `maxresdefault` only exists when the uploader
    /// provided a custom thumbnail; `hqdefault`/`sddefault` are 4:3 with letterbox
    /// bars baked into the JPEG and should not be used for video cards.
    init(videoID: String, resolution: YouTubeThumbnailResolution = .hd720) {
        self.videoID = videoID
        self.resolution = resolution
    }
}
