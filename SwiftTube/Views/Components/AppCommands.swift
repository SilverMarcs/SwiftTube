//
//  AppCommands.swift
//  SwiftTube
//

import SwiftUI

struct AppCommands: Commands {
    @Binding var selectedTab: TabSelection
    
    var body: some Commands {
        CommandGroup(before: .toolbar) {
            ForEach(TabSelection.allCases, id: \.self) { tab in
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
