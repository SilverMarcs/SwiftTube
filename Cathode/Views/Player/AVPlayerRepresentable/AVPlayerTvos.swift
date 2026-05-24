import SwiftUI
import AVKit
import UIKit

struct AVPlayerTvos: UIViewControllerRepresentable {
    let player: AVPlayer
    let video: Video

    @Environment(VideoManager.self) private var videoManager
    @Environment(LibraryStore.self) private var cloudStore

    private static let skipSponsorActionId = UIAction.Identifier("cathode.skipSponsor")

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.allowsPictureInPicturePlayback = true
        controller.transportBarIncludesTitleView = true
        controller.customInfoViewControllers = makeInfoTabs()
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if uiViewController.player !== player {
            uiViewController.player = player
        }
        // Skip Sponsor — only mutate on transition to avoid flicker.
        let inSponsor = videoManager.currentSponsorSegment != nil
        let hasAction = uiViewController.contextualActions.contains { $0.identifier == Self.skipSponsorActionId }
        if inSponsor && !hasAction {
            uiViewController.contextualActions = [makeSkipSponsorAction()]
        } else if !inSponsor && hasAction {
            uiViewController.contextualActions = []
        }
    }

    private func makeInfoTabs() -> [UIViewController] {
        let comments = UIHostingController(
            rootView: PlayerCommentsTab(video: video)
                .environment(videoManager)
                .environment(cloudStore)
        )
        comments.title = "Comments"

        let channel = UIHostingController(
            rootView: PlayerChannelTab(channelId: video.channelId ?? "")
                .environment(videoManager)
                .environment(cloudStore)
        )
        channel.title = video.channelTitle

        return [comments, channel]
    }

    private func makeSkipSponsorAction() -> UIAction {
        UIAction(title: "Skip Sponsor", identifier: Self.skipSponsorActionId) { [videoManager] _ in
            videoManager.skipCurrentSponsorSegment()
        }
    }
}
