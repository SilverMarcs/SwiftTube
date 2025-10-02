//
//  SettingsView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 27/09/2025.
//

import SwiftUI
import SwiftMediaViewer
import SwiftData

struct SettingsView: View {
    @State private var deleteAlertPresented = false
    @Environment(\.modelContext) var modelContext
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
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                
                #if DEBUG
                Section("Data Management") {
                    Button("Delete All Videos") {
                        if let videos = try? modelContext.fetch(FetchDescriptor<Video>()) {
                            videos.forEach { modelContext.delete($0) }
                        }
                    }
                    
                    Button("Delete All Channels") {
                        if let channels = try? modelContext.fetch(FetchDescriptor<Channel>()) {
                            channels.forEach { modelContext.delete($0) }
                        }
                    }
                    
                    Button("Delete All Comments") {
                        if let comments = try? modelContext.fetch(FetchDescriptor<Comment>()) {
                            comments.forEach { modelContext.delete($0) }
                        }
                    }
                }
                #endif
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .toolbarTitleDisplayMode(.inline)
        }
    }
}
