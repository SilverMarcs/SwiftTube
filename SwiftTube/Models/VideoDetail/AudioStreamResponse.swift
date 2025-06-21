//
//  AudioStreamResponse.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 21/06/2025.
//

import Foundation

struct AudioStreamResponse: Codable {
    let url: String?
    let format: String?
    let quality: String?
    let mimeType: String?
    let codec: String?
    let audioTrackId: String?
    let audioTrackName: String?
    let audioTrackType: String?
    let audioTrackLocale: String?
    let videoOnly: Bool?
    let itag: Int?
    let bitrate: Int?
    let initStart: Int?
    let initEnd: Int?
    let indexStart: Int?
    let indexEnd: Int?
    let loudness: Double?
    let contentLength: Int?
}
