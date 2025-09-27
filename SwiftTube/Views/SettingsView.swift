//
//  SettingsView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 27/09/2025.
//

import SwiftUI
import SwiftMediaViewer

struct SettingsView: View {
    @AppStorage("youtubeAPIKey") private var apiKey = ""
    @State private var deleteAlertPresented = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("API Key", text: $apiKey)
                        .autocorrectionDisabled()
                    #if os(iOS)
                        .textInputAutocapitalization(.never)
                    #endif
                } header: {
                    Text("API Key")
                } footer: {
                    Text("Enter your YouTube Data API v3 key. Get one from [Google Cloud Console](https://console.cloud.google.com/).")
                }
                
                // TODO: put this view in swiftemdi viewer pakcage
                Section("Cache") {
                    Button {
                        deleteAlertPresented = true
                    } label: {
                        HStack {
                            Label {
                                Text("Clear Image Cache")
                            } icon: {
                                Image(systemName: "trash")
                            }
        //                    Spacer()
        //                    Text("{Cache Size}")
                        }
                        .contentShape(.rect)
                    }
                    #if os(macOS)
                    .buttonStyle(.plain)
                    #endif
                    .alert("Clear Image Cache", isPresented: $deleteAlertPresented) {
                        Button("Clear", role: .destructive) {
                            CachedAsyncImageConfiguration.clearAllCaches()
                        }
                        Button("Cancel", role: .cancel) { }
                    } message: {
                        Text("This will clear all cached images, freeing up storage space.")
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .toolbarTitleDisplayMode(.inlineLarge)
        }
    }
}
