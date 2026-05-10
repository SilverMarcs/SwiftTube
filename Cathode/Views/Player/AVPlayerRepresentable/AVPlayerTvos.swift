import SwiftUI
import AVKit
import UIKit

struct AVPlayerTvos: UIViewControllerRepresentable {
    let player: AVPlayer
    let video: Video

    @Environment(VideoManager.self) private var videoManager
    @Environment(CloudStoreManager.self) private var cloudStore

    private static let bookmarkActionId = UIAction.Identifier("cathode.bookmark")

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.allowsPictureInPicturePlayback = true
        controller.transportBarIncludesTitleView = true
        controller.customInfoViewControllers = makeInfoTabs()
        controller.infoViewActions.append(makeBookmarkAction())
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if uiViewController.player !== player {
            uiViewController.player = player
        }
        let updated = makeBookmarkAction()
        if let idx = uiViewController.infoViewActions.firstIndex(where: { $0.identifier == Self.bookmarkActionId }) {
            uiViewController.infoViewActions[idx] = updated
        } else {
            uiViewController.infoViewActions.append(updated)
        }
    }

    private func makeInfoTabs() -> [UIViewController] {
        let channel = UIHostingController(
            rootView: PlayerChannelTab(channel: video.channel)
                .environment(videoManager)
                .environment(cloudStore)
        )
        channel.title = video.channel.title

        let comments = UIHostingController(
            rootView: PlayerCommentsTab(video: video)
                .environment(videoManager)
                .environment(cloudStore)
        )
        comments.title = "Comments"

        return [channel, comments]
    }

    private func makeBookmarkAction() -> UIAction {
        let isBookmarked = cloudStore.isBookmarked(video.id)
        return UIAction(
            title: isBookmarked ? "Remove Bookmark" : "Add Bookmark",
            image: UIImage(systemName: isBookmarked ? "bookmark.fill" : "bookmark"),
            identifier: Self.bookmarkActionId
        ) { _ in
            cloudStore.toggleBookmark(video)
        }
    }
}
