//
//  PlaybackModeSettingsRow.swift
//  Cathode
//
//  Created by Zabir Raihan on 01/06/2026.
//

import SwiftUI

struct PlaybackModeSettingsRow: View {
    @AppStorage(VideoManager.playbackModeKey) private var playbackMode = PlaybackMode.simplified

    var body: some View {
        #if os(tvOS)
        Button {
            if playbackMode == .simplified {
                playbackMode = .remote
            } else {
                playbackMode = .simplified
            }
        } label: {
            LabeledContent("Playback Mode", value: playbackMode.displayName)
        }
        .foregroundStyle(.primary)
        #else
        Picker("Playback Mode", selection: $playbackMode) {
            ForEach(PlaybackMode.allCases) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        .pickerStyle(.menu)
        #endif
    }
}
