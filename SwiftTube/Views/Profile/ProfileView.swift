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
                    CacheManagerView()
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
