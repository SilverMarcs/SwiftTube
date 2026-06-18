//
//  AppCommands.swift
//  SwiftTube
//

import SwiftUI

struct AppCommands: Commands {
    @Binding var selectedTab: TabSelection

    var body: some Commands {
        CommandGroup(before: .toolbar) {
            ForEach(TabSelection.commandTabs, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Label(tab.title, systemImage: tab.systemImage)
                }
                .modifier(OptionalShortcut(key: tab.shortcutKey))
            }
        }
    }
}

/// Applies a Command keyboard shortcut only when a non-empty key string is provided.
/// Guards against `Character("")`, which is a fatal error when a tab has no shortcut.
private struct OptionalShortcut: ViewModifier {
    let key: String?

    func body(content: Content) -> some View {
        if let key, let character = key.first {
            content.keyboardShortcut(KeyEquivalent(character), modifiers: [.command])
        } else {
            content
        }
    }
}
