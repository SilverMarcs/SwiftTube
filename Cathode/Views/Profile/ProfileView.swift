//
//  ProfileView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 29/09/2025.
//

import SwiftMediaViewer
import SwiftUI

struct ProfileView: View {
    @Environment(LibraryStore.self) var userDefaults

    var body: some View {
        Form { // TODO: use list view here
            BookmarkView()

            HistoryView()

            #if os(iOS)
            DownloadsPreviewView()
            #endif
        }
        .formStyle(.grouped)
        .contentMargins(.top, 5)
        .platformTopBar("Library")
        .iosSettingsToolbarItem()
    }
}
