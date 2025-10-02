// ChannelListView.swift
import SwiftUI
import SwiftData
import SwiftMediaViewer

struct ChannelListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Channel.title) private var allChannels: [Channel]
    @State private var showingAddChannel = false
    @State private var subscriptions: [Channel] = []
    @State private var isLoadingSubscriptions = false
    @State private var searchText = ""
    
    private var authManager = GoogleAuthManager.shared
    
    // Filter subscriptions that aren't already saved as channels
    private var availableSubscriptions: [Channel] {
        let channelIds = Set(channels.map { $0.id })
        return subscriptions.filter { !channelIds.contains($0.id) }
    }
    
    private var channels: [Channel] {
        if searchText.isEmpty {
            allChannels
        } else {
            allChannels.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    private var filteredSubscriptions: [Channel] {
        availableSubscriptions.filter { searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if authManager.isSignedIn {
                    Section {
                        if availableSubscriptions.isEmpty {
                            Button(isLoadingSubscriptions ? "Loading..." : "Load Subscriptions") {
                                Task { await loadSubscriptions() }
                            }
                            .disabled(isLoadingSubscriptions)
                            .frame(maxWidth: .infinity)
                        } else {
                            ForEach(filteredSubscriptions) { subscription in
                                HStack {
                                    ChannelRowView(channel: subscription)
                                        .navigationLinkIndicatorVisibility(.hidden)
                                    
                                    Spacer()
                                    
                                    Button {
                                        addSubscriptionAsChannel(subscription)
                                    } label: {
                                        Image(systemName: "plus")
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.blue)
                                    .buttonBorderShape(.circle)
                                }
                            }
                        }
                    }
                }
                
                if !channels.isEmpty {
                    Section("Saved Channels") {
                        ForEach(channels) { channel in
                            ChannelRowView(channel: channel)
                        }
                        .onDelete(perform: deleteChannels)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search channels and subscriptions")

            .refreshable {
                await refreshChannels()
            }
            .navigationTitle("Channels")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddChannel = true
                    } label: {
                        Label("Add Channel", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddChannel) {
                AddChannelView()
                    .presentationDetents([.medium])
            }
        }
    }
    
    private func deleteChannels(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(channels[index])
        }
        try? modelContext.save()
    }
    
    private func loadSubscriptions() async {
        isLoadingSubscriptions = true
        defer { isLoadingSubscriptions = false }
        
        do {
            let fetchedSubscriptions = try await YTService.fetchMySubscriptions()
            subscriptions = fetchedSubscriptions.sorted { $0.title < $1.title }
        } catch {
            print("Error loading subscriptions: \(error.localizedDescription)")
        }
    }
    
    private func addSubscriptionAsChannel(_ subscription: Channel) {
        let channel = Channel(
            id: subscription.id,
            title: subscription.title,
            channelDescription: subscription.channelDescription,
            thumbnailURL: subscription.thumbnailURL
        )
        
        modelContext.insert(channel)
        try? modelContext.save()
    }

    @MainActor
    private func refreshChannels() async {
        guard !allChannels.isEmpty else { return }

        do {
            let updatedChannels = try await YTService.fetchChannels(byIds: allChannels.map { $0.id })
            for channel in updatedChannels {
                modelContext.upsertChannel(channel)
            }
        } catch {
            print("Error refreshing channels: \(error.localizedDescription)")
        }
    }
}
