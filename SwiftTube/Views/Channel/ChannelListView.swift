// ChannelListView.swift
import SwiftUI
import SwiftMediaViewer

struct ChannelListView: View {
    @Environment(CloudStoreManager.self) private var userDefaults
    @AppStorage("youtubeAPIKey") private var apiKey = ""

    @State private var showingAddChannel = false
    @State private var subscriptions: [Channel] = []
    @State private var isLoadingSubscriptions = false
    @State private var searchText = ""
    
    @Environment(GoogleAuthManager.self) private var authManager
    
    // Filter subscriptions that aren't already saved as channels
    private var availableSubscriptions: [Channel] {
        let channelIds = Set(channels.map { $0.id })
        return subscriptions.filter { !channelIds.contains($0.id) }
    }
    
    private var channels: [Channel] {
        let allChannels = userDefaults.savedChannels
        if searchText.isEmpty {
            return allChannels
        } else {
            return allChannels.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    private var filteredSubscriptions: [Channel] {
        availableSubscriptions.filter { searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section("Subscriptions") {
                    if availableSubscriptions.isEmpty {
                        #if os(macOS)
                        Text("Subscriptions not loaded yet")
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(.secondary)
                        #else
                        if authManager.isSignedIn && apiKey.isEmpty {
                            Button {
                                Task { await loadSubscriptions() }
                            } label: {
                                Label("Load Subscriptions", systemImage: "arrow.clockwise")
                            }
                            .disabled(isLoadingSubscriptions)
                        }
                        #endif
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
                            .listRowSeparator(.hidden, edges: .top)
                            .listRowSeparator(.visible, edges: .bottom)
                        }
                    }
                }
                
                if !channels.isEmpty {
                    Section("Saved Channels") {
                        ForEach(channels) { channel in
                            ChannelRowView(channel: channel)
                        }
                        .onDelete(perform: deleteChannels)
                        .listRowSeparator(.hidden, edges: .top)
                        .listRowSeparator(.visible, edges: .bottom)
                    }
                }
            }
            #if os(macOS)
            .searchable(text: $searchText, placement: .toolbarPrincipal, prompt: "Search channels and subscriptions")
            #else
            .searchable(text: $searchText, prompt: "Search channels and subscriptions")
            #endif
            .refreshable {
                await refreshChannels()
            }
            .navigationTitle("Channels")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                #if os(macOS)
                if authManager.isSignedIn && apiKey.isEmpty {
                    ToolbarItem {
                        Button {
                            Task { await loadSubscriptions() }
                        } label: {
                            Label("Load Subs", systemImage: "arrow.clockwise")
                                .labelStyle(.titleOnly)
                        }
                        .disabled(isLoadingSubscriptions)
                    }
                }
                #endif
                
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
            userDefaults.removeChannel(channels[index])
        }
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
        userDefaults.addChannel(subscription)
    }

    private func refreshChannels() async {
        let allChannels = userDefaults.savedChannels
        guard !allChannels.isEmpty else { return }

        do {
            let updatedChannels = try await YTService.fetchChannels(byIds: allChannels.map { $0.id })
            for channel in updatedChannels {
                userDefaults.updateChannel(channel)
            }
        } catch {
            print("Error refreshing channels: \(error.localizedDescription)")
        }
    }
}
