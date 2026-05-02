import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CloudStoreManager.self) private var store

    @State private var selected: Set<String> = []
    @State private var manualInput: String = ""
    @State private var isAdding = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("Channel ID or @handle", text: $manualInput)
                            .autocorrectionDisabled()
                            #if !os(macOS)
                            .textInputAutocapitalization(.never)
                            #endif
                            .onSubmit { Task { await addManual() } }

                        Button {
                            Task { await addManual() }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .buttonStyle(.borderless)
                        .disabled(manualInput.trimmingCharacters(in: .whitespaces).isEmpty || isAdding)
                    }
                } header: {
                    Text("Add Manually")
                } footer: {
                    Text("Paste a channel ID (UC...) or @handle. Added immediately.")
                }

                ForEach(StarterChannelCategory.allCases, id: \.self) { category in
                    Section {
                        ForEach(category.channels) { channel in
                            Button {
                                toggle(channel.handle)
                            } label: {
                                HStack {
                                    Text(channel.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: selected.contains(channel.handle) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selected.contains(channel.handle) ? .accent : .secondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(isAdding)
                        }
                    } header: {
                        Label(category.rawValue, systemImage: category.icon)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Channels")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                #if !os(macOS)
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { dismiss() }
                        .disabled(isAdding)
                }
                #endif
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await addSelected() }
                    } label: {
                        if isAdding {
                            ProgressView()
                        } else {
                            Text("Add Selected")
                        }
                    }
                    .disabled(selected.isEmpty || isAdding)
                }
            }
            .interactiveDismissDisabled(isAdding)
        }
    }

    private func toggle(_ handle: String) {
        if selected.contains(handle) {
            selected.remove(handle)
        } else {
            selected.insert(handle)
        }
    }

    private func addManual() async {
        let raw = manualInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        isAdding = true
        defer { isAdding = false }
        if let channel = try? await fetchChannel(input: raw) {
            store.addChannel(channel)
            manualInput = ""
        }
    }

    private func addSelected() async {
        isAdding = true
        defer { isAdding = false }
        for handle in selected {
            if let channel = try? await YTService.fetchChannel(forHandle: handle) {
                store.addChannel(channel)
            }
        }
        dismiss()
    }

    private func fetchChannel(input: String) async throws -> Channel {
        if input.hasPrefix("@") {
            return try await YTService.fetchChannel(forHandle: input)
        }
        if input.contains("youtube.com/channel/"),
           let id = input.components(separatedBy: "youtube.com/channel/").last?.components(separatedBy: "/").first {
            return try await YTService.fetchChannel(byId: id)
        }
        if input.hasPrefix("UC") {
            return try await YTService.fetchChannel(byId: input)
        }
        return try await YTService.fetchChannel(forHandle: "@\(input)")
    }
}
