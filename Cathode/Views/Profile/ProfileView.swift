//
//  ProfileView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 29/09/2025.
//

import SwiftMediaViewer
import SwiftUI

struct ProfileView: View {
    @Environment(CloudStoreManager.self) var userDefaults

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    ChannelListView()
                } label: {
                    Label("Channels", systemImage: "bell")
                }

                #if os(iOS)
                NavigationLink {
                    DownloadsView()
                } label: {
                    Label("Downloads", systemImage: "arrow.down.circle")
                }
                #endif
            }

            BookmarkView()

            HistoryView()
        }
        .formStyle(.grouped)
        .contentMargins(.top, 5)
        .navigationTitle("Profile")
        .platformNavigationToolbar()
    }
}
