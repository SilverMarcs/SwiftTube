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
    @AppStorage("youtubeAPIKey") private var apiKey = ""

    var body: some View {
        Form {
            Section {
                SignInView()
                    .alignmentGuide(.listRowSeparatorLeading) { _ in
                        return 0
                    }

                SecureField("YouTube API Key", text: $apiKey)
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
        }
        .formStyle(.grouped)
        .contentMargins(.top, 5)
        .task {
            try? await authManager.fetchUserInfo()
        }
        .navigationTitle("Profile")
        .toolbarTitleDisplayMode(.inlineLarge)
        #if os(iOS)
        .modifier(SettingsModifier())
        #endif
    }
}
