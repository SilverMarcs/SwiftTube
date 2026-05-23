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
    #if os(tvOS)
    @AppStorage("tvOSNavigationStyle") private var tvNavigationStyleSetting = TVNavigationStyle.tabBar
    #endif

    var body: some View {
        SettingsSplitView {
            form
        } infoPanel: {
            VStack(spacing: 16) {
                Image(systemName: "play.tv.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .foregroundStyle(.tint)
                Text("Cathode")
                    .font(.system(size: 56, weight: .bold))
            }
        }
    }

    private var form: some View {
        Form {
            Section {
                YTTVSignInView()
                    #if !os(tvOS)
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                    #endif
            }

            Section("Watch History Sync") {
                YTCookieAuthRow()
            }

            #if os(tvOS)
            Section("View Options") {
                Button {
                    tvNavigationStyleSetting = tvNavigationStyleSetting.next()
                } label: {
                    LabeledContent("Tab Style", value: tvNavigationStyleSetting.title)
                }
            }
            #endif

            Section("Cache") {
                CacheManagerView()
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .platformNavigationToolbar(titleDisplayMode: .inline)
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(role: .close) {
                    dismiss()
                }
            }
        }
        #endif
    }
}

#Preview {
    SettingsView()
}
