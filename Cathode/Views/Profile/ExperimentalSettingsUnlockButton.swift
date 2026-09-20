import SwiftUI

/// Matches FinStream's hidden seven-press area. Apple TV receives the unlock via iCloud.
struct ExperimentalSettingsUnlockButton: View {
    let settings: ExperimentalPlaybackSettings

    var body: some View {
        Button(action: settings.registerUnlockPress) {
            Color.clear
                .frame(height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("App information")
        .onDisappear { settings.resetUnlockProgress() }
    }
}
