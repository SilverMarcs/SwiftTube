#if os(iOS)
//
//  DownloadsView.swift
//  SwiftTube
//

import SwiftUI

struct DownloadsView: View {
    @Environment(DownloadManager.self) private var downloads

    var body: some View {
        List {
            if downloads.downloadingVideos.isEmpty && downloads.downloadedVideos.isEmpty {
                ContentUnavailableView(
                    "No Downloads",
                    systemImage: "arrow.down.circle",
                    description: Text("Download videos from the menu in any video to watch them offline.")
                )
                .listRowBackground(Color.clear)
            }

            if !downloads.downloadingVideos.isEmpty {
                Section("Downloading") {
                    ForEach(downloads.downloadingVideos) { video in
                        DownloadRow(video: video)
                    }
                }
            }

            if !downloads.downloadedVideos.isEmpty {
                Section("Downloaded") {
                    ForEach(downloads.downloadedVideos) { video in
                        DownloadRow(video: video)
                    }
                }
            }
        }
        .navigationTitle("Downloads")
        .platformNavigationToolbar(titleDisplayMode: .inline)
    }
}

struct DownloadsPreviewView: View {
    @Environment(DownloadManager.self) private var downloads

    var body: some View {
        let combined = downloads.downloadingVideos + downloads.downloadedVideos
        let items = Array(combined.prefix(3))

        Section {
            ForEach(items) { video in
                CompactVideoCard(video: video)
            }

            NavigationLink {
                DownloadsView()
            } label: {
                Text("View all downloads")
                    .foregroundStyle(.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
            }
            .navigationLinkIndicatorVisibility(.hidden)
        } header: {
            Text("Downloads")
        }
    }
}
#endif
