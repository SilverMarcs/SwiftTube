//
//  AVPlayerIos.swift
//  SwiftJelly
//
//  Created by Zabir Raihan on 10/07/2025.
//

import SwiftUI

/// Shows the shared player view controller inline. `VideoManager` keeps its
/// player in sync, so this view only embeds and releases it.
struct AVPlayerIos: UIViewControllerRepresentable {
    @Environment(VideoManager.self) private var videoManager

    func makeUIViewController(context: Context) -> PlayerContainerViewController {
        PlayerContainerViewController(host: videoManager.playerHost)
    }

    func updateUIViewController(_ uiViewController: PlayerContainerViewController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: PlayerContainerViewController, coordinator: ()) {
        uiViewController.releasePlayerViewController()
    }
}
