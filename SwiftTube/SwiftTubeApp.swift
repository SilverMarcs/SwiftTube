//
//  SwiftTubeApp.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 27/09/2025.
//

import SwiftUI

struct ChannelStoreKey: EnvironmentKey {
    static let defaultValue: ChannelStore = ChannelStore()
}

extension EnvironmentValues {
    var channelStore: ChannelStore {
        get { self[ChannelStoreKey.self] }
        set { self[ChannelStoreKey.self] = newValue }
    }
}

@main
struct SwiftTubeApp: App {
    @State private var channelStore = ChannelStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.channelStore, channelStore)
        }
    }
}
