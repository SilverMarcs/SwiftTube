// ChannelListView.swift
import SwiftUI
import SwiftMediaViewer

struct ChannelListView: View {
    @Environment(LibraryStore.self) private var library

    var body: some View {
        NavigationStack {
            List {
                ForEach(library.subscribedChannels) { channel in
                    ChannelRowView(channel: channel)
                }
            }
            .refreshable {
                await library.refresh()
            }
            .navigationTitle("Channels")
            .platformNavigationToolbar(titleDisplayMode: .inlineLarge)
            .overlay {
                if library.subscribedChannels.isEmpty {
                    ContentUnavailableView(
                        "No Subscriptions",
                        systemImage: "person.crop.circle.badge.plus",
                        description: Text("Subscribe to channels on YouTube to see them here.")
                    )
                }
            }
        }
    }
}
