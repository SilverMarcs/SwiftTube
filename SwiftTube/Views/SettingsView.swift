//
//  SettingsView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 27/09/2025.
//

import SwiftUI
import SwiftMediaViewer

struct SettingsView: View {
    @State private var deleteAlertPresented = false
    @Environment(UserDefaultsManager.self) var userDefaults
    @AppStorage("youtubeAPIKey") private var apiKey = ""
    
    var body: some View {
        NavigationStack {
            Form {
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
                
                
                Section("API") {
                    TextField("YouTube API Key", text: $apiKey)
                        .autocorrectionDisabled()
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .toolbarTitleDisplayMode(.inline)
        }
    }
}
