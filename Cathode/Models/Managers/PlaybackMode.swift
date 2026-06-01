//
//  PlaybackMode.swift
//  Cathode
//
//  Created by Zabir Raihan on 01/06/2026.
//

import Foundation

enum PlaybackMode: String, CaseIterable, Identifiable {
    case simplified = "simplified"
    case remote = "remote"
    #if !os(tvOS)
    case iframe = "iframe"
    #endif

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .simplified:
            return "Simplified"
        case .remote:
            return "Remote HLS"
        #if !os(tvOS)
        case .iframe:
            return "Iframe Player"
        #endif
        }
    }
}
