// AddChannelView.swift
import SwiftUI

struct AddChannelView: View {
    @Environment(\.dismiss) private var dismiss
    let channelStore: ChannelStore
    
    @State private var channelInput = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Channel Information") {
                    TextField("Channel ID or @handle", text: $channelInput)
//                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                
                Section {
                    Text("**Finding Channel ID:**\n• From URL: youtube.com/channel/UC... (copy the UC part)\n• From handle: @channelname\n• From old username URLs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Channel")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Add") {
                        addChannel()
                    }
                    .disabled(channelInput.isEmpty || isLoading)
                }
            }
            .overlay {
                if isLoading {
                    ProgressView("Adding Channel...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
        }
    }
    
    private func addChannel() {
        let cleanInput = channelInput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Extract channel ID from various URL formats
        let channelId = extractChannelId(from: cleanInput) ?? cleanInput
        
        isLoading = true
        
        Task {
            await channelStore.addChannel(channelId: channelId)
            await MainActor.run {
                isLoading = false
                dismiss()
            }
        }
    }
    
    private func extractChannelId(from input: String) -> String? {
        // Handle full YouTube URLs
        if input.contains("youtube.com/channel/") {
            return input.components(separatedBy: "youtube.com/channel/").last?.components(separatedBy: "/").first
        }
        
        // Handle @handles - return as-is, API will handle it
        if input.hasPrefix("@") {
            return input
        }
        
        return nil
    }
}
