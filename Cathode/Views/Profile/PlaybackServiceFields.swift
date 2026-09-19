import SwiftUI

struct PlaybackServiceFields: View {
    let settings: ExperimentalPlaybackSettings
    @State private var serverURL = ""
    @State private var apiKey = ""
    @State private var message: String?
    @FocusState private var isEditing: Bool

    var body: some View {
        Group {
            TextField("Server URL", text: $serverURL)
                .focused($isEditing)
            SecureField("API Key", text: $apiKey)
                .focused($isEditing)
            if let message { Text(message).foregroundStyle(.secondary) }
        }
        .autocorrectionDisabled()
        #if !os(macOS)
        .textInputAutocapitalization(.never)
        #endif
        .onSubmit(save)
        .onChange(of: isEditing) { _, editing in
            if !editing { save() }
        }
        .onDisappear(perform: save)
        .onChange(of: settings.serverURL, initial: true) { _, value in
            if !isEditing { serverURL = value }
        }
        .onChange(of: settings.apiKey, initial: true) { _, value in
            if !isEditing { apiKey = value }
        }
    }

    private func save() {
        guard serverURL != settings.serverURL || apiKey != settings.apiKey else { return }
        do {
            try settings.saveConnection(serverURL: serverURL, apiKey: apiKey)
            message = nil
        } catch {
            message = error.localizedDescription
        }
    }
}
