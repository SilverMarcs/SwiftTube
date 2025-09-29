// ChannelListView.swift
import SwiftUI
import SwiftData
import SwiftMediaViewer

struct ChannelListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var channels: [Channel]
    @State private var showingAddChannel = false
    @State private var subscriptions: [Subscription] = []
    @State private var isLoadingSubscriptions = false
    
    private var authManager = GoogleAuthManager.shared
    
    // Filter subscriptions that aren't already saved as channels
    private var availableSubscriptions: [Subscription] {
        let channelIds = Set(channels.map { $0.id })
        return subscriptions.filter { !channelIds.contains($0.channelId) }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if !channels.isEmpty {
                    Section("Saved Channels") {
                        ForEach(channels) { channel in
                            ChannelRowView(item: channel)
                        }
                        .onDelete(perform: deleteChannels)
                    }
                }
                
                if authManager.isSignedIn {
                    Section("My Subscriptions") {
                        if isLoadingSubscriptions {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else if availableSubscriptions.isEmpty {
                            Button("Load Subscriptions") {
                                Task { await loadSubscriptions() }
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            ForEach(availableSubscriptions) { subscription in
                                HStack {
                                    ChannelRowView(item: subscription)
                                        .navigationLinkIndicatorVisibility(.hidden)
                                    
                                    Spacer()
                                    
                                    Button {
                                        addSubscriptionAsChannel(subscription)
                                    } label: {
                                        Image(systemName: "plus")
                                    }
                                    .buttonStyle(.glassProminent)
                                    .controlSize(.small)
                                    .buttonBorderShape(.circle)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Channels")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddChannel = true
                    } label: {
                        Label("Add Channel", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddChannel) {
            AddChannelView()
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
            subscriptions = fetchedSubscriptions
        } catch {
            print("Error loading subscriptions: \(error.localizedDescription)")
        }
    }
    
    private func addSubscriptionAsChannel(_ subscription: Subscription) {
        let channel = Channel(
            id: subscription.channelId,
            title: subscription.title,
            channelDescription: subscription.description,
            thumbnailURL: subscription.thumbnailURL
        )
        
        modelContext.insert(channel)
        try? modelContext.save()
    }
}
