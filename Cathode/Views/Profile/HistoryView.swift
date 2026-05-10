//
//  HistoryView.swift
//
//  Created by Zabir Raihan on 29/09/2025.
//

import SwiftUI

struct HistoryView: View {
    @Environment(CloudStoreManager.self) private var userDefaults
    @State private var detailedHistoryVideos: [Video] = []

    private var historyVideos: [Video] {
        userDefaults.historyVideos
    }

    var body: some View {
        let displayedVideos = detailedHistoryVideos.isEmpty ? historyVideos : detailedHistoryVideos

        Section {
            ForEach(Array(displayedVideos.prefix(3))) { video in
                CompactVideoCard(video: video)
                    #if !os(tvOS)
                    .swipeActions {
                        Button {
                            userDefaults.removeFromHistory(video.id)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                    #endif
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
        .task(id: historyVideos.map(\.id)) {
            await loadHistoryVideoDetails(for: historyVideos)
        }
    }

    private func loadHistoryVideoDetails(for videos: [Video]) async {
        guard !videos.isEmpty else {
            detailedHistoryVideos = []
            return
        }

        do {
            var mutableVideos = videos
            try await YTService.fetchVideoDetails(for: &mutableVideos)
            detailedHistoryVideos = mutableVideos
        } catch {
            detailedHistoryVideos = videos
            print("Error updating history video details: \(error.localizedDescription)")
        }
    }
}

struct HistoryFullView: View {
    @Environment(CloudStoreManager.self) private var userDefaults
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var detailedVideos: [Video] = []

    private var rawVideos: [Video] { userDefaults.historyVideos }

    private var displayedVideos: [Video] {
        guard !detailedVideos.isEmpty else { return rawVideos }
        let detailed = Dictionary(uniqueKeysWithValues: detailedVideos.map { ($0.id, $0) })
        return rawVideos.map { detailed[$0.id] ?? $0 }
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                VideoGridView(videos: displayedVideos)
            } else {
                List {
                    ForEach(displayedVideos) { video in
                        CompactVideoCard(video: video)
                            #if !os(tvOS)
                            .swipeActions {
                                Button {
                                    userDefaults.removeFromHistory(video.id)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                                .tint(.red)
                            }
                            #endif
                    }
                }
            }
        }
        .navigationTitle("History")
        .platformNavigationToolbar(titleDisplayMode: .inline)
        .contentMargins(.top, 5)
        .task(id: rawVideos.map(\.id)) {
            await loadDetails(for: rawVideos)
        }
    }

    private func loadDetails(for videos: [Video]) async {
        guard !videos.isEmpty else { detailedVideos = []; return }
        do {
            var mutableVideos = videos
            try await YTService.fetchVideoDetails(for: &mutableVideos)
            detailedVideos = mutableVideos
        } catch {
            detailedVideos = videos
        }
    }
}

#Preview {
    HistoryView()
        .environment(CloudStoreManager.shared)
}
