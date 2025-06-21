//
//  NavigationDestinations.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 21/06/2025.
//

import SwiftUI

extension View {
    func navigationDestinations() -> some View {
        self
            .navigationDestination(for: Video.self) { video in
                VideoPlayerView(video: video)
            }
            .navigationDestination(for: Channel.self) { channel in
                ChannelView(channel: channel)
            }
    }
}
