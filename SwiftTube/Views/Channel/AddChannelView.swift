// AddChannelView.swift
import SwiftUI
import SwiftData

struct AddChannelView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var channelInput = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Channel ID or @handle", text: $channelInput)
                        .autocorrectionDisabled()
                } footer: {
                    Text("**Finding Channel ID:**\n• From URL: youtube.com/channel/UC... (copy the UC part)\n• From handle: @channelname\n• From old username URLs")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Channel")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addChannel()
                    }
                    .disabled(channelInput.isEmpty || isLoading)
                }
            }
            .overlay {
                if isLoading {
                  UniversalProgressView()
                }
            }
        }
    }
    
    private func addChannel() {
        let cleanInput = channelInput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Extract channel ID from various URL formats
        let channelId = extractChannelId(from: cleanInput) ?? cleanInput
        
        isLoading = true
        defer {  isLoading = false }
        
        Task {
            do {
                let channel = try await fetchChannel(channelId: channelId)
                modelContext.upsertChannel(channel)
                dismiss()
            } catch {
                print("Error adding channel: \(error)")
            }
        }
    }
    
    private func extractChannelId(from input: String) -> String? {
        // Handle full YouTube URLs
        if input.contains("youtube.com/channel/") {
            return input.components(separatedBy: "youtube.com/channel/").last?.components(separatedBy: "/").first
        }
        
        return nil
    }
    
    private func fetchChannel(channelId: String) async throws -> Channel {
        if channelId.hasPrefix("@") {
            return try await fetchChannelFromHandle(from: channelId)
        } else {
            return try await fetchChannelInfo(channelId: channelId)
        }
    }
    
    private func fetchChannelFromHandle(from handle: String) async throws -> Channel {
        let trimmed = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.hasPrefix("@") ? trimmed : "@\(trimmed)"
        return try await YTService.fetchChannel(forHandle: normalized)
    }
    
    private func fetchChannelInfo(channelId: String) async throws -> Channel {
        return try await YTService.fetchChannel(byId: channelId)
    }
}
