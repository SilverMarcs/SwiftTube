//
//  PlaybackMode.swift
//  Cathode
//
//  Created by Zabir Raihan on 01/06/2026.
//

import Foundation

enum PlaybackMode: String, CaseIterable, Identifiable {
    case remote = "remote"
    #if !os(tvOS)
    case iframe = "iframe"
    #endif

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .remote:
            return "Remote HLS"
        #if !os(tvOS)
        case .iframe:
            return "Iframe Player"
        #endif
        }
    }
}
