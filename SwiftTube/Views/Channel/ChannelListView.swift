// ChannelListView.swift
import SwiftUI
import SwiftData

struct ChannelListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var channels: [Channel]
    @State private var showingAddChannel = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(channels) { channel in
                    ChannelRowView(channel: channel)
                }
                .onDelete(perform: deleteChannels)
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
}
