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

    #if !os(tvOS)
    @AppStorage(VideoManager.alwaysUseIframeKey) private var alwaysUseIframe = false
    #endif

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

            #if !os(tvOS)
            Section {
                Toggle("Always Use Iframe Player", isOn: $alwaysUseIframe)
            } header: {
                Text("Playback")
            } footer: {
                Text("Skips stream resolution and plays videos directly in an embedded YouTube player. Playback starts faster but uses YouTube's built-in controls.")
            }
            #endif

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
