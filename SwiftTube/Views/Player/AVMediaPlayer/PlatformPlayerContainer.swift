//
//  PlatformPlayerContainer.swift
//  SwiftJelly
//
//  Created by Zabir Raihan on 09/10/2025.
//

import SwiftUI
import AVKit

struct PlatformPlayerContainer: View {
    let player: AVPlayer

    var body: some View {
        #if os(macOS)
        AVPlayerMac(player: player)
        #else
        AVPlayerIos(player: player)
        #endif
    }
}
