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
    @State private var easterEggTapCount = 0

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
        .safeAreaInset(edge: .bottom) {
            Color.clear
                .frame(height: 44)
                .contentShape(Rectangle())
                .onTapGesture {
                    easterEggTapCount += 1
                    if easterEggTapCount >= 7 {
                        showGoogleAuth = true
                        easterEggTapCount = 0
                    }
                }
        }
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
