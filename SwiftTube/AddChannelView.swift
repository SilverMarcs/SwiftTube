// AddChannelView.swift
import SwiftUI
import SwiftData

struct AddChannelView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var channelInput = ""
    @State private var isLoading = false
    
    private let apiKey = "AIzaSyCrI9toXHrVQXmx1ZwKc9hkhTBZM94k-do" // Replace with your API key
    private let baseURL = "https://www.googleapis.com/youtube/v3"
    
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
        
        Task {
            do {
                let channel = try await fetchChannel(channelId: channelId)
                modelContext.upsertChannel(channel)
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                print("Error adding channel: \(error)")
                await MainActor.run {
                    isLoading = false
                }
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
        guard let encoded = normalized.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw APIError.invalidResponse
        }
        let url = URL(string: "\(baseURL)/channels?part=snippet,contentDetails&forHandle=\(encoded)&key=\(apiKey)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let res = try JSONDecoder().decode(ChannelResponse.self, from: data)
        guard let item = res.items.first else {
            throw APIError.channelNotFound
        }
        return Channel(
            id: item.id,
            title: item.snippet.title,
            channelDescription: item.snippet.description,
            thumbnailURL: item.snippet.thumbnails.medium.url,
            uploadsPlaylistId: item.contentDetails.relatedPlaylists.uploads
        )
    }
    
    private func fetchChannelInfo(channelId: String) async throws -> Channel {
        let url = URL(string: "\(baseURL)/channels?part=snippet,contentDetails&id=\(channelId)&key=\(apiKey)")!
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(ChannelResponse.self, from: data)
        
        guard let item = response.items.first else {
            throw APIError.channelNotFound
        }
        
        return Channel(
            id: item.id,
            title: item.snippet.title,
            channelDescription: item.snippet.description,
            thumbnailURL: item.snippet.thumbnails.medium.url,
            uploadsPlaylistId: item.contentDetails.relatedPlaylists.uploads
        )
    }
}
