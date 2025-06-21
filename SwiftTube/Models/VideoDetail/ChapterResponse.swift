//
//  ChapterResponse.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 21/06/2025.
//

import Foundation

struct ChapterResponse: Codable {
    let title: String?
    let image: String?
    let start: Double?
    
    func toChapter() -> Chapter? {
        guard let title = title, let start = start else { return nil }
        return Chapter(
            title: title,
            startTime: start,
            thumbnailURL: image.flatMap { URL(string: $0) }
        )
    }
}
