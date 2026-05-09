//
//  YouTubeVideoThumbnail.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 27/09/2025.
//

import Foundation

enum YouTubeThumbnailResolution: String {
    case `default` = "default"
    case medium = "mqdefault"
    case high = "hqdefault"
    case standard = "sddefault"
    case maximum = "maxresdefault"
}

struct YouTubeVideoThumbnail {
    let videoID: String
    let resolution: YouTubeThumbnailResolution

    var url: URL? {
        let urlString = "https://img.youtube.com/vi/\(videoID)/\(resolution.rawValue).jpg"
        return URL(string: urlString)
    }

    init(videoID: String, resolution: YouTubeThumbnailResolution = .maximum) {
        self.videoID = videoID
        self.resolution = resolution
    }
}
