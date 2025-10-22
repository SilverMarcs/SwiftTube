//
//  FetchingSettings.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 15/10/2025.
//

import SwiftUI
import YouTubeKit

struct FetchingSettings {
    @AppStorage("useLocalFetching") var useLocalFetching: Bool = false

    var methods: [YouTube.ExtractionMethod] {
        useLocalFetching ? [.local, .remote] : [.remote, .local]
    }
}
