//
//  SearchItemRow.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 21/06/2025.
//

import SwiftUI

struct SearchItemRow: View {
    let item: SearchItem
    
    var body: some View {
        switch item {
        case .video(let video):
            VideoRow(video: video)
                .listRowInsets(.vertical, 7)
                .listRowInsets(.horizontal, 10)
                .listRowSeparator(.hidden)
                .navigationLinkIndicatorVisibility(.hidden)
        case .channel(let channel):
            ChannelRowContent(channel: channel)
                .navigationLinkIndicatorVisibility(.visible)
        case .playlist(let playlist):
            PlaylistRowContent(playlist: playlist)
        }
    }
}
