//
//  SettingsView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 27/09/2025.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("youtubeAPIKey") private var apiKey = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("API Key", text: $apiKey)
                        .autocorrectionDisabled()
//                        .textInputAutocapitalization(.never)
                } footer: {
                    Text("Enter your YouTube Data API v3 key. Get one from [Google Cloud Console](https://console.cloud.google.com/).")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .toolbarTitleDisplayMode(.inline)
        }
    }
}
