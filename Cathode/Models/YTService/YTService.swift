//
//  YTService.swift
//  Cathode
//
//  Thin facade over `InnerTubeAPI.shared`. Public static functions live in
//  the `YTService+*.swift` extensions and convert ITVideo/ITChannel/ITComment
//  results into Cathode's existing Video/Channel/Comment shapes so call sites
//  don't have to change.
//

import Foundation

enum YTService {
    // ISO8601 formatter retained as a small shared helper still used by callers.
    static let isoFormatter = ISO8601DateFormatter()
}
