//
//  PlaybackModeSettingsRow.swift
//  Cathode
//
//  Created by Zabir Raihan on 01/06/2026.
//

import SwiftUI

struct PlaybackModeSettingsRow: View {
    @AppStorage(VideoManager.playbackModeKey) private var playbackMode = PlaybackMode.remote

    var body: some View {
        Picker("Playback Mode", selection: $playbackMode) {
            ForEach(PlaybackMode.allCases) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        .pickerStyle(.menu)
    }
}
