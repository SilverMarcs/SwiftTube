//
//  SwiftTubeApp.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 27/09/2025.
//

import SwiftUI
import SwiftData

@main
struct SwiftTubeApp: App {
    @State var videoManager = VideoManager()
    @State var shortsManager = ShortsManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(videoManager)
                .environment(shortsManager)
        }
        .modelContainer(for: [Channel.self, Video.self, Comment.self])
    }
}
