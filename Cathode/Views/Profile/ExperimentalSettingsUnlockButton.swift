import SwiftUI

/// Matches FinStream's seven-press area below the settings form. A button also
/// supports keyboard, VoiceOver, and the Apple TV remote.
struct ExperimentalSettingsUnlockButton: View {
    let settings: ExperimentalPlaybackSettings

    var body: some View {
        Button(action: settings.registerUnlockPress) {
            #if os(tvOS)
            Text("Cathode \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                .foregroundStyle(.secondary)
            #else
            Color.clear
                .frame(height: 44)
                .contentShape(.rect)
            #endif
        }
        .buttonStyle(.plain)
        .accessibilityLabel("App information")
        .onDisappear { settings.resetUnlockProgress() }
    }
}
