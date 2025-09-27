// ChannelListView.swift
import SwiftUI

struct ChannelListView: View {
    let channelStore: ChannelStore
    
    var body: some View {
        List {
            ForEach(channelStore.channels) { channel in
                ChannelRowView(channel: channel)
            }
            .onDelete(perform: deleteChannels)
        }
        .navigationTitle("Channels")
    }
    
    private func deleteChannels(offsets: IndexSet) {
        for index in offsets {
            channelStore.removeChannel(channelStore.channels[index])
        }
    }
}