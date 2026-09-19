import SwiftUI

struct ExperimentalPlaybackSection: View {
    @Bindable var settings: ExperimentalPlaybackSettings

    var body: some View {
        if settings.isUnlocked {
            Section {
                Toggle("Use PO Token Service", isOn: $settings.isServerPlaybackEnabled)
                if settings.isServerPlaybackEnabled {
                    PlaybackServiceFields(settings: settings)
                }
            } header: {
                Text("Experimental")
            } footer: {
                Text("Settings sync automatically across your iCloud devices. Applies to newly opened videos.")
            }
        }
    }
}
