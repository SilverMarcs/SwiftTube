//
//  AppCommands.swift
//  SwiftTube
//

import SwiftUI

struct AppCommands: Commands {
    @Binding var selectedTab: TabSelection
    @AppStorage("showGoogleAuth") private var showGoogleAuth = false

    var body: some Commands {
        CommandGroup(before: .toolbar) {
            ForEach(TabSelection.allCases.filter { $0 != .search || showGoogleAuth }, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Label(tab.title, systemImage: tab.systemImage)
                }
                .keyboardShortcut(
                    KeyEquivalent(Character(tab.shortcutKey ?? "")),
                    modifiers: [.command]
                )
            }
        }
    }
}
