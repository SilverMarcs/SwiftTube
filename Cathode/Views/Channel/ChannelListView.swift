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
            #if os(iOS)
            .contentMargins(.top, 10)
            #endif
            .refreshable {
                await library.refresh()
            }
            .platformTopBar("Channels")
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
