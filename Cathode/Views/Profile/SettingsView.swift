//
//  SettingsView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 15/10/2025.
//

import SwiftUI
import SwiftMediaViewer

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss


    var body: some View {
        SettingsSplitView {
            form
        } infoPanel: {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.tint)
                .frame(width: 450, height: 450)
                .shadow(radius: 12)
        }
    }

    private var form: some View {
        Form {
            Section {
                YTTVSignInView()
                    #if os(tvOS)
                    .foregroundStyle(.primary)
                    #else
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                    #endif
            }

            Section("Watch History Sync") {
                YTCookieAuthRow()
                    #if os(tvOS)
                    .foregroundStyle(.primary)
                    #endif
            }

            Section {
                PlaybackModeSettingsRow()
            } header: {
                Text("Playback")
            }

            Section("Cache") {
                CacheManagerView()
            }
        }
        .formStyle(.grouped)
        #if os(iOS)
        .platformTopBar("Settings", titleDisplayMode: .inline) {
            Button(role: .close) {
                dismiss()
            }
        }
        #else
        .platformTopBar("Settings", titleDisplayMode: .inline)
        #endif
    }
}

#Preview {
    SettingsView()
}
