import SwiftUI

/// Icon-only refresh button intended for `platformTopBar` trailing slots.
/// Hidden on iOS and macOS 27+ (pull-to-refresh covers it); ⌘R on older macOS.
struct RefreshButton: View {
    let action: () async -> Void

    var body: some View {
        #if os(macOS)
        if #unavailable(macOS 27) {
            button
                .keyboardShortcut("r")
        }
        #elseif !os(iOS)
        button
        #if os(tvOS)
            .tint(.primary)
        #endif
        #endif
    }

    private var button: some View {
        Button {
            Task { await action() }
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
                .labelStyle(.iconOnly)
        }
    }
}
