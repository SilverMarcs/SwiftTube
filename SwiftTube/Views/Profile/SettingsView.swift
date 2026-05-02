//
//  SettingsView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 15/10/2025.
//

import SwiftUI
import SwiftMediaViewer

struct SettingsView: View {
    @State private var fetchingSettings = FetchingSettings()
    @Environment(\.dismiss) var dismiss
    @AppStorage("showGoogleAuth") private var showGoogleAuth = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var easterEggTapCount = 0

    var body: some View {
        Form {
            Section {
                Toggle("Prefer Local Fetching", isOn: $fetchingSettings.useLocalFetching)
                    .help(
                        "When enabled, tries to fetch videos locally first before falling back to remote. Local fetching may be slower but doesn't require internet."
                    )
            } header: {
                Text("Fetching")
            } footer: {
                Text("Non local fetching is more reliable but will take longer to laod videos")
            }

            Section("Cache") {
                CacheManagerView()
            }

            Section {
                Button("Show Onboarding Again") {
                    hasCompletedOnboarding = false
                    dismiss()
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(role: .close) { dismiss() }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear
                .frame(height: 44)
                .contentShape(Rectangle())
                .onTapGesture {
                    easterEggTapCount += 1
                    if easterEggTapCount >= 7 {
                        showGoogleAuth = true
                        easterEggTapCount = 0
                    }
                }
        }
    }
}

#Preview {
    SettingsView()
}
