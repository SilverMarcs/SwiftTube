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
    #if os(iOS)
    @State private var showingSettings = false
    #endif

    var body: some View {
        Form {
            BookmarkView()

            HistoryView()

            #if os(iOS)
            DownloadsPreviewView()
            #endif
        }
        .formStyle(.grouped)
        .contentMargins(.top, 5)
        .navigationTitle("Library")
        .platformNavigationToolbar()
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSettings = true
                } label: {
                    Label("Settings", systemImage: "gear")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
            }
        }
        #endif
    }
}
