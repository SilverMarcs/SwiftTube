//
//  HistoryView.swift
//
//  Created by Zabir Raihan on 29/09/2025.
//

import SwiftUI

struct HistoryView: View {
    @Environment(LibraryStore.self) private var library

    var body: some View {
        Section {
            ForEach(Array(library.history.prefix(3))) { video in
                CompactVideoCard(video: video)
            }

            NavigationLink {
                HistoryFullView()
            } label: {
                Text("View full history")
                    .foregroundStyle(.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
            }
            .navigationLinkIndicatorVisibility(.hidden)
        } header: {
            Text("History")
        }
    }
}

struct HistoryFullView: View {
    @Environment(LibraryStore.self) private var library

    private var videos: [Video] { library.history }

    var body: some View {
        VideoGridView(videos: videos)
            .navigationTitle("History")
            .platformNavigationToolbar(titleDisplayMode: .inline)
            .contentMargins(.top, 5)
            .toolbar {
                if !videos.isEmpty {
                    Button(role: .destructive) {
                        library.clearHistory()
                    } label: {
                        Label("Clear History", systemImage: "trash")
                            .labelStyle(.titleOnly)
                    }
                }
            }
    }
}
