//
//  ProfileView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 29/09/2025.
//

import SwiftMediaViewer
import SwiftUI

struct ProfileView: View {
    @Environment(GoogleAuthManager.self) private var authManager
    @Environment(CloudStoreManager.self) var userDefaults
    @AppStorage("showGoogleAuth") private var showGoogleAuth = false

    var body: some View {
        Form {
            if showGoogleAuth {
                Section {
                    SignInView()
                        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                }
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
        }
        .formStyle(.grouped)
        .contentMargins(.top, 5)
        .task {
            if showGoogleAuth {
                try? await authManager.fetchUserInfo()
            }
        }
        .navigationTitle("Profile")
        .toolbarTitleDisplayMode(.inlineLarge)
        #if os(iOS)
        .modifier(SettingsModifier())
        #endif
    }
}
