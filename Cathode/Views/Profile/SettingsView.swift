//
//  SettingsView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 15/10/2025.
//

import SwiftUI
import SwiftMediaViewer

struct SettingsView: View {
    @Environment(GoogleAuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss
    @AppStorage("showGoogleAuth") private var showGoogleAuth = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    #if os(tvOS)
    @AppStorage("tvOSNavigationStyle") private var tvNavigationStyleSetting = TVNavigationStyle.tabBar
    #endif
    @State private var easterEggTapCount = 0

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
            if showGoogleAuth {
                Section {
                    SignInView()
                        #if !os(tvOS)
                        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                        #endif
                }
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

            Section {
                Button("Show Onboarding Again") {
                    hasCompletedOnboarding = false
                    bumpEasterEgg()
                }
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
        .task {
            if showGoogleAuth {
                try? await authManager.fetchUserInfo()
            }
        }
    }

    private func bumpEasterEgg() {
        easterEggTapCount += 1
        if easterEggTapCount >= 15 {
            showGoogleAuth = true
            easterEggTapCount = 0
        }
    }
}

#Preview {
    SettingsView()
}
