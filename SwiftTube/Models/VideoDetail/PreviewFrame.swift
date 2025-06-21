//
//  PreviewFrame.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 21/06/2025.
//

import Foundation

struct PreviewFrame: Codable {
    let urls: [String]?
    let frameHeight: Int?
    let totalCount: Int?
    let framesPerPageY: Int?
    let frameWidth: Int?
    let durationPerFrame: Int?
    let framesPerPageX: Int?
}
