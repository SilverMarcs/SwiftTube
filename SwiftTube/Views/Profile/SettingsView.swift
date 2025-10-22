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
        NavigationStack {
            Form {
                Section("Fetching") {
                    Toggle("Prefer Local Fetching", isOn: $fetchingSettings.useLocalFetching)
                        .help(
                            "When enabled, tries to fetch videos locally first before falling back to remote. Local fetching may be slower but doesn't require internet."
                        )
                }

                Section("Cache") {
                    CacheManagerView()
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .toolbarTitleDisplayMode(.inline)
            #if !os(macOS)
            .toolbar {
                Button(role: .close) {
                    dismiss()
                }
            }
            #endif
        }
    }
}

#Preview {
    SettingsView()
}
