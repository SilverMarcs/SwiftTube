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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(videoManager)
        }
        .modelContainer(for: [Channel.self, Video.self])
    }
}
