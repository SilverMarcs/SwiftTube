#if os(iOS)
//
//  DownloadMenuButton.swift
//  SwiftTube
//

import SwiftUI

struct DownloadMenuButton: View {
    @Environment(DownloadManager.self) private var downloads
    let video: Video

    var body: some View {
        if downloads.isDownloaded(video.id) {
            Button {
                downloads.delete(video.id)
            } label: {
                Label("Remove Download", systemImage: "arrow.down.circle.fill")
            }
        } else if downloads.isDownloading(video.id) {
            Button {} label: {
                Label("Downloading…", systemImage: "arrow.down.circle.dotted")
            }
            .disabled(true)
        } else {
            Button {
                Task { await downloads.download(video) }
            } label: {
                Label("Download", systemImage: "arrow.down.circle")
            }
        }
    }
}
#endif
