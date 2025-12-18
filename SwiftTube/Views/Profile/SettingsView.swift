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
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .toolbarTitleDisplayMode(.inlineLarge)
    }
}

#Preview {
    SettingsView()
}
