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
#endif
