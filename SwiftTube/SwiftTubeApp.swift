//
//  SwiftTubeApp.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 27/09/2025.
//

import SwiftUI

@main
struct SwiftTubeApp: App {
    #if !os(macOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    
    @State var videoLoader = VideoLoader()
    @State var videoManager = VideoManager()
    @State var shortsManager = ShortsManager()
    @State var userDefaultsManager = UserDefaultsManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(videoLoader)
                .environment(videoManager)
                .environment(shortsManager)
                .environment(userDefaultsManager)
        }
    }
}
