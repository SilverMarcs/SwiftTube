import SwiftUI

struct SettingsModifier: ViewModifier {
    @State var showSettings: Bool = false
    @Namespace private var transition

    func body(content: Content) -> some View {
        #if os(macOS)
        content
        #else
        content
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showSettings = true
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }
                }
                .matchedTransitionSource(id: "settings-button", in: transition)
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                        .presentationDetents([.medium])
                }
                .navigationTransition(.zoom(sourceID: "settings-button", in: transition))
            }
        #endif
    }
}
