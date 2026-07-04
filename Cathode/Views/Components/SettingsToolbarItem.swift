import SwiftUI

extension View {
    /// On iOS, adds a Settings gear to the primary toolbar slot that presents
    /// `SettingsView` in a sheet. No-op on other platforms, where Settings is its
    /// own sidebar tab.
    @ViewBuilder
    func iosSettingsToolbarItem() -> some View {
        #if os(iOS)
        modifier(IOSSettingsToolbarModifier())
        #else
        self
        #endif
    }
}

#if os(iOS)
private struct IOSSettingsToolbarModifier: ViewModifier {
    @State private var showingSettings = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                // iPhone only — on iPad, Settings is a sidebar tab.
                if Device.isIPhone {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingSettings = true
                        } label: {
                            Label("Settings", systemImage: "gear")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                NavigationStack {
                    SettingsView()
                }
            }
    }
}
#endif
