//
//  ProfileView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 29/09/2025.
//

import SwiftUI
import SwiftMediaViewer

struct ProfileView: View {
    @State private var authManager = GoogleAuthManager.shared
    
    @State private var deleteAlertPresented = false
    @Environment(UserDefaultsManager.self) var userDefaults
    @AppStorage("youtubeAPIKey") private var apiKey = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SignInView()
                        .alignmentGuide(.listRowSeparatorLeading) { _ in
                             return 0
                         }
                    
                    TextField("YouTube API Key", text: $apiKey)
                        .autocorrectionDisabled()
                } footer: {
                    Text("API Key is used over signin info when it is added")
                }
                
                Section {
                    NavigationLink {
                        ChannelListView()
                    } label: {
                        Label("Channels", systemImage: "bell")
                    }
                }
                
                WatchLaterView()
                
                HistoryView()
                
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
            .contentMargins(.top, 5)
            .task {
                try? await authManager.fetchUserInfo()
            }
            .navigationTitle("Profile")
            .toolbarTitleDisplayMode(.inlineLarge)
        }
    }
}
