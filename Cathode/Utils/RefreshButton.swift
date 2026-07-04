import SwiftUI

/// Icon-only refresh button intended for `platformTopBar` trailing slots.
/// Hidden on iOS (pull-to-refresh covers it); ⌘R on macOS.
struct RefreshButton: View {
    let action: () async -> Void

    var body: some View {
        #if !os(iOS)
        Button {
            Task { await action() }
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
                .labelStyle(.iconOnly)
        }
        #if os(tvOS)
        .tint(.primary)
        #endif
        #if os(macOS)
        .keyboardShortcut("r")
        #endif
        #endif
    }
}
