//
//  SwiftTubeApp.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 20/06/2025.
//

import SwiftUI
import Kingfisher

@main
struct SwiftTubeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    
    init() {
        ImageCache.default.memoryStorage.config.totalCostLimit = 1024 * 1024 * 60 // 60 MB
        ImageCache.default.diskStorage.config.sizeLimit = 1024 * 1024 * 300 // 300 MB
        ImageCache.default.diskStorage.config.expiration = .days(2) // 1 day
    }
}
