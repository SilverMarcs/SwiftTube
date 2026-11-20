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
    @AppStorage(ShortPlaybackModel.fastLoadingKey) private var fastShortsLoading = false

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
                Toggle("Faster Loading", isOn: $fastShortsLoading)
                    #if os(tvOS)
                    .foregroundStyle(.primary)
                    #endif
            } header: {
                Text("Shorts")
            } footer: {
                Text("Plays Shorts at 360p and skips HD stream preparation so they start sooner.")
            }

            Section("Cache") {
                CacheManagerView()
            }

        }
        .tint(.accent)
        .formStyle(.grouped)
        #if os(iOS)
        .platformTopBar("Settings", titleDisplayMode: Device.isIPhone ? .inline : .inlineLarge) {
            if Device.isIPhone {
                Button(role: .close) {
                    dismiss()
                }
            }
        }
        #else
        .platformTopBar("Settings")
        #endif
    }
}

#Preview {
    SettingsView()
}
