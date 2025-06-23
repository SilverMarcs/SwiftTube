//
//  WatchHistorySettingsView.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 23/06/2025.
//

import SwiftUI

struct WatchHistorySettingsView: View {
    @State private var showingClearConfirmation = false
    
    var body: some View {
        List {
            Section {
                Button("Clear Watch History") {
                    showingClearConfirmation = true
                }
                .foregroundStyle(.red)
            } footer: {
                Text("This will remove all saved video watch positions. You'll need to start videos from the beginning.")
            }
        }
        .navigationTitle("Watch History")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Clear Watch History",
            isPresented: $showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All", role: .destructive) {
                WatchTimeService.shared.clearAllWatchTimes()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently remove all saved video watch positions. This action cannot be undone.")
        }
    }
}
