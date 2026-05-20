// ChannelListView.swift
import SwiftUI
import SwiftMediaViewer

struct ChannelListView: View {
    @Environment(CloudStoreManager.self) private var userDefaults

    @State private var showingAddChannel = false
    @State private var subscriptions: [Channel] = []
    @State private var isLoadingSubscriptions = false

    @Environment(YTTVAuthManager.self) private var authManager

    private var channels: [Channel] { userDefaults.savedChannels }

    // Filter subscriptions that aren't already saved as channels
    private var availableSubscriptions: [Channel] {
        let channelIds = Set(channels.map { $0.id })
        return subscriptions.filter { !channelIds.contains($0.id) }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if authManager.isSignedIn {
                    Section("Subscriptions") {
                        ForEach(availableSubscriptions) { subscription in
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
                            #if !os(tvOS)
                            .listRowSeparator(.hidden, edges: .top)
                            .listRowSeparator(.visible, edges: .bottom)
                            #endif
                        }

                        Button {
                            Task { await loadSubscriptions() }
                        } label: {
                            Label("Load Subscriptions", systemImage: "arrow.clockwise")
                        }
                        .disabled(isLoadingSubscriptions)
                        #if os(macOS)
                        .listRowSeparator(.hidden)
                        #endif
                    }
                }

                if !channels.isEmpty {
                    Section("Saved Channels") {
                        ForEach(channels) { channel in
                            ChannelRowView(channel: channel)
                        }
                        .onDelete(perform: deleteChannels)
                        #if !os(tvOS)
                        .listRowSeparator(.hidden, edges: .top)
                        .listRowSeparator(.visible, edges: .bottom)
                        #endif
                    }
                }
            }
            .refreshable {
                await refreshChannels()
            }
            .navigationTitle("Channels")
            .platformNavigationToolbar(titleDisplayMode: .inlineLarge)
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
