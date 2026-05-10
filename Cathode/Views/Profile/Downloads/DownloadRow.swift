#if os(iOS)
//
//  DownloadRow.swift
//  SwiftTube
//

import SwiftUI

struct DownloadRow: View {
    @Environment(DownloadManager.self) private var downloads
    let video: Video

    private var isDownloading: Bool { downloads.isDownloading(video.id) }

    var body: some View {
        HStack {
            CompactVideoCard(video: video)
                .allowsHitTesting(!isDownloading)
            accessory
        }
        .swipeActions {
            Button(role: .destructive, action: removeAction) {
                Label(isDownloading ? "Cancel" : "Delete",
                      systemImage: isDownloading ? "xmark" : "trash")
            }
        }
    }

    @ViewBuilder
    private var accessory: some View {
        Menu {
            Button(role: .destructive, action: removeAction) {
                Label(isDownloading ? "Cancel Download" : "Delete Download",
                      systemImage: isDownloading ? "xmark" : "trash")
            }
        } label: {
            if isDownloading {
                CircularProgressIcon(progress: downloads.progressValue(for: video.id))
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.tint)
            }
        }
        .buttonStyle(.plain)
    }

    private func removeAction() {
        if isDownloading {
            downloads.cancel(video.id)
        } else {
            downloads.delete(video.id)
        }
    }
}
#endif
